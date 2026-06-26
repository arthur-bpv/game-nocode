# Godot 4.6.x + Orchestrator 2.4.3
# Execute com: clique direito -> "Executar com PowerShell"
# ou no terminal: .\install_plugins.ps1

$ErrorActionPreference = "Stop"

try {
    # Garante que está rodando na pasta do projeto (onde fica o project.godot)
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $scriptDir

    if (-not (Test-Path "project.godot")) {
        throw "project.godot nao encontrado. Execute o script dentro da pasta do projeto."
    }

    $ORCHESTRATOR_TAG = "v2.4.3.stable"
    $ORCHESTRATOR_FILE = "v2.4.3-stable"
    $TMP = "$env:TEMP\orchestrator.zip"
    $URL = "https://github.com/CraterCrash/godot-orchestrator/releases/download/$ORCHESTRATOR_TAG/godot-orchestrator-$ORCHESTRATOR_FILE-plugin.zip"

    Write-Host "Instalando Orchestrator $ORCHESTRATOR_TAG em: $scriptDir"
    Write-Host "Baixando..."
    Invoke-WebRequest -Uri $URL -OutFile $TMP -UseBasicParsing
    Write-Host "Extraindo..."
    Expand-Archive -Path $TMP -DestinationPath $scriptDir -Force
    Remove-Item $TMP
    Write-Host ""
    Write-Host "Pronto! Abra o projeto no Godot 4.6.x."
}
catch {
    Write-Host ""
    Write-Host "ERRO: $_" -ForegroundColor Red
}
finally {
    Write-Host ""
    Read-Host "Pressione Enter para fechar"
}
