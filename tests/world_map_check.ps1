$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$map_path = Join-Path $project_root "assets/sprites/Mapa.png"
$mask_path = Join-Path $project_root "assets/sprites/Mapa_anotacoes.png"
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
$walls_script = Get-Content -Raw (Join-Path $project_root "scenes/world/world_walls.gd")
$generator_script = Get-Content -Raw (Join-Path $project_root "tools/generate_collision_polygons.gd")
$collision_resource_path = Join-Path $project_root "assets/generated/collision_polygons.tres"

Add-Type -AssemblyName System.Drawing

foreach ($asset in @(
	@{ Path = $map_path; Width = 4080; Height = 2295 },
	@{ Path = $mask_path; Width = 2160; Height = 1215 }
)) {
	if (-not (Test-Path -LiteralPath $asset.Path)) {
		throw "Asset de mapa ausente: $($asset.Path)"
	}
	$image = [System.Drawing.Image]::FromFile($asset.Path)
	try {
		if ($image.Width -ne $asset.Width -or $image.Height -ne $asset.Height) {
			throw "O asset '$($asset.Path)' deve medir $($asset.Width)x$($asset.Height); atual: $($image.Width)x$($image.Height)."
		}
	}
	finally {
		$image.Dispose()
	}
}

if (-not (Test-Path -LiteralPath $collision_resource_path)) {
	throw "O recurso persistido de colisões não foi gerado."
}
if ($walls_script -match 'Mapa_anotacoes|get_pixel|BitMap\.new') {
	throw "WorldWalls não pode ler ou classificar pixels em runtime."
}
if ($walls_script -notmatch 'collision_polygons\.tres') {
	throw "WorldWalls deve carregar o recurso persistido de polígonos."
}
if ($generator_script -notmatch 'MAP_MASK_PATH := "res://assets/sprites/Mapa_anotacoes\.png"') {
	throw "A ferramenta deve usar a imagem anotada como fonte de autoria."
}
if ($generator_script -notmatch 'ResourceSaver\.save') {
	throw "A ferramenta deve persistir os polígonos gerados."
}
foreach ($classification in @("is_yellow", "is_blue", "is_green")) {
	if ($generator_script -notmatch $classification) {
		throw "Classificação de área ausente: $classification"
	}
}

$map_node = [regex]::Match(
	$world_scene,
	'(?ms)\[node name="MapSprite"[^\]]*\](.*?)(?=\r?\n\[node |\z)'
)
if (-not $map_node.Success) {
	throw "MapSprite ausente da cena do mundo."
}
if ($map_node.Groups[1].Value -match '(?m)^position = ' -and $map_node.Groups[1].Value -notmatch '(?m)^position = Vector2\(0, 0\)$') {
	throw "O novo mapa deve ficar centralizado na origem do mundo."
}
if ($world_scene -notmatch '\[node name="WorldWalls" type="StaticBody2D" parent="MapSprite"') {
	throw "WorldWalls deve estar conectado ao MapSprite."
}
if ($world_scene -notmatch 'script = ExtResource\("10_walls"\)') {
	throw "WorldWalls deve carregar o gerador de colisão."
}

$player_node = [regex]::Match(
	$world_scene,
	'(?ms)\[node name="player"[^\]]*\](.*?)(?=\r?\n\[node |\z)'
)
if (-not $player_node.Success -or $player_node.Groups[1].Value -notmatch '(?m)^position = Vector2\(62, -560\)$') {
	throw "O personagem deve nascer no centro do marcador verde."
}

Write-Host "World map static checks passed."
