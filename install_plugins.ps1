# Godot 4.6.x + Orchestrator 2.4.3 + Godot MCP Native 1.0.8
# Execute no PowerShell: .\install_plugins.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$orchestratorVersion = "2.4.3"
$orchestratorTag = "v2.4.3.stable"
$orchestratorFile = "v2.4.3-stable"
$mcpVersion = "1.0.8"
$scriptDir = $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("game-nocode-plugins-" + [guid]::NewGuid().ToString("N"))

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $scriptDir "project.godot") -PathType Leaf)) {
        throw "project.godot nao encontrado ao lado do instalador."
    }

    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $addonsDir = Join-Path $scriptDir "addons"
    New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null

    Write-Step "Instalando Orchestrator $orchestratorVersion"

    $orchestratorZip = Join-Path $tempRoot "orchestrator.zip"
    $orchestratorUrl = "https://github.com/CraterCrash/godot-orchestrator/releases/download/$orchestratorTag/godot-orchestrator-$orchestratorFile-plugin.zip"

    Write-Host "Baixando Orchestrator..."
    Invoke-WebRequest -Uri $orchestratorUrl -OutFile $orchestratorZip

    Write-Host "Extraindo Orchestrator..."
    Expand-Archive -LiteralPath $orchestratorZip -DestinationPath $scriptDir -Force
    Write-Host "Orchestrator instalado." -ForegroundColor Green

    Write-Step "Instalando Godot MCP Native $mcpVersion"

    $mcpZip = Join-Path $tempRoot "godot-mcp-native.zip"
    $mcpExtract = Join-Path $tempRoot "godot-mcp-native"
    $mcpUrl = "https://github.com/yurineko73/Godot-MCP-Native/archive/refs/tags/v$mcpVersion.zip"

    Write-Host "Baixando Godot MCP Native $mcpVersion..."
    Invoke-WebRequest -Uri $mcpUrl -OutFile $mcpZip

    Write-Host "Extraindo Godot MCP Native..."
    Expand-Archive -LiteralPath $mcpZip -DestinationPath $mcpExtract -Force

    $mcpAddonSource = Get-ChildItem -LiteralPath $mcpExtract -Directory -Recurse |
        Where-Object { $_.Name -eq "godot_mcp" -and $_.Parent.Name -eq "addons" } |
        Select-Object -First 1

    if (-not $mcpAddonSource) {
        throw "Nao foi encontrada a pasta addons/godot_mcp no pacote do Godot MCP Native $mcpVersion."
    }

    $mcpAddonTarget = Join-Path $addonsDir "godot_mcp"
    if (Test-Path -LiteralPath $mcpAddonTarget) {
        Write-Host "Uma instalacao anterior do Godot MCP Native foi encontrada. Atualizando..."
        Remove-Item -LiteralPath $mcpAddonTarget -Recurse -Force
    }

    Copy-Item -LiteralPath $mcpAddonSource.FullName -Destination $mcpAddonTarget -Recurse -Force

    Write-Step "Verificando instalacao"

    if (-not (Test-Path -LiteralPath (Join-Path $mcpAddonTarget "plugin.cfg") -PathType Leaf)) {
        throw "O arquivo plugin.cfg do Godot MCP Native nao foi encontrado."
    }

    if (-not (Test-Path -LiteralPath (Join-Path $addonsDir "orchestrator") -PathType Container)) {
        Write-Warning "A pasta addons/orchestrator nao foi encontrada. Verifique a estrutura do pacote."
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " INSTALACAO CONCLUIDA!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Orchestrator:       $orchestratorVersion"
    Write-Host "Godot MCP Native:   $mcpVersion"
    Write-Host "MCP addon:          addons/godot_mcp/"
    Write-Host "Node.js / npm:      NAO NECESSARIOS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Abra/reabra o projeto, acesse Project > Project Settings > Plugins"
    Write-Host "e ative 'Godot MCP Native'."
}
catch {
    Write-Host "Falha na instalacao: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
