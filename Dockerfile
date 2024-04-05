FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

LABEL org.opencontainers.image.source="https://github.com/kesokaj/stable-diffusion-ui-dockerfile"

ENV SHARED_GROUP="users"
ENV SD_INSTALL_DIR="/current"
ENV LOCAL_USER="shelly"
ENV EXPOSE_PORT="80"
ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    google-perftools \
    nvidia-utils-535-server \
    bc

WORKDIR /tmp

RUN useradd -rm -d ${SD_INSTALL_DIR} -s /bin/bash -G sudo,users -u 666 ${LOCAL_USER}
RUN echo "${LOCAL_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${LOCAL_USER}
WORKDIR ${SD_INSTALL_DIR}
RUN mkdir -p bucket
RUN wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
RUN chmod a+x webui.sh
RUN ./webui.sh --skip-torch-cuda-test --precision full --no-half --xformers --exit
RUN pip3 install torch

COPY init.sh init.sh
RUN sudo chmod a+x init.sh

EXPOSE ${EXPOSE_PORT}
ENTRYPOINT [ "/current/init.sh" ]
