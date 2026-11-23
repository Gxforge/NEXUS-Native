# NEXUS QA LAB

## Capas

1. Importación Godot 4.4 sin errores/recursos faltantes.
2. Unitarias: estado, grafo, puertas, inventario, energía, IA y serialización.
3. Escena: instanciar cada `.tscn`; sockets, grupos, colisión, cámaras y animación.
4. Streaming: recorrer cada arista; carga async, transferencia, descarga real y fallo.
5. Regresión: archivos, bóveda, armas, W-01, vehículo, cápsula, CCTV y UI.
6. Rendimiento: recorridos repetidos, memoria estabilizada, nodos y CPU/GPU.
7. Gráfica: pantalla virtual/GPU, capturas deterministas y comparación documentada.

## Invariantes

- Un Player, CameraDirector, ZoneManager y cuerpo W-01.
- Exactamente 20 tentáculos y 7 ojos cuando W-01 está instanciado.
- Sin referencias inválidas tras descargar.
- Puertas gemelas sincronizadas.
- Zona anterior ausente del árbol y sin proceso/audio/física.
- Estado de vehículo y bóveda conservado.

## Evidencias

`qa/reports/<fecha>/`: JSON/JUnit, logs, métricas, árbol, PNG y vídeo de recorridos. Headless valida lógica/importación, **no gráficos**.

Propuesta: runner `--headless --script res://qa/run_suite.gd`, runner gráfico separado y `qa_lab.tscn`. Baselines independientes por plataforma.