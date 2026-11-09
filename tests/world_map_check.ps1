$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
$catalog = Get-Content -Raw (Join-Path $project_root "data/study/catalog.tres")
$tablet = Get-Content -Raw (Join-Path $project_root "scenes/tablet/TabletMenu.tscn")

if ($world_scene -notmatch 'name="MapLayout".*instance=ExtResource\("8_modular"\)') {
    throw "O mundo não instancia o mapa modular."
}
if ($world_scene -match 'name="MapSprite"|name="WorldWalls"') {
    throw "O mapa único e suas colisões antigas não devem estar ativos."
}
if ($tablet -notmatch 'name="StationMinimap" type="Control"' -or $tablet -match 'modular_map_overview\.png|tablet_frame\.png') {
    throw "O tablet deve usar moldura nativa e minimapa desenhado a partir dos tiles."
}

$room_scenes = @(Get-ChildItem -LiteralPath (Join-Path $project_root "scenes/world/rooms") -Filter "*_room.tscn")
$corridor_scenes = @(Get-ChildItem -LiteralPath (Join-Path $project_root "scenes/world/corridors") -Filter "*_corridor.tscn")
if ($room_scenes.Count -ne 7 -or $corridor_scenes.Count -ne 6) {
    throw "A seção deve ter sete salas e seis tipos de corredor."
}
foreach ($piece in @($room_scenes) + @($corridor_scenes)) {
    $content = Get-Content -Raw -LiteralPath $piece.FullName
    if ($content -notmatch 'name="Walls" type="StaticBody2D"') {
        throw "Colisão editável ausente: $($piece.Name)"
    }
}
foreach ($slot_id in @(
    "sala_inferior_esquerda_principal",
    "sala_superior_direita_principal",
    "sala_inferior_central_principal"
)) {
    if ($catalog -notmatch [regex]::Escape($slot_id)) {
        throw "Task sem vínculo com o slot físico $slot_id."
    }
}

Write-Host "World map modular checks passed."
