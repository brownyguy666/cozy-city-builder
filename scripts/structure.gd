extends Resource
class_name Structure

@export_subgroup("Display")
@export var display_name: String = "" # UI Display Name
@export var category: String = "Bangunan" # Category: Jalan, Bangunan, Taman & Alam, Kendaraan
@export var icon: Texture2D # 2D UI Icon

@export_subgroup("Model")
@export var model: PackedScene # Model of the structure

@export_subgroup("Gameplay")
@export var price: int = 100 # Price of the structure when building

func get_title() -> String:
	if not display_name.is_empty():
		return display_name
	if not resource_name.is_empty():
		return resource_name
	if resource_path:
		return resource_path.get_file().get_basename().capitalize().replace("-", " ")
	return "Struktur"

