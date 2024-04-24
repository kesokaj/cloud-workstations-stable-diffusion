FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    google-perftools \
    bc \
    nvidia-driver-535-server \
    python3-pip \
    python-is-python3

COPY 120_start-gcsfuse.sh /etc/workstation-startup.d/
COPY 200_start-webui.sh /etc/workstation-startup.d/
RUN chmod a+x /etc/workstation-startup.d/*

EXPOSE 80
