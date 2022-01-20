#!/usr/bin/env bash

/usr/bin/cloud-init status --long --wait
systemctl status cloud-final.service --full --no-pager --wait