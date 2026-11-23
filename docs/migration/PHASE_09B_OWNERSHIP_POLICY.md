# Fase 9B · Política ejecutable de propiedad

`ZoneOwnershipPolicy` convierte la auditoría en reglas reutilizables por exportadores y escenas Godot:

- una sola intersección → contenido local de esa zona;
- varias intersecciones → `zone_connection`;
- ninguna intersección → `shared_infrastructure`;
- raíces funcionales conocidas reciben controladores específicos.

Asignaciones especiales: Transit → `transit_controller`, ZoneGates → conexión, Facility → infraestructura compartida, Operations → `operations_controller`, Vault → `vault_controller`.

`qa/validate_zone_ownership.gd` valida contenido A-01/C-04, portal multizona, corredor compartido y raíces funcionales. Esta política evita duplicar recursos fronterizos al generar escenas modulares.
