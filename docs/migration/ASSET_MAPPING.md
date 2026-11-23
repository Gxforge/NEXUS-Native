# Mapa de modelos y recursos

No existen GLTF/FBX/OBJ en la fuente. Los modelos son código Three.js: deben exportarse de forma determinista o reconstruirse con `ArrayMesh`, `SurfaceTool`, `MultiMesh` y primitivas Godot. Cada salida registrará commit, parámetros, escala, ejes, materiales y captura.

| Original | Destino | Método | Estado |
|---|---|---|---|
| Cuerpo/collar/hombros W-01 | GLB + escena | exportar SphereGeometry deformada, sin alterar topología | Planificado |
| Cabeza/labios/mandíbula | meshes + AnimationTree | exportar poses y apertura | Planificado |
| 7 ojos/córneas/párpados | escena ocular reutilizable | mesh compartida, shader y blend shapes | Planificado |
| 20 tentáculos | spline/skin + escena | portar anclajes, Catmull-Rom, radios, ventosas y longitud | Riesgo alto |
| Dientes/ventosas | MultiMesh | instancing con selección por índice | Planificado |
| Piel/iris/suelo | PNG/KTX2 horneado | fijar semilla y comparar | Requiere horneado |
| Laboratorio | GLB por zona + StaticBody3D | exportar sala; colisión separada | Planificado |
| Letras | FontFile o meshes horneados | verificar tipografía y acentos | Por decidir |
| Bóveda | jerarquía + AnimationPlayer | pivotes exactos y secuencia de 22 s | Planificado |
| Cápsula | GLB + cuerpo animable | puertas, asientos y andenes | Planificado |
| Carro | GLB + física | comparar VehicleBody3D con solver propio | Riesgo alto |
| Operador/manos | meshes + Skeleton3D | poses y capa de cámara | Planificado |
| Larvas/vasos | escenas reutilizables | animación y burbujas locales | Planificado |
| Instrumentos/archivos | familias GLB + escenas | instancing y pivotes funcionales | Planificado |
| Pantallas | SubViewport/Control | portar contenido dinámico | Planificado |
| Polvo/nube/impactos | GPUParticles3D | preservar apariencia y plano de impacto | Planificado |
| Audio procedural | AudioStreamGenerator | osciladores, ruido y filtros | Planificado |
| UI React/CSS | Control + Theme | reconstrucción funcional responsive | Planificado |

Convenciones: Y vertical, 1 unidad = 1 metro y validación explícita del signo Z. Compartidos en `res://assets/shared/`; exclusivos en `res://zones/<id>/`. Nada se marca migrado sin geometría, material, escala, pivote, colisión y captura aprobados.