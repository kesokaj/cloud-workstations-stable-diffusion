#!/bin/bash
set -eoux pipefail

sudo service ssh start
sudo mkdir -p /home/${LOCAL_USER}
sudo chown -R ${LOCAL_USER}:users /home/${LOCAL_USER}
export HOME="/home/${LOCAL_USER}"

/current/webui.sh --listen --port 8080
