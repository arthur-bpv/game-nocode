# Contexto para próximas sessões Codex

Atualizado em: 2026-09-01

## Objetivo do projeto nesta frente

O NETBOT está migrando de telas completas desenhadas como PNG para uma UI reutilizável no Godot. PNGs devem ser usados apenas como decoração; textos, botões, sliders, estados e navegação ficam em cenas, controles e scripts do Godot.

A primeira fase implementada cobre menu inicial, loading, pause, configurações de áudio, confirmações e tablet. A reconstrução visual das tasks e a filtragem delas por temática ainda não fazem parte desta fase.

## Decisões confirmadas pelo usuário

- Suporte atual: 16:9 em 1280×720, 1920×1080 e 3840×2160.
- Fonte: Press Start 2P já presente no projeto e licenciada por OFL.
- Multiplayer permanece visível, desabilitado e marcado como “Em breve”.
- A escolha de cor do personagem foi removida do fluxo por enquanto; usa-se a cor padrão.
- O tablet contém apenas assuntos do jogo/ambiente: mapa, missões e tutorial.
- Configurações globais não pertencem ao tablet.
- O pause deve oferecer Continuar, Configurações, Voltar ao menu e Sair do jogo.
- Voltar ao menu e sair completamente exigem confirmação.
- Configurações v1: Master, Music e SFX, com persistência local.
- Loading: apresentação minimalista feita no Godot.
- Não integrar a branch `davi` por merge ou cherry-pick. Ela foi usada apenas como referência comportamental e contém alterações ruidosas e mais PNGs completos.

## Arquitetura implementada

- `assets/ui/netbot_theme.tres`: Theme compartilhado para fonte, cores, painéis, botões e sliders.
- `scripts/autoload/scene_transition.gd`: autoload `SceneTransition`; carrega cenas em thread e mostra loading minimalista.
- `scripts/autoload/audio_settings.gd`: autoload `AudioSettings`; controla Master/Music/SFX e persiste em `user://settings.cfg`.
- `default_bus_layout.tres`: buses Master, Music e SFX.
- `scripts/ui/confirmation_modal.gd` + `scenes/ui/ConfirmationModal.tscn`: modal reutilizável.
- `scripts/ui/main_menu.gd` + `scenes/menu.tscn`: menu inicial reconstruído com controles reais.
- `scripts/ui/pause_menu.gd` + `scenes/Pause.tscn`: pause como overlay, com áudio e confirmações.
- `scenes/world/world_controller.gd`: roteador central de ESC em um nó com `process_mode = ALWAYS`.
- `scenes/tablet/tablet_menu.gd` + `TabletMenu.tscn`: tablet separado de configurações globais.
- `tools/generate_collision_polygons.gd`: ferramenta que converte o mapa anotado em colisões persistidas.
- `assets/generated/collision_polygons.tres`: três polígonos carregados em runtime.

## Prioridade do ESC

1. Se o tablet estiver aberto, fecha somente o tablet.
2. Se uma confirmação estiver aberta, cancela a confirmação.
3. Se a tela de áudio estiver aberta, volta às ações do pause.
4. Se o pause estiver aberto, continua a partida.
5. Se nenhuma UI estiver aberta, pausa o jogo e abre o menu.

O roteador fica em `CanvasLayer/UiController`, não no nó raiz do mundo. Isso é necessário para continuar recebendo input enquanto `SceneTree.paused` está ativo.

## Mapa e colisões

O mapa permanece uma imagem única em 4K. `Mapa_anotacoes.png` é a fonte de autoria das áreas navegáveis, mas não é lida em runtime.

Depois de modificar o mapa ou a anotação, executar:

```powershell
godot --headless --path . --script res://tools/generate_collision_polygons.gd
```

O comando regenera `assets/generated/collision_polygons.tres`. O teste atual confirma três polígonos: limite externo e dois obstáculos internos.

## Estado importante do worktree

A branch usada é `chore/cleanup-e-classifica-assets`. O worktree já estava sujo antes da evolução da UI. Não restaurar, apagar nem atribuir automaticamente estes arquivos à mudança de UI:

- imagens em `addons/godot_mcp`, `addons/orchestrator`, `assets/sprites` e `assets/ui/classifica`;
- alterações de missão em `scenes/missions`;
- alterações de personagem em `scenes/player/player.tscn`;
- `scenes/tablet/tablet.torch`;
- mapa, anotação, colisões e testes de mapa criados na frente anterior;
- arquivos TMP do Orchestrator.

Preservar especialmente a escala/posição do personagem, a task na sala octagonal e a geometria atual do mapa.

## Verificação conhecida

Os testes imprimem sucesso e não apresentam erro de parser ou assertion. Porém, qualquer script Godot neste projeto — inclusive um smoke test vazio — termina com código 1 no shutdown das extensões carregadas. Sem `--disable-crash-handler`, o Godot 4.6 mostra uma falha nativa ao encerrar, provavelmente relacionada ao ambiente de extensões/Orchestrator. Tratar isso separadamente; não confundir com falha da UI.

As capturas de verificação ficam em `.godot/ui_*.png` e não são artefatos para commit.

## Material ainda esperado do Canvas

- Fundo limpo 16:9, preferencialmente 3840×2160, sem logo, textos, botões ou ícones.
- Logo NETBOT em PNG transparente.
- Opcional: molduras, ícones e estados decorativos de botão separados.

O `tablet_frame.png` atual já pode ser reutilizado. A UI funciona sem esses novos assets; o fundo atual é procedural/provisório.
