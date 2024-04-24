## Local development
````
# build
docker build -t stable-diffusion .

# with cpu 
docker run -it --privileged -e USE_NVIDIA=false -p 8080:80 stable-diffusion

# with nvidia
docker run -it --gpus=all --privileged -p 8080:80 stable-diffusion

# Environment variables
USE_NVIDIA=(true/false) true is default
USE_GCS_BUCKET=(true/false) false is default

If "USE_GCS_BUCKET" is set add bucket name to "GCS_BUCKET".

# with nvidia and gcs-bucket
docker run -it --gpus=all --privileged -e USE_GCS_BUCKET=true -e GCS_BUCKET="<bucket-name>" -p 8080:80 stable-diffusion

# run with nvidia in COS
docker run -it --privileged -p 8080:8080  \
  --volume /var/lib/nvidia/lib64:/usr/local/nvidia/lib64 \
  --volume /var/lib/nvidia/bin:/usr/local/nvidia/bin \
  --device /dev/nvidia0:/dev/nvidia0 \
  --device /dev/nvidia-uvm:/dev/nvidia-uvm \
  --device /dev/nvidiactl:/dev/nvidiactl \
  stable-diffusion
````

## Push to Artifact Registry
````
# gcloud CLI credential helper
gcloud auth configure-docker us-east1-docker.pkg.dev

# Standalone credential helper
docker-credential-gcr configure-docker us-east1-docker.pkg.dev

# Image naming
LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE
docker tag SOURCE-IMAGE LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE:TAG

# Push image
docker push LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE
````

## Create a Cloud Workstations
https://cloud.google.com/workstations/docs/create-workstation

## Urls
https://cloud.google.com/workstations/docs/preconfigured-base-images
https://cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling

