#!/bin/bash
# Godot 4.6.x + Orchestrator 2.4.3
set -e

ORCHESTRATOR_VERSION="v2.4.3.stable"

echo "Instalando Orchestrator ${ORCHESTRATOR_VERSION}..."
curl -L "https://github.com/CraterCrash/godot-orchestrator/releases/download/${ORCHESTRATOR_VERSION}/godot-orchestrator-${ORCHESTRATOR_VERSION}-plugin.zip" \
  -o /tmp/orchestrator.zip
unzip -o /tmp/orchestrator.zip -d .
rm /tmp/orchestrator.zip
echo "Pronto. Abra o projeto no Godot 4.6.x."
