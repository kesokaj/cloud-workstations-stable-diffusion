#!/bin/bash
set -eoux pipefail

sudo mkdir -p /home/${LOCAL_USER}
sudo chown -R ${LOCAL_USER}:users /home/${LOCAL_USER}
export HOME="/home/${LOCAL_USER}"

/current/webui.sh --skip-torch-cuda-test --precision full --no-half --xformers --listen --port 8080