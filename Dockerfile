#FROM debian:bullseye-slim
FROM nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04

LABEL org.opencontainers.image.source="https://github.com/kesokaj/stable-diffusion-ui-dockerfile"

ENV SHARED_GROUP="users"
ENV SD_INSTALL_DIR="/current"
ENV LOCAL_USER="shelly"
ENV EXPOSE_PORT="8080"
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3 \
    python3-venv \
    libgl1 \
    libglib2.0-0 \
    python-is-python3 \
    google-perftools \
    bc \
    apt-utils \
    sudo \
    openssh-server \
    vim \
    apt-transport-https \
    ca-certificates \
    gnupg \
    nvidia-driver-535-server \
    cuda-toolkit   

# Add docker-ce
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-ce.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-ce.gpg] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker-ce.list

# Add google-sdk & gcsfuse
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud-google.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloud-google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloud-google.gpg] https://packages.cloud.google.com/apt gcsfuse-bionic main" | tee -a /etc/apt/sources.list.d/gcsfuse.list

RUN apt-get update && apt-get install -y \
    google-cloud-cli \
    gcsfuse

RUN useradd -rm -d ${SD_INSTALL_DIR} -s /bin/bash -G sudo,users -u 666 ${LOCAL_USER}
RUN echo "${LOCAL_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${LOCAL_USER}
WORKDIR ${SD_INSTALL_DIR}
RUN mkdir -p bucket
RUN wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
RUN chmod a+x webui.sh
RUN ./webui.sh --skip-torch-cuda-test --precision full --no-half --xformers --exit

COPY init.sh init.sh
RUN sudo chmod a+x init.sh

EXPOSE ${EXPOSE_PORT}
ENTRYPOINT [ "/current/init.sh" ]
