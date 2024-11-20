#!/bin/bash

set -eoux pipefail

use_gcs_bucket=${USE_GCS_BUCKET:-false}

if [[ $use_gcs_bucket == "true" ]]; then
    mkdir -p /bucket
    chmod -R 777 /bucket
    gcsfuse -o rw,allow_other --implicit-dirs ${GCS_BUCKET} /bucket
else
    echo "Not mounting bucket @ /bucket"
fi