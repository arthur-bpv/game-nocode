# Godot 4.6.x + Orchestrator 2.4.3 + Godot MCP Native 1.0.8
# Execute com: clique direito -> "Executar com PowerShell"
# ou no terminal: .\install_plugins_godot_mcp_native.ps1
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

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $scriptDir

    if (-not (Test-Path "project.godot")) {
        throw "project.godot nao encontrado. Execute o script dentro da pasta do projeto."
    }

    # ============================================================
    # 1) ORCHESTRATOR 2.4.3
    # ============================================================
    Write-Step "Instalando Orchestrator 2.4.3"

    $ORCHESTRATOR_TAG = "v2.4.3.stable"
    $ORCHESTRATOR_FILE = "v2.4.3-stable"
    $ORCH_TMP = Join-Path $env:TEMP "orchestrator.zip"
    $ORCH_URL = "https://github.com/CraterCrash/godot-orchestrator/releases/download/$ORCHESTRATOR_TAG/godot-orchestrator-$ORCHESTRATOR_FILE-plugin.zip"

    Write-Host "Baixando Orchestrator..."
    Invoke-WebRequest -Uri $ORCH_URL -OutFile $ORCH_TMP -UseBasicParsing

    Write-Host "Extraindo Orchestrator..."
    Expand-Archive -Path $ORCH_TMP -DestinationPath $scriptDir -Force
    Remove-Item $ORCH_TMP -Force -ErrorAction SilentlyContinue

    Write-Host "Orchestrator instalado." -ForegroundColor Green

    # ============================================================
    # 2) GODOT MCP NATIVE 1.0.8
    # ============================================================
    Write-Step "Instalando Godot MCP Native 1.0.8"

    $MCP_VERSION = "1.0.8"
    $MCP_TMP = Join-Path $env:TEMP "godot-mcp-native-$MCP_VERSION.zip"
    $MCP_EXTRACT = Join-Path $env:TEMP "godot-mcp-native-$MCP_VERSION"

    # O repositorio usa a tag v1.0.8.
    # O arquivo contem o addon em:
    # addons/godot_mcp/
    $MCP_URL = "https://github.com/yurineko73/Godot-MCP-Native/archive/refs/tags/v$MCP_VERSION.zip"

    if (Test-Path $MCP_EXTRACT) {
        Remove-Item $MCP_EXTRACT -Recurse -Force
    }

    Write-Host "Baixando Godot MCP Native $MCP_VERSION..."
    Invoke-WebRequest -Uri $MCP_URL -OutFile $MCP_TMP -UseBasicParsing

    Write-Host "Extraindo Godot MCP Native..."
    Expand-Archive -Path $MCP_TMP -DestinationPath $MCP_EXTRACT -Force
    Remove-Item $MCP_TMP -Force -ErrorAction SilentlyContinue

    # Localiza addons/godot_mcp dentro da pasta extraida.
    $mcpAddonSource = Get-ChildItem -Path $MCP_EXTRACT -Directory -Recurse |
        Where-Object { $_.Name -eq "godot_mcp" } |
        Select-Object -First 1

    if (-not $mcpAddonSource) {
        throw "Nao foi encontrada a pasta addons/godot_mcp no pacote do Godot MCP Native $MCP_VERSION."
    }

    $addonsDir = Join-Path $scriptDir "addons"
    $mcpAddonTarget = Join-Path $addonsDir "godot_mcp"

    New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null

    if (Test-Path $mcpAddonTarget) {
        Write-Host "Uma instalacao anterior do Godot MCP Native foi encontrada. Atualizando..."
        Remove-Item $mcpAddonTarget -Recurse -Force
    }

    Copy-Item -Path $mcpAddonSource.FullName -Destination $mcpAddonTarget -Recurse -Force

    Remove-Item $MCP_EXTRACT -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Godot MCP Native $MCP_VERSION instalado." -ForegroundColor Green

    # ============================================================
    # 3) VERIFICACAO
    # ============================================================
    Write-Step "Verificando instalacao"

    $pluginCfg = Join-Path $mcpAddonTarget "plugin.cfg"

    if (-not (Test-Path $pluginCfg)) {
        throw "O arquivo plugin.cfg do Godot MCP Native nao foi encontrado."
    }

    $orchestratorDir = Join-Path $addonsDir "orchestrator"

    if (-not (Test-Path $orchestratorDir)) {
        Write-Host "Aviso: a pasta addons/orchestrator nao foi encontrada. Verifique a instalacao do Orchestrator." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " INSTALACAO CONCLUIDA!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Orchestrator:       2.4.3"
    Write-Host "Godot MCP Native:   1.0.8"
    Write-Host "MCP addon:          addons/godot_mcp/"
    Write-Host ""
    Write-Host "Node.js:            NAO NECESSARIO" -ForegroundColor Green
    Write-Host "npm:                NAO NECESSARIO" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximo passo:"
    Write-Host "1. Abra/reabra o projeto no Godot."
    Write-Host "2. Va em Project > Project Settings > Plugins."
    Write-Host "3. Ative o plugin 'Godot MCP Native'."
    Write-Host "4. Abra o dock MCP Native e configure o servidor."
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERRO DURANTE A INSTALACAO" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
}
finally {
    Write-Host ""
    Read-Host "Pressione Enter para fechar"
}
