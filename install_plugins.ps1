# Godot 4.6.x + Orchestrator 2.4.3
$ErrorActionPreference = "Stop"

$ORCHESTRATOR_VERSION = "v2.4.3.stable"
$TMP = "$env:TEMP\orchestrator.zip"

Write-Host "Instalando Orchestrator $ORCHESTRATOR_VERSION..."
Invoke-WebRequest -Uri "https://github.com/CraterCrash/godot-orchestrator/releases/download/$ORCHESTRATOR_VERSION/godot-orchestrator-$ORCHESTRATOR_VERSION-plugin.zip" -OutFile $TMP
Expand-Archive -Path $TMP -DestinationPath "." -Force
Remove-Item $TMP
Write-Host "Pronto. Abra o projeto no Godot 4.6.x."
