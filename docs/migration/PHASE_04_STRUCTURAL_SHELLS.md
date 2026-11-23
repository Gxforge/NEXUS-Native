# Fase 4A · Estructuras reales C-04 y A-01

## Alcance

Se sustituyeron los suelos sintéticos por un primer shell estructural derivado de `Environment.ts` y `Sectors.ts` del commit `f4e1e81`. Incluye volúmenes principales y colisión; todavía no incluye campo de contención, mobiliario, luminarias completas, turbinas, archivos ni texturas finales.

## Sistema de coordenadas

Ambas zonas usan origen común en el portal A/01 mundial `(-9, 0, -14)`. Conversión: `local = (world.x + 9, world.y, world.z + 14)`. Unidad: metro.

## A-01

Siete cajas fuente: suelo, techo, muro oeste, partición este `x=0`, muro de fondo `z=-38` y dos segmentos del mamparo frontal. Exportado como un mesh con dos superficies/materiales y siete BoxShape3D.

- GLB: `assets/generated/a01_structural_shell.glb`
- SHA-256: `ffa686f12c393f237716491e31ef29b4673cc80a73f89b1ce78444c69c1c2dc0`
- AABB: `36.475 × 9.47 × 24.55 m`

## C-04

Diez cajas fuente: suelo, techo, muros laterales, tres segmentos del mamparo `z=-14`, dos segmentos del muro Transit y cabecera L01. Exportado como un mesh con dos superficies y diez BoxShape3D.

- GLB: `assets/generated/c04_structural_shell.glb`
- SHA-256: `a2ed2e75957b9c07e285f35d80a31b9a41f69eae0c10baa8534bd54e2a792d47`
- AABB: `72.6 × 9.47 × 84.55 m`

## Implementación

- `StructuralShell` genera colisiones desde el mismo manifest que produjo el GLB, evitando divergencia visual/física.
- `zone_c04_shell.tscn` y `zone_a01_shell.tscn` son ahora las escenas del catálogo.
- El entorno visual global permanece persistente en Main; no se duplican WorldEnvironment durante transiciones.
- Los portales permanecen deshabilitados durante staging y se activan después de transferir al Player, evitando cruces accidentales al instanciar.
- ZoneManager eliminó esperas internas basadas en corutinas y usa señales one-shot para `zone_ready` y `tree_exited`.

## QA y evidencia

46/46 comprobaciones: conteo de colisiones, mesh único por shell, AABB, streaming, sensores, puerta y liberación del origen.

Capturas gráficas Vulkan Forward Mobile/Xvfb, 1280×720:

- `reports/c04-structural-slice.png`
- `reports/a01-structural-slice.png`

Las imágenes muestran correctamente los volúmenes estructurales y el portal. No se consideran paridad final: faltan detalles, materiales/texturas e iluminación original.

## Incidencia abierta

El runner gráfico aislado informa un `RefCounted` restante al cerrar inmediatamente la escena de captura. La suite de ciclo de vida confirma que la zona anterior se libera y no retiene su WeakRef, pero el aviso del harness gráfico debe investigarse antes del gate de ausencia total de fugas.
