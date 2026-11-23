# Fase 10A · Contacts y Survey nativos

Se inició la sustitución funcional de `Contacts.ts` y `Survey.ts`:

- `ContactQuery3D` usa `PhysicsDirectSpaceState3D.intersect_ray`, máscaras, exclusiones, cuerpos y áreas.
- `SurveySystem` proyecta un rayo desde Camera3D, obtiene metadatos del objetivo, evita registros duplicados y emite `target_scanned`.
- `GameState` conserva snapshots profundos de los registros para sobrevivir cambios de zona.

La QA valida rechazo de rayos inválidos, identidad, zona, deduplicación y restauración persistente. Faltan el resaltado visual de barrido y los ContactFX de gas/impacto; por ello esta fase no marca ambos módulos como completamente migrados.
