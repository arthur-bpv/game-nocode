class_name StudyTask
extends Resource

@export var id: StringName
@export var title: String
@export var enabled: bool = true
# Missões físicas opcionais podem ignorar a sequência pedagógica.
@export var always_available: bool = false
@export_file("*.tscn") var mission_scene: String
# Identidade do ponto de montagem visual, independente da identidade da task.
@export var map_slot: StringName

enum Presentation { MAP, TABLET }
@export var presentation: Presentation = Presentation.MAP
