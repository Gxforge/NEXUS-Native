# Fase 5B · Núcleo anatómico W-01

## Alcance completado

Se exportó a `assets/generated/w01_core.glb` el núcleo anatómico definido por `Monster.ts` y `Head.ts`:

- cabeza cerrada y pose objetivo abierta;
- encía y garganta con sus poses abiertas;
- 26 dientes con escala, orientación y anclaje fuente;
- collar orgánico;
- hombros izquierdo y derecho, con deformación procedural y transformaciones fuente;
- textura de piel PNG embebida en el GLB.

El GLB contiene 33 nodos, siete mallas fuente reutilizadas, 32 instancias visibles, tres mallas con morph target y una textura embebida. La jerarquía mantiene boca y dientes como descendientes de la cabeza para que acompañen respiración y movimiento.

## Procedencia y reproducibilidad

- Fuente oficial: `f4e1e819a9c783374e79dbc99cde4597099aba11`.
- Archivos fuente: `src/scene/Monster.ts`, `src/scene/Head.ts` y `src/scene/materials.ts`.
- Exportador: `tools/export_w01_core.py`.
- Informe: `reports/export-w01-core.json`.
- SHA-256 GLB: `ff3ea58a51617fb6c45d983efce3994fb1248de05a7ab7a81bc0a76ec151cb8d`.
- Dos exportaciones consecutivas fueron idénticas byte a byte.

## Validación Godot 4.4.1

Godot importó el GLB. `qa/validate_w01_core.gd` verificó:

- 32 MeshInstance3D;
- 26 dientes;
- tres mallas con blend shape;
- carga e instanciación correctas.

Esta fase no declara aún paridad gráfica final. Faltan el sistema de siete ojos, párpados/venas, los 20 tentáculos y ventosas, materiales Godot avanzados, animación/IA, colisión y captura comparativa gráfica.
