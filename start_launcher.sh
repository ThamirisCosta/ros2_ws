#!/bin/bash

# Script genérico para iniciar um ambiente ROS 2 com suporte a Gazebo
# para uso em novos projetos de simulação de UAVs.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-ros-jazzy-container}"
ROS_DISTRO_NAME="${ROS_DISTRO:-jazzy}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
    echo "Erro: Docker não está instalado ou não está no PATH."
    echo "Instale com: sudo apt update && sudo apt install -y docker.io docker-compose-plugin"
    exit 1
fi

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    echo "Erro: acesso negado ao daemon do Docker."
    echo "Seu usuário precisa pertencer ao grupo docker."
    echo "Execute:"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo "ou faça logout/login e tente novamente."
    exit 1
fi

echo "Iniciando ambiente ROS 2 + Gazebo..."

# Configuração do X11 para interface gráfica
if command -v xhost >/dev/null 2>&1; then
    xhost +local:docker 2>/dev/null || true
else
    echo "Aviso: xhost não está instalado; a GUI pode não funcionar sem ele."
fi

# Iniciar o container se ele não estiver em execução
if ! "$DOCKER_BIN" ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    if "$DOCKER_BIN" ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
        echo "Container encontrado em estado parado. Iniciando..."
        "$DOCKER_BIN" start "$CONTAINER_NAME" >/dev/null
    else
        echo "Container não encontrado. Criando imagem e iniciando..."
        "$DOCKER_BIN" compose -f "$SCRIPT_DIR/docker-compose.yml" up -d --build
    fi
    sleep 2
fi

# Entrar no container com o workspace já montado
# Se quiser executar um comando específico, use:
#   ROS_COMMAND="ros2 topic list" ./start_launcher.sh
# ou simplesmente rode o script para abrir um shell interativo.
if [ -n "${ROS_COMMAND:-}" ]; then
    "$DOCKER_BIN" exec -it "$CONTAINER_NAME" bash -lc "
        set -e
        source /opt/ros/${ROS_DISTRO_NAME}/setup.bash
        cd /ros2_ws
        ${ROS_COMMAND}
    "
else
    "$DOCKER_BIN" exec -it "$CONTAINER_NAME" bash -lc "
        set -e
        source /opt/ros/${ROS_DISTRO_NAME}/setup.bash
        cd /ros2_ws
        exec bash
    "
fi