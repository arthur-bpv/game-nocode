# Lógica de runtime em GDScript

Atualizado em: 2026-09-21

Toda a lógica executável do jogo está em scripts de texto versionáveis e pesquisáveis. As
cenas apenas declaram nós, recursos e conexões de sinais; não há grafos visuais de código.

## Responsabilidades

- `scenes/player/player_controller.gd`: lê as ações direcionais, calcula a velocidade a
  `460 px/s` e chama `move_and_slide()` a cada frame de física.
- `scenes/tablet/tablet_interaction.gd`: acompanha jogadores dentro da área do tablet,
  exibe a dica de interação e abre `TabletUi` quando a ação `interact` é pressionada.
- `scenes/world/world_controller.gd`: coordena tablet, missões e menu de pausa, inclusive
  enquanto a árvore está pausada.
- `scripts/ui/main_menu.gd`, `pause_menu.gd`, `settings_screen.gd` e `volume_screen.gd`:
  controlam navegação e configurações sem lógica embutida nas cenas.

## Regras de manutenção

1. Novos comportamentos devem ser implementados em `.gd` com nomes que expressem sua
   responsabilidade.
2. Scripts específicos de uma cena ficam ao lado da cena; sistemas compartilhados ficam
   em `scripts/`.
3. Cenas não devem referenciar formatos de scripting visual ou classes fornecidas por
   extensões de terceiros.
4. `tests/dependency_cleanup_check.ps1` protege essa fronteira arquitetural.
