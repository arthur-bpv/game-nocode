#!/usr/bin/env bash

# Godot 4.6.x + Orchestrator 2.4.3 + Godot MCP Native 1.0.8
# Execute com:
#   chmod +x install_plugins.sh
#   ./install_plugins.sh
#
# IMPORTANTE:
# - Este instalador usa o Godot MCP Native da Asset Library:
#   yurineko73 / Godot MCP Native / 1.0.8
# - O MCP Native nao precisa de Node.js, npm ou servidor externo.
# - O addon e instalado em res://addons/godot_mcp/
#
# Requisitos:
# - Godot 4.6.x
# - Projeto com project.godot
#
# Depois da instalacao:
# 1. Abra o projeto no Godot.
# 2. Va em Project > Project Settings > Plugins.
# 3. Ative "Godot MCP Native".
# 4. Abra o dock do MCP para configurar/iniciar o servidor.

set -euo pipefail

write_step() {
    echo
    printf '\033[1;36m==> %s\033[0m\n' "$1"
}

error_exit() {
    echo
    printf '\033[1;31m============================================\033[0m\n'
    printf '\033[1;31m ERRO DURANTE A INSTALACAO\033[0m\n'
    printf '\033[1;31m============================================\033[0m\n'
    printf '\033[1;31m%s\033[0m\n' "$1"
    exit 1
}

ORCH_TMP=""
MCP_TMP=""
MCP_EXTRACT=""

cleanup() {
    if [[ -n "$ORCH_TMP" ]]; then rm -f "$ORCH_TMP" || true; fi
    if [[ -n "$MCP_TMP" ]]; then rm -f "$MCP_TMP" || true; fi
    if [[ -n "$MCP_EXTRACT" ]]; then rm -rf "$MCP_EXTRACT" || true; fi
}

trap 'error_exit "Erro na linha $LINENO."' ERR
trap cleanup EXIT

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "project.godot" ]]; then
    error_exit "project.godot nao encontrado. Execute o script dentro da pasta do projeto."
fi

for cmd in curl unzip find cp rm mkdir; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_exit "Dependencia ausente: $cmd"
    fi
done

# ============================================================
# 1) ORCHESTRATOR 2.4.3
# ============================================================

write_step "Instalando Orchestrator 2.4.3"

ORCHESTRATOR_TAG="v2.4.3.stable"
ORCHESTRATOR_FILE="v2.4.3-stable"

ORCH_TMP="$(mktemp --suffix=.zip)"

ORCH_URL="https://github.com/CraterCrash/godot-orchestrator/releases/download/${ORCHESTRATOR_TAG}/godot-orchestrator-${ORCHESTRATOR_FILE}-plugin.zip"

echo "Baixando Orchestrator..."

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    "$ORCH_URL" \
    --output "$ORCH_TMP"

echo "Extraindo Orchestrator..."

unzip -o "$ORCH_TMP" -d "$SCRIPT_DIR"

rm -f "$ORCH_TMP"

printf '\033[1;32mOrchestrator instalado.\033[0m\n'


# ============================================================
# 2) GODOT MCP NATIVE 1.0.8
# ============================================================

write_step "Instalando Godot MCP Native 1.0.8"

MCP_VERSION="1.0.8"

MCP_TMP="$(mktemp --suffix=.zip)"
MCP_EXTRACT="$(mktemp -d)"

MCP_URL="https://github.com/yurineko73/Godot-MCP-Native/archive/refs/tags/v${MCP_VERSION}.zip"

echo "Baixando Godot MCP Native ${MCP_VERSION}..."

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    "$MCP_URL" \
    --output "$MCP_TMP"

echo "Extraindo Godot MCP Native..."

unzip -q "$MCP_TMP" -d "$MCP_EXTRACT"

rm -f "$MCP_TMP"

# Localiza addons/godot_mcp dentro da pasta extraida.

MCP_ADDON_SOURCE="$(
    find "$MCP_EXTRACT" \
        -type d \
        -path "*/addons/godot_mcp" \
        -print \
        -quit
)"

if [[ -z "$MCP_ADDON_SOURCE" ]]; then
    rm -rf "$MCP_EXTRACT"
    error_exit "Nao foi encontrada a pasta addons/godot_mcp no pacote do Godot MCP Native ${MCP_VERSION}."
fi

ADDONS_DIR="${SCRIPT_DIR}/addons"
MCP_ADDON_TARGET="${ADDONS_DIR}/godot_mcp"

mkdir -p "$ADDONS_DIR"

if [[ -d "$MCP_ADDON_TARGET" ]]; then
    echo "Uma instalacao anterior do Godot MCP Native foi encontrada. Atualizando..."
    rm -rf "$MCP_ADDON_TARGET"
fi

cp -a "$MCP_ADDON_SOURCE" "$MCP_ADDON_TARGET"

rm -rf "$MCP_EXTRACT"

printf '\033[1;32mGodot MCP Native %s instalado.\033[0m\n' "$MCP_VERSION"


# ============================================================
# 3) VERIFICACAO
# ============================================================

write_step "Verificando instalacao"

PLUGIN_CFG="${MCP_ADDON_TARGET}/plugin.cfg"

if [[ ! -f "$PLUGIN_CFG" ]]; then
    error_exit "O arquivo plugin.cfg do Godot MCP Native nao foi encontrado."
fi

ORCHESTRATOR_DIR="${ADDONS_DIR}/orchestrator"

if [[ ! -d "$ORCHESTRATOR_DIR" ]]; then
    printf '\033[1;33mAviso: a pasta addons/orchestrator nao foi encontrada. Verifique a instalacao do Orchestrator.\033[0m\n'
fi

echo
printf '\033[1;32m============================================\033[0m\n'
printf '\033[1;32m INSTALACAO CONCLUIDA!\033[0m\n'
printf '\033[1;32m============================================\033[0m\n'
echo
echo "Orchestrator:       2.4.3"
echo "Godot MCP Native:   1.0.8"
echo "MCP addon:          addons/godot_mcp/"
echo
printf 'Node.js:            \033[1;32mNAO NECESSARIO\033[0m\n'
printf 'npm:                \033[1;32mNAO NECESSARIO\033[0m\n'
echo
echo "Proximo passo:"
echo "1. Abra/reabra o projeto no Godot."
echo "2. Va em Project > Project Settings > Plugins."
echo "3. Ative o plugin 'Godot MCP Native'."
echo "4. Abra o dock MCP Native e configure o servidor."
echo
