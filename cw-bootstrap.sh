#!/bin/bash

function insert-nested-virtualization-kernel-modules() {
  modprobe -a vhost_vsock vhost_net vsockmon
}

function await-crictl() {
  until /usr/bin/crictl ps &>/dev/null; do
    echo 'Waiting for crictl...'
    sleep 1
  done
}
function delete-default-docker-network() {
  until docker ps &>/dev/null; do
    sleep 2
  done
  systemctl stop docker.service
  ip link delete docker0
}
function configure-cloud-logging() {
    mkdir -p /var/log/containers
    cat > /etc/stackdriver/logging.config.d/fluentd-lakitu.conf << "EOF"
      <source>
        @type tail
        path /var/log/containers/cloudshell*.log,/var/log/containers/orchestrator*.log
        pos_file /var/log/gcp-containers.log.pos
        read_from_head true
        <parse>
          @type multi_format
          <pattern>
            format json
            time_key time
            time_format %Y-%m-%dT%H:%M:%S.%NZ
          </pattern>
          <pattern>
            format /^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/
            time_format %Y-%m-%dT%H:%M:%S.%N%:z
          </pattern>
        </parse>
        tag containers
      </source>

      # Parse contents of the "log" key, which should be JSON formatted for Stackdriver
      <filter containers>
        @type parser
        key_name log
        emit_invalid_record_to_error false
        <parse>
          @type multi_format
          <pattern>
            format json
            time_key timestamp
            time_format %Y-%m-%dT%H:%M:%S.%NZ
          </pattern>
          <pattern>
            format none
          </pattern>
        </parse>
      </filter>

      # Send log lines to Stackdriver. Tune performance to consume fewer resources.
      <match containers>
        @type google_cloud
        flush_interval 10s
        retry_wait 30
        num_threads 4
        enable_monitoring false
      </match>

      # Drop the logs so they don't get forwarded to the in-built stackdriver output.
      <match containers>
        @type null
      </match>
EOF
  if [[ "false" == "true" ]]
  then
    cat >> /etc/stackdriver/logging.config.d/fluentd-lakitu.conf << "EOF"
      <source>
        @type systemd
        filters [{ "SYSLOG_IDENTIFIER": "audit" }]
        pos_file /var/log/gcp-journald-audit.pos
        read_from_head true
        tag linux-auditd
      </source>
      <match fluent.**>
        @type null
      </match>
      <match **>
        @type google_cloud
        flush_interval 10s
        retry_wait 30
        num_threads 4
        enable_monitoring false
      </match>
EOF
  fi
    sed -i 's/^LOGGING_AGENT_DOCKER_IMAGE.*/LOGGING_AGENT_DOCKER_IMAGE=\"gcr.io\/stackdriver-agents\/stackdriver-logging-agent:1.9.8\"/' \
      /etc/stackdriver/env_vars
    . /etc/stackdriver/env_vars
    RANDOM_ID=$(/usr/bin/openssl rand -hex 12)
    cat <<EOF > /var/lib/google/stackdriver-logging-agent-pod.json
{
  "metadata": {
    "name": "${LOGGING_AGENT_NAME}",
    "namespace": "default",
    "uid": "${RANDOM_ID}"
  },
  "log_directory": "/tmp"
}
EOF
    cat <<EOF > /var/lib/google/stackdriver-logging-agent-container.json
{
  "metadata": {
    "name": "${LOGGING_AGENT_NAME}"
  },
  "image": {
    "image": "${LOGGING_AGENT_DOCKER_IMAGE}"
  },
  "mounts":[
    {"host_path": "/etc/stackdriver/logging.config.d/", "container_path": "/etc/google-fluentd/config.d/"},
    {"host_path": "/var/log", "container_path": "/var/log"}
  ],
  "log_path":"stackdriver-logging-agent.log",
  "labels": {
    "containerd.io/restart.policy": "always",
    "containerd.io/restart.status": "running"
  }
}
EOF
  cat > /etc/systemd/system/stackdriver-containerd-logging.service << "EOF"
[Unit]
Description=Fluentd container for Stackdriver Logging using containerd

[Service]
EnvironmentFile=-/etc/stackdriver/env_vars
ExecStartPre=/bin/mkdir -p /var/log/google-fluentd/
ExecStartPre=/usr/bin/crictl pull ${LOGGING_AGENT_DOCKER_IMAGE}
ExecStart=/bin/sh -c '/usr/bin/crictl runp /var/lib/google/stackdriver-logging-agent-pod.json;PODID=$(/usr/bin/crictl pods --name stackdriver-logging-agent -q);/usr/bin/crictl create $PODID /var/lib/google/stackdriver-logging-agent-container.json /var/lib/google/stackdriver-logging-agent-pod.json;CONID=$(/usr/bin/crictl ps --name stackdriver-logging-agent -q -a);/usr/bin/crictl start $CONID'
EOF
    systemctl daemon-reload
    systemctl start stackdriver-containerd-logging.service
    if [[ "false" == "true" ]]; then
      systemctl start cloud-audit-setup
    fi
}

function configure-gpu() {
  if [[ "true" == "true" ]]; then
    cos-extensions install gpu
    sudo mount --bind /var/lib/nvidia /var/lib/nvidia
    sudo mount -o remount,exec /var/lib/nvidia
  fi
}

function configure-inotify-for-theia() {
  echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf
  sudo sysctl -p
}

function configure-orchestrator() {
  sudo mkdir -p /var/volumes
  sudo mkdir -p /var/lib/google
  SECRET=$(curl -H Metadata-Flavor:Google -f http://169.254.169.254/computeMetadata/v1/instance/attributes/environments-devops-cloud-google-com_secret)
  RANDOM_ID=$(/usr/bin/openssl rand -hex 12)
  cat <<EOF > /var/lib/google/orchestrator-pod.json
{
  "metadata": {
    "name": "orchestrator",
    "namespace": "default",
    "uid": "${RANDOM_ID}"
  },
  "log_directory": "/var/log/containers",
  "linux": {
    "security_context": {
      "privileged": true
    }
  }
}
EOF
  cat <<EOF > /var/lib/google/orchestrator-container.json
{
  "metadata": {
    "name": "orchestrator"
  },
  "image": {
    "image": "europe-west4-docker.pkg.dev/cloud-workstations-images/system/orchestrator:20240318-080347"
  },
  "args": ["--allowUnauthenticatedPreflightRequests=false","--baseServerUrl=https://ssh.cloud.google.com","--disableTcpRelay=false","--enableLocalhostReplacement=true","--forwardingAgentImage=europe-west4-docker.pkg.dev/cloud-workstations-images/system/forwardingagent:20240318-080347","--frameAncestors=","--gatewayImage=europe-west4-docker.pkg.dev/cloud-workstations-images/system/gateway:20240318-080347","--mountGpuDevices=true","--oauthClientId=618104708054-m0mqlm35l2ahieavnib6emtan2k95ps9.apps.googleusercontent.com","--oauthRedirectPath=/devshell/gateway/oauth","--userImage=europe-west4-docker.pkg.dev/fj61-positive-ladybug/cwi/stable-diffusion@sha256:bceeffe751b76c1655eea82230a8ebab5e8944ee52761bd522d544947dea429a","--waitForDiskAttach=true","--whitelistedOauthClients=618104708054-9r9s1c4alg36erliucho9t52n32n6dgq.apps.googleusercontent.com,618104708054-plueempusfrhq9l2dk3do2jtapm533gi.apps.googleusercontent.com","--workstationsJwtPublicKeys=eyIxMDgyNDg3NTg5IjoiLS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS1cbk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBM29TZlR3a0drZGhtZVdEc285dmlcbnhwc1M0TXBsL0JHTTRvb3ZaR3l1MzNSR2ZMUXRLdVFNdlNVY2RJMG1sV2NGVkh4VFlpSHQ5c2oxRWVweWVFTWlcblVqZHM4UXpMZDZsOXJKKzFtTW9VSld6NTNnUGF2bWE4TjlpUVJPd1NleDVzTzFkT1RzR1hRWG1BYnRUN3Y1a2dcbitqYUV3Yk4rRk1JTElnSWNpaDd6dGNhZVJlVFcyTTMrNUhXdzhxQUM2U2RnaGNjYXcyUnNydC9aeUdKYTJ2TStcbmNsbFlXWFA2RTdITXh3RWhJcUkwWjV2eUVtN3VQQkRVU1lGUnRsOUJoVWgyODFGWWdVSmxFenhWWURxWHVXVUxcbjhmQW1Ba3dONVNNR1N0L1hDdE1HWWQ1dkhRNUwwbzVjaDZTVTkwVGNlZk5QTlBQT21kQlJYZDB0ZXFRaUxSQ2lcbmVRSURBUUFCXG4tLS0tLUVORCBQVUJMSUMgS0VZLS0tLS0iLCItNjUwNzE5NzQxIjoiLS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS1cbk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBeVFxbW9Uc3FrWEhUUGxhUE1CU3FcbkM1NzRzRDdRNUI0S3hkNkxwT2lWQTg4eVQxWERHY3kyZ01maXAyeEtGWHdtb0U4eENlaUNnUEpBY1pRSUs5bWdcbjFsQzRxZHhEWDJ4N0Y3Mkk2d2FTSmJCdGxpUzQrR3RoL0pEUUZsRWtRbWpMMUVPTEY0Y083LzlBTitlTG9wQzhcbjR5cjZhbnVwSlU2K2YyZVZ3VGo5VDU2eU9uS2ZObzRQaUp6UWtmZHpLdXB5dWh4Q0t2c2VnYTJqcmVpVUN1T2NcbmRDZlBiK1hCUW9Kc2VhRFFtSWNvZWlZNE8rOGdSQU1maDBoTC9KZFlpQWhGc1c2UHZsWEV6UWFaKzNGRzl4Z3lcbit4RHNxazlOYUtXVndicFl0UHkxbElTWGFOSGc5UkVKdU1RVFk0QnlBQVl0NlUzWmVlRWlLK2lCaDJqOXVoYmRcbnB3SURBUUFCXG4tLS0tLUVORCBQVUJMSUMgS0VZLS0tLS0iLCI1NTM2NDg3MjciOiItLS0tLUJFR0lOIFBVQkxJQyBLRVktLS0tLVxuTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF3Q0NnWG5Ua2hpK1hFMUhtajlZVlxueEs1aUg3a3QwOXhvRlpqRWNmVnlycEpnSHladldGbzJmeVNQYUpERU85OHphdGkwbHBJRXpqK1BLTTJpVXJld1xuWitpQVlHT2ZiSm55MG9tK1JTd3ZLdjRCa0tiZ0lEY0w5aWorc0lMOEg3T0xzYW55WTV3NWlac09meW1qN2QxTVxucENweXIxVk9ONGFJK3VPRkVsTnQ4UzFHQ0xZN3ZKOW9WaUZwYmtHU1NVNjlIb01iUklIdms1UnowM2pRZytPRVxub0dPL245WUxQK0p3UUJvNVhRUnk2eGgwL052VVlaQzl2RDFUaXNaY2pBWUVWNURKZmpUbkVxUnQyemwrUk1saFxudStVV3Jyc3FtQVVVNFNWd2ZhVjc0UEZMV3VubktuZ1BJS2JhczVyQ3I4blRjazhUUDVhYkYvSnN4a0Q4VlNISVxuS3dJREFRQUJcbi0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLSIsIi0xMTM2MzY5OTY5IjoiLS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS1cbk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMnltQko2cSs2UXVScXpwdnVRbDRcbm4rY05pQ3phcjZJem1XazFmelVGaytRRFAvODF5Y3R2OHYybktGY0Z0WWVtTi80WExwelRCaXgzdm1LN1dZcE5cbi9aYVRXT3hZd2E4MDd5eWo1UjVlKytzQksxRzhlZmJROUJscUhlQVh0NmlWb05WNnV4NmwwRGZTVVI3bkI0bm1cbkJzY2krN294Q3pvTVk1a2J0d2lLS2lUOUVDaTZLV2hxMDV2cEZ0MldjMDZmOFNwRkh0YzhYYVRNaWVjV0pKSlJcbjA2aUhrYTUxdHlBbG5SSTNlQ0JaTnMwc3ZJSnhKMXQzamE5QXFXM2pWQUorZ3hVUzVKdThLNTJzT1dDc0JvWDJcbnNEblJ6NEVoNjJJaGxySGFma2dxQ3lSTFp0ZVhuMXpHTDA3b3BCL1pCL1BXamt0VE5iby9EMmxjUWRlbWhPVzBcbkh3SURBUUFCXG4tLS0tLUVORCBQVUJMSUMgS0VZLS0tLS0ifQ==","--useCriContainerdClient=true"],
  "envs": [
    {"key": "SECRET", "value": "${SECRET}"}
  ],
  "mounts":[
    {"host_path": "/dev", "container_path": "/dev", "propagation": 2},
    {"host_path": "/run/containerd", "container_path": "/run/containerd", "propagation": 2},
    {"host_path": "/var", "container_path": "/var", "propagation": 2},
    {"host_path": "/tmp", "container_path": "/tmp", "propagation": 2}
  ],
  "log_path":"orchestrator.log",
  "linux": {
    "security_context": {
      "privileged": true
    }
  },
  "labels": {
    "containerd.io/restart.policy": "always",
    "containerd.io/restart.status": "running"
  }
}
EOF
  #TODO(b/296237219): Create a script instead to run orchestrator.
  cat >> /etc/systemd/system/orchestrator.service << "EOF"
    [Unit]
    Description=orchestrator
    After=containerd.service
    Requires=containerd.service

    [Service]
    TimeoutStartSec=0
    Restart=always
    ExecStartPre=/usr/bin/crictl pull europe-west4-docker.pkg.dev/cloud-workstations-images/system/orchestrator:20240318-080347
    ExecStart=/bin/sh -c '/usr/bin/crictl runp /var/lib/google/orchestrator-pod.json;PODID=$(/usr/bin/crictl pods --name "orchestrator" -q);/usr/bin/crictl create $PODID /var/lib/google/orchestrator-container.json /var/lib/google/orchestrator-pod.json;CONID=$(/usr/bin/crictl ps --name orchestrator -q -a);/usr/bin/crictl start $CONID'
EOF
  systemctl daemon-reload
  systemctl start orchestrator.service
}

function check-connectivity() {
  crictl pull "europe-west4-docker.pkg.dev/cloud-workstations-images/system/orchestrator:20240318-080347"
  if [[ $? == 0 ]]
   then curl -X PUT --data "true" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ArtifactRegistryConnectivity -H "Metadata-Flavor: Google"
   else
      curl -X PUT --data "false" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ArtifactRegistryConnectivity -H "Metadata-Flavor: Google"
      error_message_ar = "$(crictl pull "europe-west4-docker.pkg.dev/cloud-workstations-images/system/orchestrator:20240318-080347")"
      if [[ "$error_message_ar" != "" ]]
        then curl -X PUT --data "$error_message_ar" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ArtifactRegistryConnectivityError -H "Metadata-Flavor: Google"
        else curl -X PUT --data "unknown error" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ArtifactRegistryConnectivityError -H "Metadata-Flavor: Google"
      fi
      echo -e "\nUnable to pull images from Artifact Registry so cannot start your Workstation.\n" 1>&2
  fi

  crictl pull "gcr.io/stackdriver-agents/stackdriver-logging-agent:1.9.8"
  if [[ $? == 0 ]]
   then curl -X PUT --data "true" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ContainerRegistryConnectivity -H "Metadata-Flavor: Google"
   else
      curl -X PUT --data "false" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ContainerRegistryConnectivity -H "Metadata-Flavor: Google"
      error_message_gcr = "$(crictl pull "gcr.io/stackdriver-agents/stackdriver-logging-agent:1.9.8")"
      if [[ "$error_message_ar" != "" ]]
        then curl -X PUT --data "$error_message_gcr" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ContainerRegistryConnectivityError -H "Metadata-Flavor: Google"
        else curl -X PUT --data "unknown error" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ContainerRegistryConnectivityError -H "Metadata-Flavor: Google"
      fi
      echo -e "\nUnable to pull images from Container Registry so cannot start your Workstation.\n" 1>&2
  fi

  ENDPOINT=$(curl -H Metadata-Flavor:Google -f http://169.254.169.254/computeMetadata/v1/instance/attributes/environments-devops-cloud-google-com_psc-endpoint)
  status=$(curl --insecure --head --location --write-out %{http_code} --silent --output /dev/null "https://$ENDPOINT/_invertingproxy/healthz")
  connection_attempts=0
  while [[ "$status" != 200 && $connection_attempts -lt 30 ]]; do
    sleep 1s
    ((connection_attempts=connection_attempts+1))
    status=$(curl --insecure --head --location --write-out %{http_code} --silent --output /dev/null "https://$ENDPOINT/_invertingproxy/healthz")
  done
  if [[ "$status" == 200 ]]
   then curl -X PUT --data "true" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ControlPlaneConnectivity -H "Metadata-Flavor: Google"
   else
      curl -X PUT --data "false" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/health/ControlPlaneConnectivity -H "Metadata-Flavor: Google"
      echo -e "\nUnable to connect to the Cloud Workstations control plane so cannot start your Workstation.\n" 1>&2
  fi
}

function block-ssh() {
  sudo systemctl stop sshd
  sudo systemctl mask sshd
  # Insert a rule to drop all connection on port 22.
  sudo iptables -I INPUT -i eth0 -p tcp --dport 22 -j DROP
}

function configure-containerd() {
  # TODO(b/295421330): Move these binaries to more appropriate path.
  mkdir -p /var/lib/google

  wget https://storage.googleapis.com/"europe-west4"-cloud-workstations-binaries/binaries/gcfsd/v0.195.0/gcfsd -O /var/lib/google/gcfsd
  chmod +x /var/lib/google/gcfsd
  wget https://storage.googleapis.com/"europe-west4"-cloud-workstations-binaries/binaries/gcfs-snapshotter/v1.29-2/containerd-gcfs-grpc -O /var/lib/google/containerd-gcfs-grpc
  chmod +x /var/lib/google/containerd-gcfs-grpc

  cat << EOF > /etc/systemd/system/gcfsd.service
# Systemd configuration for Google Container File System service
[Unit]
Description=Google Container File System service
After=network.target

[Service]
Type=simple

# More aggressive Go garbage collection setting (go/fast/19).
Environment=GOGC=10
ExecStartPre=-/bin/umount -v /run/gcfsd/mnt
ExecStartPre=-/bin/mkdir -p /run/gcfsd/mnt
# prod config
ExecStartPre=/bin/mkdir -p /var/lib/containerd/io.containerd.snapshotter.v1.gcfs/snapshotter/layers
ExecStartPre=/bin/mkdir -p /var/lib/containerd/io.containerd.snapshotter.v1.gcfs/gcfsd
# start
ExecStart=/var/lib/google/gcfsd \
  --allow_suid=true \
  --mount_point=/run/gcfsd/mnt \
  --metrics_flavor="" \
  --client_name=cloud_workstations \
  --log_level=info \
  --max_content_cache_size_mb=721 \
  --max_large_files_cache_size_mb=721 \
  --event_reporter_type=none \
  --layer_cache_dir=/var/lib/containerd/io.containerd.snapshotter.v1.gcfs/snapshotter/layers \
  --images_in_use_db_path=/var/lib/containerd/io.containerd.snapshotter.v1.gcfs/gcfsd/images_in_use.db

ExecStop=/bin/umount /run/gcfsd/mnt
RuntimeDirectory=gcfsd
StateDirectory=gcfsd
# Higher process scheduling priority
Nice=-20

[Install]
WantedBy=multi-user.target
EOF

  mkdir -p /etc/cni/net.d
  cat << EOF > /etc/cni/net.d/10-containerd-net.conflist
{
  "cniVersion": "1.0.0",
  "name": "containerd-net",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "ipMasq": true,
      "promiscMode": true,
      "ipam": {
        "type": "host-local",
        "ranges": [
          [{
            "subnet": "10.88.0.0/16"
          }]
        ],
        "routes": [
          { "dst": "0.0.0.0/0" }
        ]
      }
    },
    {
      "type": "firewall",
      "backend": "iptables"
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true}
    },
    {
      "type": "tuning",
      "sysctl": {
          "net.ipv6.conf.all.disable_ipv6": "1",
          "net.ipv6.conf.default.disable_ipv6": "1",
          "net.ipv6.conf.lo.disable_ipv6": "1"
       }
    }
  ]
}
EOF

  mkdir -p /etc/containerd-gcfs-grpc
  touch /etc/containerd-gcfs-grpc/config.toml
  cat << EOF > /etc/systemd/system/snapshotter.service
# Systemd configuration for Google Container File System snapshotter
[Unit]
Description=GCFS snapshotter
After=network.target
Before=containerd.service

[Service]
Environment=HOME=/root
ExecStart=/var/lib/google/containerd-gcfs-grpc \
    --log-level=info \
    --kubeconfig "" \
    --config=/etc/containerd-gcfs-grpc/config.toml

Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

  cat << EOF > /etc/containerd/config.toml
version = 2
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "k8s.gcr.io/pause:3.5"
  enable_unprivileged_ports = true
[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "gcfs"
  disable_snapshot_annotations = false
[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d/"
  conf_template = ""
[proxy_plugins]
[proxy_plugins.gcfs]
  type = "snapshot"
  address = "/run/containerd-gcfs-grpc/containerd-gcfs-grpc.sock"
EOF

  systemctl daemon-reload
  systemctl stop gcfsd snapshotter containerd
  systemctl enable gcfsd snapshotter containerd
  systemctl restart gcfsd snapshotter containerd
}

function mount-ephemeral-disk() {
  sudo mkdir -p /var/volumes/ephemeral-disk
  NEXT_WAIT_TIME=0
  MOUNT_EXIT_CODE=1
  until [[ $MOUNT_EXIT_CODE -eq 0 || $NEXT_WAIT_TIME -eq 3 ]]; do
    MOUNT_OUTPUT=$(sudo mount /dev/disk/by-id/google-ephemeral-disk /var/volumes/ephemeral-disk 2>&1)
    MOUNT_EXIT_CODE=$?
    sleep $NEXT_WAIT_TIME
    let NEXT_WAIT_TIME=NEXT_WAIT_TIME+1
  done
  JSON_FMT='{"status":"%s","output":"%s"}\n'
  if [[ $MOUNT_EXIT_CODE == 0 ]]
   then
      printf "${JSON_FMT}" "OK" "" > /var/google/ephemeral-disk-mount-status
   else
      printf "${JSON_FMT}" "FAILED" "${MOUNT_OUTPUT}" > /var/google/ephemeral-disk-mount-status
      echo -e "\nUnable to mount ephemeral disk to your Workstation:\n" 1>&2
      echo -e "${MOUNT_OUTPUT}" 1>&2
  fi
}

function check-for-home-disk() {
  while [[ ! $(cat /proc/partitions|grep -e nvme0n2 -e sdb) ]]; do
    sleep 5s
  done
  echo "Home disk partition detected"
  sleep 5s
  if [[ -e "/dev/disk/by-id/google-home" ]]
    then
      echo "Home disk mounted"
      touch /var/google/home-disk-attached
    else
      echo "Home disk not detected"
  fi
}

function show-ssh-port-status() {
   sudo lsof -i:22
}

function main() {
  sudo mkdir -p /var/google
  if [[ "false" == "true" ]]
  then
    mount-ephemeral-disk&
  fi
  configure-containerd
  if [[ "false" == "true" ]]
  then
    insert-nested-virtualization-kernel-modules
  fi
  await-crictl
  check-connectivity
  configure-cloud-logging
  configure-gpu
  configure-inotify-for-theia
  check-for-home-disk&
  configure-orchestrator
  delete-default-docker-network&
  if [[ "false" == "true" ]]
  then
    block-ssh
  fi
  show-ssh-port-status
  echo 'VM is ready!'
}

main |& tee /dev/ttyS2
