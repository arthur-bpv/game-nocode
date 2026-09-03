# Log de mudanças

Atualizado em: 2026-09-01

## UI e identidade visual

- Criado Theme compartilhado com Press Start 2P, paleta ciano/azul, painéis, botões e sliders.
- Removida a dependência ativa do PNG completo `ui_background_netbot_menu.png` nas cenas migradas.
- Menu inicial reconstruído com anchors e containers.
- Tablet reorganizado dentro da moldura existente e limitado a mapa, missões e tutorial.
- Configuração standalone também foi migrada para a nova tela de áudio, sem fundo completo hardcoded.

## Menu inicial

- Singleplayer agora usa `SceneTransition` para carregar o mundo.
- Multiplayer está desabilitado e marcado como “Em breve”.
- Escolha de cor e `TabletMenuPregame` foram removidos.
- Sair abre o modal compartilhado de confirmação.

## Pause e navegação

- Pause reconstruído como overlay responsivo.
- Adicionadas ações Continuar, Configurações, Voltar ao menu e Sair do jogo.
- Adicionadas confirmações para voltar ao menu e encerrar o jogo.
- Criado roteador central de ESC com prioridade para tablet, confirmação, áudio e pause.
- A cena ativa do mundo deixou de depender de `world.torch` para o ESC.

## Áudio

- Criados buses Master, Music e SFX.
- Criados sliders e controles de mute para os três buses.
- Adicionado botão Restaurar padrões.
- Configurações são persistidas em `user://settings.cfg`.
- Efeito Kenney existente é usado como prévia do volume SFX.

## Loading e desempenho

- Criado autoload `SceneTransition` com `ResourceLoader.load_threaded_request`.
- Criado loading minimalista com fundo escuro, NETBOT, texto e indicador animado.
- Removida a classificação pixel a pixel da máscara durante `_ready()` do mundo.
- Criado gerador de colisões e recurso persistido com três polígonos.
- Teste do mapa passou em aproximadamente 1,5 s incluindo a inicialização do Godot; antes, a geração em runtime levava aproximadamente 4 s no ambiente medido.

## Testes adicionados/atualizados

- `tests/ui_system_check.ps1`: contratos estruturais da nova UI.
- `tests/ui_navigation_check.ps1`: atualizado para o fluxo sem grafos ativos.
- `tests/ui_runtime_test.gd`: menu, buses, persistência, tablet, pause e prioridade do ESC.
- `tests/scene_transition_runtime_test.gd`: loading assíncrono e entrada no mundo.
- `tests/ui_render_test.gd`: capturas de menu em 720p/1080p/4K e telas de pause, áudio, confirmação, tablet e loading.
- Testes de mapa atualizados para exigir colisões pré-geradas.

## Resultado da última verificação

- 4 checks PowerShell: aprovados.
- UI runtime: aprovado.
- World map runtime: aprovado com três polígonos.
- Scene transition runtime: aprovado em 33 frames na última execução.
- Render visual OpenGL: aprovado.
- `git diff --check`: aprovado.
- Busca por credenciais: nenhum resultado.
- Nenhum arquivo em conflito no Git.

## Limitações conhecidas

- O encerramento do executável de console Godot retorna código 1 depois de imprimir sucesso, reproduzível até com smoke test vazio neste projeto.
- Os conteúdos de mapa, missões e tutorial do tablet ainda são placeholders.
- Não existe multiplayer nesta fase.
- A UI visual das tasks e sua filtragem temática ainda não foram implementadas.
- O fundo e logo definitivos do Canvas ainda não foram fornecidos.

