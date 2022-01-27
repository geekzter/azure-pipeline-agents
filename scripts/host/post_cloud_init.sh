#!/usr/bin/env bash

# Wait for Cloud Init to complete
/usr/bin/cloud-init status --long --wait
systemctl status cloud-final.service --full --no-pager --wait

# Remove Log Analytics if installed, so we can install our own
# [ -f /opt/microsoft/omsagent/bin/purge_omsagent.sh ] && sudo /opt/microsoft/omsagent/bin/purge_omsagent.sh

echo done