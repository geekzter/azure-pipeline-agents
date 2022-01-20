#!/usr/bin/env bash

[ -f /opt/microsoft/omsagent/bin/purge_omsagent.sh ] && sudo /opt/microsoft/omsagent/bin/purge_omsagent.sh
echo done
