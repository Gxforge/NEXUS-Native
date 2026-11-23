# Fase 5A · Texturas procedurales compartidas

## Alcance completado

Se portaron las tres texturas generadas por `src/scene/materials.ts` de la fuente oficial `f4e1e819a9c783374e79dbc99cde4597099aba11`:

- `nexus_skin.png` — 1024×512, repetición fuente 1.5×1.15.
- `nexus_iris.png` — 512×512.
- `nexus_floor.png` — 512×512, repetición fuente 6×6.

El exportador reproduce fórmulas, orden de dibujo, capas, capilares, poros, fibras radiales y juntas del código TypeScript. Se fijaron semillas independientes (`151001`–`151003`) porque la fuente usa `Math.random()` sin semilla y, por tanto, no define un bitmap canónico entre ejecuciones.

## Reproducibilidad y procedencia

- Exportador: `tools/export_procedural_textures.py`.
- Informe: `reports/export-procedural-textures.json`.
- Salidas: `assets/generated/textures/`.
- Dos ejecuciones consecutivas produjeron archivos y reporte idénticos byte a byte.
- El informe registra dimensiones, espacio de color, repetición, semilla y SHA-256.

El rasterizador de exportación es Pillow, no Canvas2D del navegador. Esta diferencia queda registrada explícitamente y requiere comparación gráfica antes de declarar paridad visual final. No se modificó la fuente web.

## Integración prevista

Los PNG son recursos sRGB importables por Godot 4.4. La piel se conectará también como bump en los materiales orgánicos, el iris se incorporará al GLB/escena ocular y el suelo se asignará por zona conservando sus factores de repetición. Materiales transparentes, clearcoat y bump se reconstruirán como recursos Godot para evitar perder parámetros que GLB no representa de forma idéntica.
