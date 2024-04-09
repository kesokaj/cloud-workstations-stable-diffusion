#!/bin/bash

set -eoux pipefail

if [ ! -f webui.sh ]; then 
    runuser -l user -c 'wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh'
    runuser -l user -c 'chmod a+x webui.sh'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
    runuser -l user -c './webui.sh --xformers --listen --port 80 &'
else
    runuser -l user -c '/webui.sh --skip-torch-cuda-test --precision full --no-half --listen --port 80 &'
fi

exit 0
