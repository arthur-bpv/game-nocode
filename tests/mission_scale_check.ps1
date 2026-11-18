$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$mission_scene = Get-Content -Raw (Join-Path $project_root "scenes/missions/conecta_camadas.tscn")
$panel_scene = Get-Content -Raw (Join-Path $project_root "scenes/missions/network_repair_panel.tscn")
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
$room_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/rooms/upper_left_room.tscn")
$catalog = Get-Content -Raw (Join-Path $project_root "data/study/catalog.tres")
$player_scene = Get-Content -Raw (Join-Path $project_root "scenes/player/player.tscn")

if ($panel_scene -notmatch "(?m)^offset_right = 680\.0$") {
	throw "A task deve ter largura lógica de 680 px."
}
if ($panel_scene -notmatch "(?m)^offset_bottom = 460\.0$") {
	throw "A task deve ter altura lógica de 460 px."
}
if ($mission_scene -notmatch 'network_repair_panel\.tscn') {
	throw "A task deve usar o painel compartilhado."
}

if ($world_scene -notmatch 'name="MapLayout".*instance=ExtResource\("8_modular"\)') {
	throw "O mundo deve instanciar o mapa modular."
}
$room_anchor = [regex]::Match(
	$room_scene,
	'(?ms)\[node name="Primary"[^\]]*parent="MissionSlots"[^\]]*\](.*?)(?=\r?\n\[node |\z)'
)
if (-not $room_anchor.Success) {
	throw "Âncora da missão ausente da sala superior esquerda."
}
if ($room_anchor.Groups[1].Value -notmatch '(?m)^slot_id = &"sala_superior_esquerda_principal"\r?$') {
	throw "Âncora da missão fora da sala superior esquerda."
}
if ($catalog -notmatch '(?m)^id = &"conecta_camadas"\r?\n[^\[]*?map_slot = &"sala_superior_esquerda_principal"') {
	throw "A task de camadas deve usar o slot da sala superior esquerda."
}

if ($player_scene -notmatch "scale = Vector2\(1\.951538, 2\.090698\)") {
	throw "O personagem não deve ser reduzido para compensar a task."
}

Write-Host "Mission scale static checks passed."
