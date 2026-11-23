# Fase 10D · Descomposición inicial de SceneExperience

`SceneExperienceController` se añadió una sola vez bajo `PersistentWorld`. Coordina, sin convertirse en un nuevo monolito:

- Camera3D persistente;
- SurveySystem y SurveyHighlight;
- ContactQuery3D;
- ContactFx3D;
- persistencia de registros en GameState.

Expone acciones explícitas para escanear un punto de viewport y emitir impacto/gas desde un resultado físico. Los subsistemas siguen siendo scripts pequeños y reutilizables. La escena principal garantiza un único controlador que sobrevive cambios de zona; no se instancia dentro de escenas modulares.

La suite acumulada valida controlador único, propiedad de Survey/ContactFX y recorrido C-04↔A-01: 51/51.
