class_name StudyTask
extends Resource

@export var id: StringName
@export var title: String
@export var enabled: bool = true
@export_file("*.tscn") var mission_scene: String
# Identidade do ponto de montagem visual, independente da identidade da task.
@export var map_slot: StringName

enum Presentation { MAP, TABLET }
@export var presentation: Presentation = Presentation.MAP
