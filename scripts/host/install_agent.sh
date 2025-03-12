#!/usr/bin/env bash

echo $(basename $0) "$@"

# Process arguments
function validate {
    valid=1

    if [[ "$AGENT_NAME" == "" ]] 
    then
        echo "No agent name. Use --agent-name to specify agent name"
        valid=0
    fi               
    if [[ "$AGENT_VERSION_ID" == "" ]] 
    then
        echo "No agent version. Use --agent-version-id to specify agent version"
        valid=0
    fi    
    if [[ "$ORG" == "" ]] 
    then
        echo "No Azure DevOps organization. Use --org to specify an organization"
        valid=0
    fi
    if [[ "$PAT" == "" ]] 
    then
        echo "No Personal Access Token. Use --pat to specify a Personal Access Token"
        valid=0
    fi
    if (( valid == 0)) 
    then
        exit 1
    fi
}

AGENT_DIRECTORY="/opt/pipelines-agent"
AGENT_DATA_DIRECTORY="/var/opt/pipelines-agent"
AGENT_VERSION_ID="latest" # Default
while [ "$1" != "" ]; do
    case $1 in
        --agent-name)                   shift
                                        AGENT_NAME=$1
                                        ;;                                                                                                                
        --agent-pool)                   shift
                                        AGENT_POOL=$1
                                        ;;
        --agent-version-id)             shift
                                        AGENT_VERSION_ID=$1
                                        ;;
        --deployment-group)             shift
                                        AGENT_GROUP=$1
                                        ;;
        --environment)             shift
                                        AGENT_ENVIRONMENT=$1
                                        ;;
        --project)                      shift
                                        PROJECT=$1
                                        ;;
        --org)                          shift
                                        ORG=$1
                                        ;;        
        --pat)                          shift
                                        PAT=$1
                                        ;;        
       * )                              echo "Invalid argument: $1"
                                        exit 1
    esac
    shift
done

validate

# Allways re-install agent, so remove it if it exists
if [ -f $AGENT_DIRECTORY/.agent ]; then
    echo "Agent ${AGENT_NAME} already installed, removing first..."
    pushd $AGENT_DIRECTORY
    sudo ./svc.sh stop
    sudo ./svc.sh uninstall
    ./config.sh remove --unattended --auth pat --token $PAT
    popd
fi

# Get desired release version from GitHub
AGENT_VERSION=$(curl https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/${AGENT_VERSION_ID} | jq ".name" | sed -E 's/.*"v([^"]+)".*/\1/')
AGENT_PACKAGE="vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"
AGENT_URL="https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/${AGENT_PACKAGE}"

# Setting up directories
sudo mkdir -p -- $AGENT_DIRECTORY $AGENT_DATA_DIRECTORY/diag $AGENT_DATA_DIRECTORY/work 2>/dev/null
sudo ln -s $AGENT_DATA_DIRECTORY/diag $AGENT_DIRECTORY/_diag
sudo ln -s $AGENT_DATA_DIRECTORY/work $AGENT_DIRECTORY/_work
sudo chown -R $USER:$USER $AGENT_DIRECTORY
sudo chown -R $USER:$USER $AGENT_DATA_DIRECTORY
pushd $AGENT_DIRECTORY

# Download & extract
echo "Retrieving agent from ${AGENT_URL}..."
wget -nv $AGENT_URL
echo "Extracting ${AGENT_PACKAGE} in $(pwd)..."
tar zxf $AGENT_PACKAGE
echo "Extracted ${AGENT_PACKAGE}"

echo "Installing dependencies..."
sudo ./bin/installdependencies.sh

# Unattended config
# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
if [[ -n $AGENT_ENVIRONMENT ]]; then
    echo "Creating agent ${AGENT_NAME} and adding it to environment ${AGENT_ENVIRONMENT} in project ${PROJECT} in organization ${ORG}..."
    ./config.sh --unattended \
                --url https://dev.azure.com/${ORG} \
                --auth pat --token $PAT \
                --environment --environmentname "${AGENT_ENVIRONMENT}" \
                --projectname "${PROJECT}" \
                --agent $AGENT_NAME --replace \
                --acceptteeeula \
                --work $AGENT_DATA_DIRECTORY/work
elif [[ -n $AGENT_GROUP ]]; then
    echo "Creating agent ${AGENT_NAME} and adding it to deployment group ${AGENT_GROUP} in project ${PROJECT} in organization ${ORG}..."
    ./config.sh --unattended \
                --url https://dev.azure.com/${ORG} \
                --auth pat --token $PAT \
                --deploymentgroup --deploymentgroupname "${AGENT_GROUP}" \
                --projectname "${PROJECT}" \
                --agent $AGENT_NAME --replace \
                --acceptteeeula \
                --work $AGENT_DATA_DIRECTORY/work
elif [ ! -z $AGENT_POOL ]; then
    echo "Creating agent ${AGENT_NAME} and adding it to pool ${AGENT_POOL} in organization ${ORG}..."
    ./config.sh --unattended \
                --url https://dev.azure.com/${ORG} \
                --auth pat --token $PAT \
                --pool $AGENT_POOL \
                --agent $AGENT_NAME --replace \
                --acceptteeeula \
                --work $AGENT_DATA_DIRECTORY/work
else
    echo "Neither --agent-pool, --deployment-group or --environment specified. Nothing to do"
    exit 1
fi

if [ ! -f /etc/systemd/system/vsts.agent.${ORG}.* ]; then
    # Run as systemd service
    echo "Setting up agent to run as systemd service..."
    sudo ./svc.sh install
fi

echo "Starting agent service..."
sudo ./svc.sh start
popd