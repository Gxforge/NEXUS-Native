# Fase 10B · Sustitución de ZoneCache

El streaming nativo ya no solicita PackedScene con el modo de caché por defecto. `ZoneManager` usa `ResourceLoader.CACHE_MODE_IGNORE` tanto para precarga como para transición, conserva únicamente WeakRef de diagnóstico y libera la instancia anterior tras `tree_exited`.

La suite acumulada añade comprobaciones de que:

- la instancia anterior desaparece;
- el manager no conserva una referencia fuerte;
- el PackedScene de la zona descargada no permanece en el ResourceLoader cache;
- jugador y sistemas persistentes no se duplican.

Resultado acumulado: 48/48. Esto sustituye el calentamiento gráfico de `ZoneCache.ts` para C-04↔A-01. Falta aplicar el mismo catálogo y escenas modulares a las demás zonas.
