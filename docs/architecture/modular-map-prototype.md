# Mapa da estação em tiles

O mapa jogável está em `scenes/world/maps/tile_station.tscn`. Abra a cena no
Godot e selecione uma camada para pintar ou apagar células de **32 × 32**.
`world.tscn` e as variações de mundo usam essa cena.

| Camada | Função |
| --- | --- |
| `Floor` | Pisos, variações e sinalização que o personagem pode atravessar. |
| `Walls` | Paredes, cantos e laterais dos corredores. Cada célula dessa camada tem colisão no TileSet. |
| `Details` | Painéis de sinalização por setor, com passagem livre. |
| `Pieces` | Âncoras que associam as missões aos setores por ID. |

O TileSet compartilhado é `assets/sprites/map/netbot_station_tiles.tres`. A
sprite sheet `assets/sprites/map/netbot_station_tiles.png`, criada no PixelLab,
tem 8 colunas e 6 linhas. A primeira linha contém pisos e marcas de circulação.
As duas linhas seguintes contêm as 16 combinações de parede conforme os lados
voltados para o piso. A quarta linha contém painéis de piso, grelhas e balizas. A quinta contém
reforços, ventilação e janelas que atravessam três células de parede. A sexta
fornece as quatro orientações de colisão triangular. O acabamento visível dos
chanfros é uma faixa contínua de polígonos em `BevelFinishes`, gerada por trecho
a partir das células da parede. Cada ponta usa o perfil da parede reta que
recebe o chanfro, inclusive quando o recorte liga duas faces horizontais.

Os corredores horizontais, verticais, curtos e em L são feitos com as mesmas
células de piso e parede. O corredor central segue um eixo reto de sete células
de largura. As saídas sob as salas superiores esquerda e direita são
alinhadas ao centro de cada sala.

O gerador `tools/build_tile_station_map.gd` registra as dimensões iniciais dos
setores e corredores. Regenerar substitui a cena e o TileSet, incluindo edições
manuais nesses arquivos. O tablet desenha o minimapa a partir das camadas de
piso e parede da cena ativa, com o marcador na posição do jogador. A
[prévia completa](modular-map-preview.png) é uma imagem de documentação.

A composição antiga de sprites por sala fica em
`scenes/world/maps/central_section_prototype.tscn` para consulta.
