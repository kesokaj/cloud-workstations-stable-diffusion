FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:last-ubuntu2204

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y \
    bc \
    apt-utils \
    google-perftools \
    software-properties-common

RUN apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    nvidia-driver-535-server

RUN apt-get install -y \
    python3-pip \
    python3-venv \
    python3-dev \
    python-is-python3

COPY 120_start-gcsfuse.sh /etc/workstation-startup.d/
COPY 200_start-webui.sh /etc/workstation-startup.d/
RUN chmod a+x /etc/workstation-startup.d/*

EXPOSE 80
