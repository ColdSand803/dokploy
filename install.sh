#!/bin/bash

# Docker version to install and maintain
DOCKER_VERSION="28.5.0"

# Custom Image Configuration
# Defaults to ColdSand803's GHCR container image (can be overridden via DOKPLOY_IMAGE environment variable)
# Examples:
#   export DOKPLOY_IMAGE="ghcr.io/coldsand803/dokploy"
#   export DOKPLOY_VERSION="latest"
DOKPLOY_IMAGE="${DOKPLOY_IMAGE:-ghcr.io/coldsand803/dokploy}"

# Detect version from environment variable or default to latest
# Usage with curl: curl -sSL https://raw.githubusercontent.com/ColdSand803/dokploy/pro/install.sh | bash
# Usage with custom image: DOKPLOY_IMAGE="my-repo/dokploy" curl -sSL ... | bash
detect_version() {
    local version="${DOKPLOY_VERSION}"
    
    # If no version specified, default to latest
    if [ -z "$version" ]; then
        version="latest"
    fi
    
    echo "$version"
}

# Function to detect if running in Proxmox LXC container
is_proxmox_lxc() {
    # Check for LXC in environment
    if [ -n "$container" ] && [ "$container" = "lxc" ]; then
        return 0  # LXC container
    fi
    
    # Check for LXC in /proc/1/environ
    if grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        return 0  # LXC container
    fi
    
    return 1  # Not LXC
}

generate_random_password() {
    local password=""
    if command -v openssl >/dev/null 2>&1; then
        password=$(openssl rand -base64 32 | tr -d "=+\/" | cut -c1-32)
    elif [ -r /dev/urandom ]; then
        password=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
    else
        if command -v sha256sum >/dev/null 2>&1; then
            password=$(date +%s%N | sha256sum | base64 | head -c 32)
        elif command -v shasum >/dev/null 2>&1; then
            password=$(date +%s%N | shasum -a 256 | base64 | head -c 32)
        else
            password=$(echo "$(date +%s%N)-$(hostname)-$$-$RANDOM" | base64 | tr -d "=+\/" | head -c 32)
        fi
    fi
    
    if [ -z "$password" ] || [ ${#password} -lt 20 ]; then
        echo "Error: Failed to generate random password" >&2
        exit 1
    fi
    
    echo "$password"
}

install_dokploy() {
    # Detect version tag and docker image
    VERSION_TAG=$(detect_version)
    DOCKER_IMAGE="${DOKPLOY_IMAGE}:${VERSION_TAG}"
    
    echo "=========================================================="
    echo "  Installing Dokploy (i18n / 中文汉化版)"
    echo "  Image:   ${DOCKER_IMAGE}"
    echo "  Version: ${VERSION_TAG}"
    echo "=========================================================="

    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root (必须使用 root 权限运行)" >&2
        exit 1
    fi

    # check if is Mac OS
    if [ "$(uname)" = "Darwin" ]; then
        echo "This script must be run on Linux" >&2
        exit 1
    fi

    # check if is running inside a container
    if [ -f /.dockerenv ]; then
        echo "This script must be run on Linux host" >&2
        exit 1
    fi

    # check if something is running on port 80
    if ss -tulnp | grep ':80 ' >/dev/null; then
        echo "Error: something is already running on port 80" >&2
        exit 1
    fi

    # check if something is running on port 443
    if ss -tulnp | grep ':443 ' >/dev/null; then
        echo "Error: something is already running on port 443" >&2
        exit 1
    fi

    # check if something is running on port 3000
    if ss -tulnp | grep ':3000 ' >/dev/null; then
        echo "Error: something is already running on port 3000" >&2
        echo "Dokploy requires port 3000 to be available. Please stop any service using this port." >&2
        exit 1
    fi

    command_exists() {
      command -v "$@" > /dev/null 2>&1
    }

    if command_exists docker; then
      echo "Docker already installed"
    else
      curl -sSL https://get.docker.com | sh -s -- --version $DOCKER_VERSION
      if command_exists apt-mark; then
        apt-mark hold docker-ce docker-ce-cli docker-ce-rootless-extras
      fi
    fi

    endpoint_mode=""
    if [ "$ENDPOINT_MODE" = "dnsrr" ]; then
        echo "ENDPOINT_MODE=dnsrr set — adding --endpoint-mode dnsrr to Docker services."
        endpoint_mode="--endpoint-mode dnsrr"
    elif is_proxmox_lxc; then
        echo "⚠️ WARNING: Detected Proxmox LXC container environment!"
        endpoint_mode="--endpoint-mode dnsrr"
        echo "Waiting for 5 seconds before continuing..."
        sleep 5
    fi

    docker swarm leave --force 2>/dev/null

    get_ip() {
        local ip=""
        ip=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
        fi
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
        fi
        if [ -z "$ip" ]; then
            ip=$(curl -6s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
            fi
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
            fi
        fi

        if [ -z "$ip" ]; then
            echo "Error: Could not determine server IP address automatically." >&2
            echo "Please set the ADVERTISE_ADDR environment variable manually." >&2
            exit 1
        fi
        echo "$ip"
    }

    get_private_ip() {
        ip -o -4 addr show scope global \
            | awk '$2 !~ /^(docker|br-|veth)/ {print $4}' \
            | cut -d/ -f1 \
            | grep -E "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" \
            | head -n1
    }

    advertise_addr="${ADVERTISE_ADDR:-$(get_private_ip)}"
    if [ -z "$advertise_addr" ]; then
        advertise_addr=$(get_ip)
    fi

    if [ -z "$advertise_addr" ]; then
        echo "ERROR: We couldn't detect your server IP address." >&2
        exit 1
    fi
    echo "Using advertise address: $advertise_addr"

    swarm_init_args="${DOCKER_SWARM_INIT_ARGS:-}"
    if [ -n "$swarm_init_args" ]; then
        echo "Using custom swarm init arguments: $swarm_init_args"
        docker swarm init --advertise-addr $advertise_addr $swarm_init_args
    else
        docker swarm init --advertise-addr $advertise_addr
    fi
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to initialize Docker Swarm" >&2
        exit 1
    fi

    echo "Swarm initialized"

    docker network rm -f dokploy-network 2>/dev/null
    docker network create --driver overlay --attachable dokploy-network

    echo "Network created"

    mkdir -p /etc/dokploy
    chmod 777 /etc/dokploy

    POSTGRES_PASSWORD=$(generate_random_password)
    echo "$POSTGRES_PASSWORD" | docker secret create dokploy_postgres_password - 2>/dev/null || true

    AUTH_SECRET=$(openssl rand -hex 32)
    echo "$AUTH_SECRET" | docker secret create dokploy_auth_secret - 2>/dev/null || true

    echo "Generated secure database credentials and auth secret"

    docker service create \
      --name dokploy-postgres \
      --constraint 'node.role==manager' \
      --network dokploy-network \
      --env POSTGRES_USER=dokploy \
      --env POSTGRES_DB=dokploy \
      --secret source=dokploy_postgres_password,target=/run/secrets/postgres_password \
      --env POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
      --mount type=volume,source=dokploy-postgres,target=/var/lib/postgresql/data \
      $endpoint_mode \
      postgres:16

    release_tag_env=""
    case "$VERSION_TAG" in
        v[0-9]*.[0-9]*.[0-9]*)
            release_tag_env="-e RELEASE_TAG=latest"
            ;;
        latest)
            ;;
        *)
            release_tag_env="-e RELEASE_TAG=$VERSION_TAG"
            ;;
    esac
    
    echo "Deploying Dokploy service using image: ${DOCKER_IMAGE}..."
    docker service create \
      --name dokploy \
      --replicas 1 \
      --network dokploy-network \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      --mount type=bind,source=/etc/dokploy,target=/etc/dokploy \
      --mount type=volume,source=dokploy,target=/root/.docker \
      --secret source=dokploy_postgres_password,target=/run/secrets/postgres_password \
      --secret source=dokploy_auth_secret,target=/run/secrets/dokploy_auth_secret \
      --publish published=3000,target=3000,mode=host \
      --update-parallelism 1 \
      --update-order stop-first \
      --constraint 'node.role == manager' \
      $endpoint_mode \
      $release_tag_env \
      -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
      -e BETTER_AUTH_SECRET_FILE=/run/secrets/dokploy_auth_secret \
      $DOCKER_IMAGE

    sleep 4

    docker run -d \
        --name dokploy-traefik \
        --restart always \
        --network dokploy-network \
        -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml \
        -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p 80:80/tcp \
        -p 443:443/tcp \
        -p 443:443/udp \
        traefik:v3.6.25

    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    NC="\033[0m"

    format_ip_for_url() {
        local ip="$1"
        if echo "$ip" | grep -q ':'; then
            echo "[${ip}]"
        else
            echo "${ip}"
        fi
    }

    public_ip="${ADVERTISE_ADDR:-$(get_ip)}"
    private_ip=$(get_private_ip)
    formatted_addr=$(format_ip_for_url "$public_ip")
    echo ""
    printf "${GREEN}===================================================================${NC}\n"
    printf "${GREEN} 🎉 Congratulations! Dokploy (i18n / 中文汉化版) is installed!${NC}\n"
    printf "${GREEN} 🎉 恭喜！Dokploy (支持多语言 / 中文实时切换) 已成功安装！${NC}\n"
    printf "${GREEN}===================================================================${NC}\n"
    printf "${BLUE}Wait 15 seconds for the server to start (请等待约 15 秒服务完全启动)${NC}\n"
    printf "${YELLOW}Dashboard URL: http://${formatted_addr}:3000${NC}\n"
    if [ -n "$private_ip" ] && [ "$private_ip" != "$public_ip" ]; then
        printf "${YELLOW}Local LAN URL: http://${private_ip}:3000${NC}\n"
    fi
    printf "${CYAN}Language: Supports English & 简体中文 (可在界面随时自由切换)${NC}\n"
    printf "${CYAN}Repo:     https://github.com/ColdSand803/dokploy${NC}\n"
    printf "\n"
}

update_dokploy() {
    VERSION_TAG=$(detect_version)
    DOCKER_IMAGE="${DOKPLOY_IMAGE}:${VERSION_TAG}"

    echo "Updating Dokploy to version: ${VERSION_TAG} (${DOCKER_IMAGE})"
    docker pull $DOCKER_IMAGE
    docker service update --image $DOCKER_IMAGE dokploy
    echo "Dokploy has been updated to: ${DOCKER_IMAGE}"
}

# Main script execution
if [ "$1" = "update" ]; then
    update_dokploy
else
    install_dokploy
fi
