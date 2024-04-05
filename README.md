````
# build
docker build -t stable-diffusion .

# with cpu 
docker run -it --privileged -e USE_NVIDIA=false -p 8080:8080 stable-diffusion

# with nvidia
docker run -it --gpus=all --privileged -p 8080:8080 stable-diffusion

# Environment variables
USE_NVIDIA=(true/false) true is default
USE_GCS_BUCKET=(true/false) false is default

If "USE_GCS_BUCKET" is set add bucket name to "GCS_BUCKET".

# with nvidia and gcs-bucket
docker run -it --gpus=all --privileged -e USE_GCS_BUCKET=true -e GCS_BUCKET="<bucket-name>" -p 8080:8080 stable-diffusion

# run with nvidia in COS
docker run -it --privileged -p 8080:8080  \
  --volume /var/lib/nvidia/lib64:/usr/local/nvidia/lib64 \
  --volume /var/lib/nvidia/bin:/usr/local/nvidia/bin \
  --device /dev/nvidia0:/dev/nvidia0 \
  --device /dev/nvidia-uvm:/dev/nvidia-uvm \
  --device /dev/nvidiactl:/dev/nvidiactl \
  stable-diffusion



### Remake with
us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest
https://cloud.google.com/workstations/docs/preconfigured-base-images

````
