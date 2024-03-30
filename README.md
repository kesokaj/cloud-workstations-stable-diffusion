````
# build
docker build -t ghcr.io/kesokaj/stable-diffusion-ui .

# with cpu or other gpu
docker run -it -p 8080:8080 ghcr.io/kesokaj/stable-diffusion-ui

# with nvidia
docker run -it --gpus=all -p 8080:8080 ghcr.io/kesokaj/stable-diffusion-ui
````
