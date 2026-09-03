# Sistema de UI do NETBOT

As telas ativas usam `assets/ui/netbot_theme.tres`, containers e controles do Godot. PNGs devem conter somente decoração; textos, botões, sliders e seus estados não devem ser rasterizados na arte.

## Assets do Canvas

Para substituir o fundo provisório do menu sem voltar ao fluxo hardcoded, exporte:

- fundo limpo 16:9, preferencialmente 3840×2160, sem logo, texto, botão ou ícone;
- logo NETBOT em PNG transparente;
- opcionalmente, molduras, ícones e estados decorativos de botão em arquivos separados.

O `tablet_frame.png` já segue esse contrato e pode continuar sendo reutilizado.

## Colisões do mapa

`Mapa_anotacoes.png` é a fonte de autoria das áreas navegáveis. Quando o mapa ou a anotação mudar, regenere o recurso persistido antes de executar o jogo:

```powershell
godot --headless --path . --script res://tools/generate_collision_polygons.gd
```

O comando atualiza `assets/generated/collision_polygons.tres`. A cena do mundo carrega esse recurso e nunca percorre os pixels da máscara em runtime.

## Responsabilidades

- `SceneTransition`: transições e loading assíncrono.
- `AudioSettings`: buses Master, Music e SFX e persistência em `user://settings.cfg`.
- `PauseMenu`: pause, áudio, confirmações, retorno ao menu e encerramento.
- `GameplayTablet`: mapa, missões, tutorial e informações do ambiente; não contém configurações globais.
