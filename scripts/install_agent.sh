#!/usr/bin/env bash

echo $(basename $0) "$@"

# Process arguments
function validate {
    valid=1

    if [[ "$AGENT_POOL" == "" ]] 
    then
        echo "No agent pool. Use --agent-pool to specify agent pool"
        valid=0
    fi    
    if [[ "$AGENT_NAME" == "" ]] 
    then
        echo "No agent name. Use --agent-name to specify agent name"
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

while [ "$1" != "" ]; do
    case $1 in
        --agent-name)                   shift
                                        AGENT_NAME=$1
                                        ;;                                                                                                                
        --agent-pool)                   shift
                                        AGENT_POOL=$1
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

# Allways re-install agent, if it exists
if [ -f $HOME/pipeline-agent/.agent ]; then
    echo "Agent ${AGENT_NAME} already installed, removing first..."
    pushd $HOME/pipeline-agent
    sudo ./svc.sh stop
    sudo ./svc.sh uninstall
    ./config.sh remove \
              --unattended \
              --auth pat --token $PAT
fi

# Get latest released version from GitHub
# https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest
AGENT_VERSION=$(curl https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq ".name" | sed -E 's/.*"v([^"]+)".*/\1/')
AGENT_PACKAGE="vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"
AGENT_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/${AGENT_PACKAGE}"

if [ ! -d $HOME/pipeline-agent ]; then
    mkdir $HOME/pipeline-agent
fi
pushd $HOME/pipeline-agent
echo "Retrieving agent from ${AGENT_URL}..."
wget $AGENT_URL
echo "Extracting ${AGENT_PACKAGE} in $(pwd)..."
tar zxf $AGENT_PACKAGE
echo "Extracted ${AGENT_PACKAGE}"

# Unattended config
# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
echo "Creating agent ${AGENT_NAME} and adding it to pool ${AGENT_POOL} in organization ${ORG}..."
./config.sh --unattended \
            --url https://dev.azure.com/${ORG} \
            --auth pat --token $PAT \
            --pool $AGENT_POOL \
            --agent $AGENT_NAME --replace \
            --acceptTeeEula

if [ ! -f /etc/systemd/system/vsts.agent.${ORG}.* ]; then
    # Run as systemd service
    echo "Setting up agent to run as systemd service..."
    sudo ./svc.sh install
fi

echo "Starting agent service..."
sudo ./svc.sh start
popd