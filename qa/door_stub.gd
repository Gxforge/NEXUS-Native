class_name QaDoorStub
extends Node3D
## Compuerta mínima para las pruebas del recorte: sólo expone `aperture` y
## `apply_aperture`, que es lo que `Visibility` consulta de un `SectorDoor`.

var aperture := 0.0

func apply_aperture(value: float) -> void:
	aperture = clampf(value, 0.0, 1.0)
