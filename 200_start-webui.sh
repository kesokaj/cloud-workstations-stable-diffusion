#!/bin/bash

set -eoux pipefail

if [ ! -f /home/user/webui.sh ]; then 
    runuser -l user -c 'wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh'
    runuser -l user -c 'chmod a+x webui.sh'
fi

if [ -f /proc/driver/nvidia/version ]; then
    runuser -l user -c 'cat /proc/driver/nvidia/version'
    runuser -l user -c 'env'
    runuser -l user -c 'nvidia-smi'
    runuser -l user -c './webui.sh --xformers --allow-code --api --administrator --listen --port 80 &'
else
    runuser -l user -c '/webui.sh --skip-torch-cuda-test --allow-code --api --administrator --listen --port 80 &'
fi

exit 0
