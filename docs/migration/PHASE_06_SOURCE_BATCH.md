# Fase 6 · Exportación masiva directa desde constructores TypeScript

Se añadió un exportador que ejecuta los constructores originales Three.js del commit fuente y entrega GLB binarios para taller/cápsulas, bóveda, tránsito, tres variantes de larva, tres instrumentos y vehículo. La aleatoriedad se fija con semilla antes de construir las escenas.

## Resultado

- 10 GLB.
- 95.552.772 bytes.
- 1.127 instancias MeshInstance3D importadas en Godot.
- Taller: 195; bóveda: 284; tránsito: 498; larvas: 29/31/33; instrumentos: 7 cada uno; vehículo: 36.
- Dos lotes consecutivos idénticos byte a byte.
- Los diez GLB cargan e instancian en Godot 4.4.1.

Los CanvasTexture dinámicos se eliminan durante esta exportación geométrica porque deben reconstruirse como materiales y SubViewport nativos. El informe `export-source-batch.json` registra esta limitación; no se declara migrada la funcionalidad de pantallas, animación, física ni interacción.
