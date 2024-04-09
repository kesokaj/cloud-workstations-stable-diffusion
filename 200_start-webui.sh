#!/bin/bash

set -eoux pipefail

cuda_status=$(python -c 'import torch; print(torch.cuda.is_available())')

if [[ $cuda_status == "True" ]]; then
    nvidia-smi
    nvcc -V
    /current/webui.sh --xformers --listen --port ${EXPOSE_PORT} &
else
    /current/webui.sh --skip-torch-cuda-test --precision full --no-half --listen --port ${EXPOSE_PORT} &
fi

exit 0