# Fase 10A · Contacts y Survey nativos

Se inició la sustitución funcional de `Contacts.ts` y `Survey.ts`:

- `ContactQuery3D` usa `PhysicsDirectSpaceState3D.intersect_ray`, máscaras, exclusiones, cuerpos y áreas.
- `SurveySystem` proyecta un rayo desde Camera3D, obtiene metadatos del objetivo, evita registros duplicados y emite `target_scanned`.
- `GameState` conserva snapshots profundos de los registros para sobrevivir cambios de zona.

`SurveyHighlight` añade un material overlay aditivo con banda de barrido y retícula, avanza durante un tiempo configurable y restaura exactamente el material overlay anterior al finalizar. `SurveySystem` puede conectarlo al objetivo físico detectado.

La QA valida rechazo de rayos inválidos, identidad, zona, deduplicación, restauración persistente, aplicación temporal del resaltado y restauración del material. Faltan los ContactFX de gas/impacto y la integración final con controles/UI; por ello esta fase no marca ambos módulos como completamente migrados.
