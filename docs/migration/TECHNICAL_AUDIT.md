# Informe técnico de auditoría

## Resumen

NEXUS 15.1 es casi enteramente procedural. La dificultad no es copiar modelos, sino convertir generación, animación y estado Three.js/React en assets y subsistemas Godot verificables. El destino está vacío salvo configuración Mobile e icono.

## Persistencia

Persistir partida, Player único, inventario, progreso, energía, misiones, Transit y `WatcherState`. Descargar representaciones locales. Las diez cámaras se conservan como definiciones; solo se renderizan las necesarias. W-01 mantiene estado global con un solo cuerpo instanciado.

## Reconstrucción W-01

1. Capturar parámetros, meshes y referencias de `f4e1e81`.
2. Exportar cuerpo/collar/hombros sin cambiar topología.
3. Portar cabeza y dos arcadas; validar sutura en apertura 0, 0.45 y 1.
4. Escena ocular compartida: 7 posiciones, párpados, iris, pupila, córnea, venas y `flash()`.
5. Portar 20 anclajes, Catmull-Rom, radios, ventosas, objetivos y longitud fija.
6. Colisión: broad phase corporal, narrow phase y cápsulas/segmentos; comparación A/B.
7. Portar estados IDLE/WATCHING/CURIOUS/AGGRESSIVE/ATTACK/RECOVERY, visión, oído, memoria, señuelo, frío y agarre.
8. Optimizar solo después con MultiMesh, buffers y visibilidad.

## Física/animación

Player en CharacterBody3D; colisiones sincronizadas de puertas/gavetas. W-01 controlado y confinado por reglas originales. Prototipo VehicleBody3D frente a solver propio para cuatro contactos, suspensión, turbo, regeneración y daño. Puertas/bóveda mediante AnimationPlayer con estado serializable. NavigationRegion por zona, enlazada solo con ambas activas y puerta abierta.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Sin modelos fuente | exportador determinista + capturas/medidas |
| Texturas aleatorias | semilla fija, horneado y hash |
| Tentáculos dinámicos | corte vertical de uno, luego 20; longitud/coste |
| Cannon ≠ Godot | escenarios numéricos A/B; solver propio si hace falta |
| Referencias entre zonas | datos/IDs y auditor previo a unload |
| CCTV en Android | escalonar por visibilidad sin eliminar cámaras |
| Materiales físicos | tabla de equivalencia y captura controlada |
| Picos de carga | threaded loader, sensores y telemetría |
| UI React compleja | inventario de estados y Control responsive |
| Caché `.godot` en ZIP | no versionarla; regenerar con 4.4 |
| Patch Godot no fijado | elegir 4.4.x exacto antes de importar |

## Aprobaciones necesarias

Autorizar fase 1 de implementación (esqueleto/ZoneManager/QA sintético), elegir Godot 4.4.x exacto, aprobar exportador procedural, fijar dispositivos Android/FPS/memoria y decidir perfil Windows Mobile o Forward+.