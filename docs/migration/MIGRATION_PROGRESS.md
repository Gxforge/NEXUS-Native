# Progreso

## Auditoría y fundación
- [x] Fuente `f4e1e81` de solo lectura; arquitectura y QA.
- [x] Godot 4.4.1, Player único, catálogo, estado y ZoneManager.
- [x] Carga threaded, sockets, transferencia y descarga.

## Pipeline/portal A-01
- [x] Exportador GLB determinista.
- [x] Marco y hojas A/01, colisiones, pivotes y sensor original.
- [x] Capturas gráficas cerrada/abierta.

## Estructura real C-04/A-01
- [x] Sistema común de coordenadas desde portal mundial `(-9,0,-14)`.
- [x] Shell A-01: 7 volúmenes, 1 mesh, 7 colisiones.
- [x] Shell C-04: 10 volúmenes, 1 mesh, 10 colisiones.
- [x] Escenas estructurales sustituyen a las zonas sintéticas en el catálogo.
- [x] WorldEnvironment global sin duplicación.
- [x] Portal deshabilitado durante staging; sin cruce accidental.
- [x] QA acumulada 46/46 y capturas 1280×720.
- [ ] Resolver aviso RefCounted del harness gráfico al salir.
- [ ] Campo C-04, iluminación completa, texturas, archivos y mobiliario.
- [ ] Comparación A/B con Three.js.

## Inventario y texturas procedurales
- [x] Inventario reproducible de 28 archivos con geometría, materiales o texturas.
- [x] Piel, iris y suelo exportados a PNG con semillas y hashes registrados.
- [x] Verificación byte a byte de dos exportaciones consecutivas.
- [x] Integrar piel en el GLB del núcleo orgánico W-01.
- [x] Exportar cabeza, encía, garganta, 26 dientes, collar y hombros con tres morph targets.
- [ ] Integrar iris y exportar los siete ojos, párpados y venas.
- [ ] Exportar los 20 tentáculos, ventosas y familias de geometría restantes.
- [ ] Comparación gráfica contra Canvas2D/Three.js antes de declarar paridad final.

## No iniciado
- [ ] W-01 nativo y resto de zonas.
- [ ] UI, IA, audio/VFX completos.
- [ ] Builds Windows/Android y push.
