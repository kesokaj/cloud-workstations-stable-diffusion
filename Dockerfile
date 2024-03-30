FROM debian:stable-slim

LABEL org.opencontainers.image.source=https://github.com/kesokaj/stable-diffusion-ui-dockerfile

EXPOSE 8080

ENV LOCAL_USER="user"
ENV WORKSPACE="/workspace"
ENV SD_INSTALL_DIR="/current"

RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3 \
    python3-venv \
    libgl1 \
    libglib2.0-0 \
    python-is-python3 \
    google-perftools \
    bc

RUN mkdir -p ${WORKSPACE}
RUN mkdir -p ${SD_INSTALL_DIR}

RUN useradd -rm -d /home/${LOCAL_USER} -s /bin/bash -G sudo -u 666 ${LOCAL_USER}
RUN echo "${LOCAL_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN chgrp -R ${LOCAL_USER} ${WORKSPACE} && chmod -R 755 ${WORKSPACE} && chown -R ${LOCAL_USER}:sudo ${WORKSPACE}
RUN chgrp -R ${LOCAL_USER} ${SD_INSTALL_DIR} && chmod -R 755 ${SD_INSTALL_DIR} && chown -R ${LOCAL_USER}:sudo ${SD_INSTALL_DIR}

USER ${LOCAL_USER}
WORKDIR ${SD_INSTALL_DIR}
RUN wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
RUN chmod a+x webui.sh
RUN ./webui.sh --skip-torch-cuda-test --precision full --no-half --exit

WORKDIR ${WORKSPACE}
ENTRYPOINT [ "/bin/sh", "-c", "${SD_INSTALL_DIR}/webui.sh --skip-torch-cuda-test --precision full --no-half --listen --port 8080" ]