# Plan de rendimiento

## Presupuestos iniciales (por validar)

| Métrica | Windows | Android |
|---|---:|---:|
| Zonas completas activas | 1–2 | 1–2 |
| CPU frame | <8 ms a 60 FPS | <16 ms a 30/60 FPS según dispositivo |
| Draw calls típicas | <700 | <250 |
| Sombras simultáneas | perfilar | 1 principal + excepciones justificadas |

No son resultados ni garantías.

## Acciones

- Mobile ya configurado; comparar Forward+ para Windows.
- Combinar estructuras estáticas por zona/material y usar MultiMesh para repetidos.
- Colisiones simples separadas; físicas y NavigationRegion solo en zonas activas.
- Hornear texturas procedurales con semilla y compresión de plataforma.
- LOD/visibility ranges solo tras captura A/B; no reducir arbitrariamente los 20 tentáculos.
- Tentáculos visuales solo cuando W-01 esté instanciado; estado lógico fuera de zona.
- Diez CCTV conservadas; SubViewports actualizados por visibilidad/escalonamiento.
- Pool para impactos/nube; GPUParticles con presupuesto medido, sin eliminarlas.
- Audio local detenido y liberado con zona.
- Medir RAM/VRAM, nodos, objetos, draw calls, primitivas, CPU/GPU y picos de transición.

Android: probar dispositivos reales, Vulkan Mobile, shaders, texturas, SubViewports, luces, safe areas y densidades. El perfil no cambiará contenido ni reglas.