# Plan por fases y dependencias

Duraciones orientativas; aprobación entre gates.

| Fase | Trabajo | Estimación | Gate |
|---|---|---:|---|
| 0 | auditoría, hashes, referencias y arquitectura | completada | aprobación documental |
| 1 | esqueleto, estado, ZoneManager y QA Lab | 1–2 sem | zonas sintéticas sin fuga |
| 2 | pipeline procedural→GLB/ArrayMesh, materiales/escala | 2–4 sem | assets patrón comparados |
| 3 | laboratorio y puertas por zona | 4–7 sem | recorrido y descarga real |
| 4 | jugador, cámara, interacción, UI e inventario | 3–5 sem | controles Windows/Android |
| 5 | W-01: cuerpo, 7 ojos, boca, 20 tentáculos | 5–8 sem | anatomía/animación/colisión |
| 6 | IA, atención, barrera, armas y VFX | 3–5 sem | ataque/recuperación |
| 7 | bóveda, archivos, energía, CCTV y bancos | 4–7 sem | interacciones persistentes |
| 8 | Transit, cápsula, carro y física | 4–7 sem | recorrido y física A/B |
| 9 | audio, iluminación y fidelidad | 2–4 sem | capturas/escucha aprobadas |
| 10 | optimización, soak y builds | 3–6 sem | QA y presupuestos |

Orden crítico: probar streaming con escenas sintéticas antes de construir todo; C-04+A-01 como corte vertical; W-01 después del pipeline de geometría; Transit después de física base.