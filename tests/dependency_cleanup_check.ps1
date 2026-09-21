$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$legacy_addon = "orchestra" + "tor"
$visual_extension = ".to" + "rch"

if (Test-Path -LiteralPath (Join-Path $project_root "addons/$legacy_addon")) {
	throw "A dependência visual legada ainda existe em addons/."
}

$visual_resources = Get-ChildItem -LiteralPath $project_root -Recurse -File |
	Where-Object {
		$_.FullName -notmatch '[\\/]\.git[\\/]|[\\/]\.godot[\\/]' -and
		$_.Extension -eq $visual_extension
	}
if ($visual_resources) {
	throw "Ainda existem recursos de scripting visual no projeto: $($visual_resources.FullName -join ', ')"
}

$text_extensions = @(".cfg", ".gd", ".gitignore", ".godot", ".json", ".md", ".ps1", ".sh", ".tres", ".tscn")
$legacy_references = Get-ChildItem -LiteralPath $project_root -Recurse -File |
	Where-Object {
		$_.FullName -notmatch '[\\/]\.git[\\/]|[\\/]\.godot[\\/]' -and
		$text_extensions -contains $_.Extension
	} |
	Select-String -SimpleMatch -Pattern $legacy_addon, $visual_extension
if ($legacy_references) {
	throw "Ainda existem referências à dependência visual legada: $($legacy_references.Path -join ', ')"
}

$player_scene = Get-Content -Raw -LiteralPath (Join-Path $project_root "scenes/player/player.tscn")
$tablet_scene = Get-Content -Raw -LiteralPath (Join-Path $project_root "scenes/tablet/Tablet.tscn")
if ($player_scene -notmatch 'player_controller\.gd') {
	throw "A cena do jogador não usa o controlador GDScript."
}
if ($tablet_scene -notmatch 'tablet_interaction\.gd') {
	throw "A cena do tablet físico não usa o controlador GDScript."
}

Write-Host "Dependency cleanup checks passed."
