class_name StudyDiscipline
extends Resource

@export var id: StringName
@export var title: String
@export_file("*.tscn") var map_scene: String
@export var topics: Array[StudyTopic] = []

func find_topic(topic_id: StringName) -> StudyTopic:
	for topic in topics:
		if topic.id == topic_id:
			return topic
	return null
