````
# build
docker build -t stable-diffusion .

# with cpu 
docker run -it -e USE_NVIDIA=false -p 8080:8080 stable-diffusion

# with nvidia
docker run -it --gpus=all -p 8080:8080 stable-diffusion

# Environment variables
USE_NVIDIA=(true/false) true is default
USE_GCS_BUCKET=(true/false) false is default

If "USE_GCS_BUCKET" is set add bucket name to "GCS_BUCKET".

# with nvidia and gcs-bucket
docker run -it --gpus=all --privileged -e USE_GCS_BUCKET=true -e GCS_BUCKET="<bucket-name>" -p 8080:8080 stable-diffusion
````
