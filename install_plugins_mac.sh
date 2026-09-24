#!/usr/bin/env bash

# ============================================================
# Instalador de plugins para Godot no macOS
#
# Godot 4.6.x
# Orchestrator 2.4.3
# Godot MCP Native 1.0.8
#
# Uso:
#
#   chmod +x install_plugins.sh
#   ./install_plugins.sh
#
# Requisitos:
# - macOS
# - Godot 4.6.x
# - Projeto Godot contendo project.godot
# - curl
# - unzip
#
# Depois da instalação:
#
# 1. Abra/reabra o projeto no Godot.
# 2. Vá em:
#
#    Project > Project Settings > Plugins
#
# 3. Ative:
#
#    Godot MCP Native
#
# 4. Abra o dock do MCP Native.
#
# ============================================================

set -euo pipefail


# ============================================================
# CORES
# ============================================================

COLOR_CYAN='\033[1;36m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[1;31m'
COLOR_RESET='\033[0m'


# ============================================================
# FUNÇÕES
# ============================================================

write_step() {
    echo
    printf "${COLOR_CYAN}==> %s${COLOR_RESET}\n" "$1"
}


write_success() {
    printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$1"
}


write_warning() {
    printf "${COLOR_YELLOW}Aviso: %s${COLOR_RESET}\n" "$1"
}


error_exit() {
    echo
    printf "${COLOR_RED}============================================${COLOR_RESET}\n"
    printf "${COLOR_RED} ERRO DURANTE A INSTALACAO${COLOR_RESET}\n"
    printf "${COLOR_RED}============================================${COLOR_RESET}\n"
    printf "${COLOR_RED}%s${COLOR_RESET}\n" "$1"
    exit 1
}


# ============================================================
# ARQUIVOS TEMPORÁRIOS
#
# O mktemp do macOS é diferente do GNU/Linux.
#
# Não usamos:
#
#   mktemp --suffix=.zip
#
# ============================================================

make_temp_file() {
    mktemp -t godot_plugin.XXXXXX
}


make_temp_dir() {
    mktemp -d -t godot_plugin.XXXXXX
}


# ============================================================
# VARIÁVEIS TEMPORÁRIAS
# ============================================================

ORCH_TMP=""
MCP_TMP=""
MCP_EXTRACT=""


# ============================================================
# LIMPEZA
# ============================================================

cleanup() {

    if [[ -n "${ORCH_TMP:-}" && -f "$ORCH_TMP" ]]; then
        rm -f "$ORCH_TMP" || true
    fi

    if [[ -n "${MCP_TMP:-}" && -f "$MCP_TMP" ]]; then
        rm -f "$MCP_TMP" || true
    fi

    if [[ -n "${MCP_EXTRACT:-}" && -d "$MCP_EXTRACT" ]]; then
        rm -rf "$MCP_EXTRACT" || true
    fi
}


trap cleanup EXIT


# ============================================================
# TRATAMENTO DE ERRO
# ============================================================

on_error() {

    local exit_code=$?
    local line_number=$1

    printf "\n${COLOR_RED}============================================${COLOR_RESET}\n"
    printf "${COLOR_RED} ERRO DURANTE A INSTALACAO${COLOR_RESET}\n"
    printf "${COLOR_RED}============================================${COLOR_RESET}\n"
    printf "${COLOR_RED}Erro na linha %s.${COLOR_RESET}\n" "$line_number"

    exit "$exit_code"
}


trap 'on_error $LINENO' ERR


# ============================================================
# DIRETÓRIO DO SCRIPT
# ============================================================

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd
)"

cd "$SCRIPT_DIR"


# ============================================================
# INFORMAÇÕES DO SISTEMA
# ============================================================

write_step "Verificando ambiente"

OS_NAME="$(uname -s)"

if [[ "$OS_NAME" != "Darwin" ]]; then
    write_warning "Este instalador foi preparado especificamente para macOS."
    write_warning "Sistema detectado: $OS_NAME"
fi

echo "Sistema: $(uname -s)"
echo "Arquitetura: $(uname -m)"
echo "Projeto: $SCRIPT_DIR"


# ============================================================
# VERIFICAR PROJECT.GODOT
# ============================================================

if [[ ! -f "$SCRIPT_DIR/project.godot" ]]; then
    error_exit "project.godot nao encontrado.

Coloque install_plugins.sh na pasta raiz do projeto Godot.

Exemplo:

meu-jogo/
├── project.godot
├── install_plugins.sh
├── scenes/
└── scripts/"
fi


# ============================================================
# VERIFICAR DEPENDÊNCIAS
# ============================================================

write_step "Verificando dependencias"

DEPENDENCIES=(
    curl
    unzip
    find
    cp
    rm
    mkdir
    uname
    mktemp
)

for cmd in "${DEPENDENCIES[@]}"; do

    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_exit "Dependencia ausente: $cmd"
    fi

    echo "OK: $cmd"

done

write_success "Dependencias verificadas."


# ============================================================
# CRIAR DIRETÓRIO ADDONS
# ============================================================

ADDONS_DIR="$SCRIPT_DIR/addons"

mkdir -p "$ADDONS_DIR"


# ============================================================
# 1) ORCHESTRATOR 2.4.3
# ============================================================

write_step "Instalando Orchestrator 2.4.3"

ORCHESTRATOR_VERSION="2.4.3"
ORCHESTRATOR_TAG="v2.4.3.stable"
ORCHESTRATOR_FILE="v2.4.3-stable"

ORCH_URL="https://github.com/CraterCrash/godot-orchestrator/releases/download/${ORCHESTRATOR_TAG}/godot-orchestrator-${ORCHESTRATOR_FILE}-plugin.zip"

ORCH_TMP="$(make_temp_file)"

echo
echo "URL:"
echo "$ORCH_URL"
echo

echo "Baixando Orchestrator..."

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    "$ORCH_URL" \
    --output "$ORCH_TMP"


if [[ ! -s "$ORCH_TMP" ]]; then
    error_exit "O download do Orchestrator retornou um arquivo vazio."
fi


echo
echo "Extraindo Orchestrator..."

unzip -o "$ORCH_TMP" -d "$SCRIPT_DIR"


rm -f "$ORCH_TMP"
ORCH_TMP=""


write_success "Orchestrator ${ORCHESTRATOR_VERSION} instalado."


# ============================================================
# VERIFICAR ORCHESTRATOR
# ============================================================

ORCHESTRATOR_DIR="$ADDONS_DIR/orchestrator"

if [[ -d "$ORCHESTRATOR_DIR" ]]; then

    write_success "Diretorio encontrado: addons/orchestrator/"

else

    write_warning "A pasta addons/orchestrator nao foi encontrada."

    echo
    echo "Pastas encontradas dentro de addons:"
    echo

    find "$ADDONS_DIR" \
        -maxdepth 2 \
        -type d \
        -print || true

fi


# ============================================================
# 2) GODOT MCP NATIVE 1.0.8
# ============================================================

write_step "Instalando Godot MCP Native 1.0.8"

MCP_VERSION="1.0.8"

MCP_URL="https://github.com/yurineko73/Godot-MCP-Native/archive/refs/tags/v${MCP_VERSION}.zip"

MCP_TMP="$(make_temp_file)"
MCP_EXTRACT="$(make_temp_dir)"


echo
echo "URL:"
echo "$MCP_URL"
echo


echo "Baixando Godot MCP Native ${MCP_VERSION}..."

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    "$MCP_URL" \
    --output "$MCP_TMP"


if [[ ! -s "$MCP_TMP" ]]; then
    error_exit "O download do Godot MCP Native retornou um arquivo vazio."
fi


echo
echo "Extraindo Godot MCP Native..."

unzip -q "$MCP_TMP" -d "$MCP_EXTRACT"


rm -f "$MCP_TMP"
MCP_TMP=""


# ============================================================
# LOCALIZAR addons/godot_mcp
# ============================================================

echo "Localizando addons/godot_mcp..."

MCP_ADDON_SOURCE="$(
    find "$MCP_EXTRACT" \
        -type d \
        -path "*/addons/godot_mcp" \
        -print \
        -quit
)"


if [[ -z "$MCP_ADDON_SOURCE" ]]; then

    echo
    echo "Conteudo encontrado no pacote:"
    echo

    find "$MCP_EXTRACT" \
        -maxdepth 4 \
        -type d \
        -print || true

    error_exit "Nao foi encontrada a pasta:

addons/godot_mcp

no pacote do Godot MCP Native ${MCP_VERSION}."
fi


echo "Addon encontrado em:"
echo "$MCP_ADDON_SOURCE"


# ============================================================
# DESTINO MCP
# ============================================================

MCP_ADDON_TARGET="$ADDONS_DIR/godot_mcp"


if [[ -d "$MCP_ADDON_TARGET" ]]; then

    echo
    echo "Instalacao anterior do Godot MCP Native encontrada."
    echo "Atualizando addon..."

    rm -rf "$MCP_ADDON_TARGET"

fi


cp -R "$MCP_ADDON_SOURCE" "$MCP_ADDON_TARGET"


rm -rf "$MCP_EXTRACT"
MCP_EXTRACT=""


write_success "Godot MCP Native ${MCP_VERSION} instalado."


# ============================================================
# 3) VERIFICAÇÃO DO GODOT MCP
# ============================================================

write_step "Verificando Godot MCP Native"

PLUGIN_CFG="$MCP_ADDON_TARGET/plugin.cfg"


if [[ ! -d "$MCP_ADDON_TARGET" ]]; then
    error_exit "A pasta addons/godot_mcp nao foi criada."
fi


if [[ ! -f "$PLUGIN_CFG" ]]; then
    error_exit "O arquivo abaixo nao foi encontrado:

addons/godot_mcp/plugin.cfg"
fi


write_success "plugin.cfg encontrado."


# ============================================================
# 4) VERIFICAR ESTRUTURA ADDONS
# ============================================================

write_step "Estrutura de addons instalada"

echo

find "$ADDONS_DIR" \
    -maxdepth 2 \
    -type d \
    -print


# ============================================================
# 5) RESULTADO
# ============================================================

echo
printf "${COLOR_GREEN}============================================${COLOR_RESET}\n"
printf "${COLOR_GREEN} INSTALACAO CONCLUIDA!${COLOR_RESET}\n"
printf "${COLOR_GREEN}============================================${COLOR_RESET}\n"

echo

printf "%-22s %s\n" "Orchestrator:" "2.4.3"
printf "%-22s %s\n" "Godot MCP Native:" "1.0.8"

echo

printf "%-22s %s\n" "Projeto:" "$SCRIPT_DIR"
printf "%-22s %s\n" "Addons:" "$ADDONS_DIR"

echo

printf "%-22s ${COLOR_GREEN}%s${COLOR_RESET}\n" \
    "Node.js:" \
    "NAO NECESSARIO"

printf "%-22s ${COLOR_GREEN}%s${COLOR_RESET}\n" \
    "npm:" \
    "NAO NECESSARIO"

echo

echo "Plugins:"
echo

if [[ -d "$ADDONS_DIR/orchestrator" ]]; then
    printf "  ${COLOR_GREEN}[OK]${COLOR_RESET} addons/orchestrator/\n"
else
    printf "  ${COLOR_YELLOW}[AVISO]${COLOR_RESET} addons/orchestrator/ nao localizado\n"
fi


if [[ -d "$ADDONS_DIR/godot_mcp" ]]; then
    printf "  ${COLOR_GREEN}[OK]${COLOR_RESET} addons/godot_mcp/\n"
else
    printf "  ${COLOR_RED}[ERRO]${COLOR_RESET} addons/godot_mcp/ nao localizado\n"
fi


echo
printf "${COLOR_CYAN}Proximos passos:${COLOR_RESET}\n"
echo
echo "1. Feche o Godot caso ele esteja aberto."
echo
echo "2. Abra novamente o projeto."
echo
echo "3. Acesse:"
echo
echo "      Project > Project Settings > Plugins"
echo
echo "4. Ative:"
echo
echo "      Godot MCP Native"
echo
echo "5. Ative também o Orchestrator caso apareça desativado."
echo
echo "6. Abra o dock do MCP Native e configure/inicie o servidor."
echo

printf "${COLOR_GREEN}Pronto.${COLOR_RESET}\n"
echo