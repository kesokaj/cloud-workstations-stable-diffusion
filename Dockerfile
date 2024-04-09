FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

LABEL org.opencontainers.image.source="https://github.com/kesokaj/stable-diffusion-ui-dockerfile"

ENV EXPOSE_PORT="80"
ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    google-perftools \
    nvidia-utils-535-server \
    bc \
    python3-pip \
    python-is-python3

WORKDIR /tmp

RUN wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
RUN chmod a+x webui.sh
RUN pip3 install torch

EXPOSE ${EXPOSE_PORT}