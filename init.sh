#!/bin/bash
set -eoux pipefail

sudo service ssh start
sudo mkdir -p /home/${LOCAL_USER}
sudo chown -R ${LOCAL_USER}:users /home/${LOCAL_USER}
export HOME="/home/${LOCAL_USER}"

use_nvidia=${USE_NVIDIA:-true}
use_gcs_bucket=${USE_GCS_BUCKET:-false}

if [[ $use_gcs_bucket == "true" ]]; then
    gcsfuse --implicit-dirs ${GCS_BUCKET} ${SD_INSTALL_DIR}/bucket
else
    echo "Not mounting bucket @ ${SD_INSTALL_DIR}/bucket"
fi

if [[ $use_nvidia == "true" ]]; then
    /current/webui.sh --xformers --listen --port ${EXPOSE_PORT}
else
    /current/webui.sh --skip-torch-cuda-test --precision full --no-half --listen --port ${EXPOSE_PORT}
fi


sleep infinity
