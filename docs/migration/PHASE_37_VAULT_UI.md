# Fase 37 · Puerta de la bóveda, pantalla de carga y arte del menú

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **375 checks, 0 fallos** · `validate_vault_door` **24 checks**
**Punto de partida:** `bda4e35` (fase 36)

Los tres encargos de esta fase venían de la misma sesión de prueba: el jugador
abría la bóveda y no pasaba nada, la pantalla de carga se quedaba en
«Precargando geometría y recursos · 0 %» y el juego se anunciaba con un fondo
prestado del HUD.

## 1. Puerta de la bóveda con los modelos reales

`vault.glb` ya estaba en el proyecto (fase 15 para la lógica, fase 30 para el
atrezzo), pero la puerta sólo existía como ocho pestillos procedurales de
`BuildKit`. Ahora el grupo `Node2` del lote original se monta en la galería V–03
y `VaultDoorRig` lo anima con la secuencia de `Vault.ts`.

### 1.1 Localización (`scripts/world/vault_door_rig.gd`)

El `.glb` no trae nombres útiles: `Node2` contiene 252 nodos hijos con nombres
repetidos. `attach()` identifica cada pieza **por geometría**, con el mismo
criterio que se usó para la familia de luminarias en la fase 32:

| Pieza | Criterio | Encontradas |
|---|---|---|
| Disco | hijo directo con caja > 4,5 m en X y > 20 mallas | 1 (5,96 m) |
| Corona | hijo del disco, caja 2,5–3,8 m centrada (`|x|,|y| < 0,4`) | 1 |
| Cerrojos | 4 mallas, alto 1,0–1,7 m | 8 |
| Pistones | 7 mallas, alto 1,7–2,2 m | 4 |
| Brazos | 1 malla con `center.x < −2` | varios |

`qa/validate_vault_door.gd` (24 checks) comprueba que se encuentran las cinco
familias, que el reparto es 1 + 1 + 8 + 4 y que cada pieza vuelve a su sitio
tras `reset()`.

### 1.2 Secuencia (idéntica a `Vault.ts`)

`sync(seconds)` es una función pura del tiempo de la bóveda, sin estado
acumulado, igual que en la web:

| Tiempo | Movimiento |
|---|---|
| −1 (reset) | todo sellado: disco a `z = 0,08`, cerrojos y pistones a 0 |
| 0,8 + i·0,71 → 3,1 + i·0,71 | pistón `i` sube `1,56 m` |
| 4,3 + i·0,58 → 5,9 + i·0,58 | cerrojo `i` sube `0,96 m` |
| 8,8 → 13,9 | corona `rotation.z −2,3·π` (2,3 vueltas) |
| 13,6 → 16,2 | disco `z += 1,32 m` (despega del marco) |
| 16,3 → 22,0 | disco `x −= 6,25 m` (se aparta a la izquierda) |
| ≥ 22,0 | `opened = true` |

Las rampas son `smoothstep`, como en `Vault.ts`; `VaultModule.update()` llama a
`door.sync(timer)` en cada frame con el temporizador de la secuencia de 22 s, así
que la apertura disparada por el jugador (consola o panel) mueve la geometría
real sin código adicional.

### 1.3 Dónde está montada

En la fase 30 la puerta se puso como atrezzo en el muro sur de **B–02
Turbinas**, mientras la lógica de la bóveda vive en **V–03 Galería**: se abría
una bóveda que no era la que el jugador tenía delante. Ahora se monta al fondo
del eje de la galería, en `(28,0, 2,6, −78,6)`, con radio 1,8 m, y esconde el
portal a la crioteca (en la captura abierta se ve el umbral al otro lado).

El centro va desplazado a **+x** a propósito: los brazos hidráulicos del modelo
salen 4,8 m hacia −x y con la puerta centrada atravesaban el muro oeste del
módulo (el validador de atrezzo lo detectaba como «mobiliario dentro de las
paredes»). El rótulo de la galería se movió de `z = −76` a `z = −44` porque
cruzaba el encuadre de la puerta.

`game_state.vault` no siempre existe cuando se construye el atrezzo, así que el
enganche va por el nodo hermano: `zone_dressing.gd::_vault_door` hace
`get_parent().get_node_or_null("VaultModule").attach_door(rig)`, con el camino
de `game_state` como respaldo.

## 2. Pantalla de carga

El síntoma era doble: la barra no se movía y el panel no decía nada del juego.

### 2.1 Progreso (`scripts/ui/loading_progress.gd`)

`ResourceLoader.load_threaded_get_status` devuelve `IN_PROGRESS` durante toda la
precarga y sólo cambia al final, así que una barra atada a ese valor se queda en
0 %. `LoadingProgress.value()` combina tres fuentes:

```
precarga:  max(informe · 70,  8 + (1 − e^(−1,6·t)) · 52)   acotado a 0…68
montaje:   70 + peso(estado) · 30
```

El suelo exponencial sube solo con el reloj (8 % al arrancar, 28 % a los 0,3 s,
52 % a los 3 s) y se queda justo por debajo del techo de 68 % para no mentir
mientras el hilo sigue trabajando. Con el módulo ya cargado, los estados de
`ZoneManager` reparten el último 30 %: `VALIDANDO` 0,05 · `INSTALANDO` 0,25 ·
`CARGANDO` 0,45 · `ACTIVANDO` 0,68 · `TRANSFIRIENDO` 0,84 · `LIBERANDO` 0,96 ·
`IDLE` 1,0 (100 %).

### 2.2 Datos reales

`details()` compone una línea con lo que hay de verdad en ese instante: módulo
destino, nombre del `.tscn`, tamaño en KB leído del disco, número de
dependencias contadas en el archivo, segundos transcurridos, informe del
cargador y estado del `ZoneManager`. Ejemplo medido:

```
V03_GALLERY · zone_v03_gallery.tscn · 4 KB · 8 dependencias · 0,1 s · informe 50 % · estado IDLE
```

El título del panel ya no es fijo: `main.gd::_zone_label()` lo toma de
`data/zone_graph.json` (`C-04 · Contención`, `V-03 · Galería axial`…) y también
se usa en el botón del menú («CONTINUAR EN C-04 · CONTENCIÓN»). Antes decía
siempre «C-04 · CONTENCIÓN» aunque la zona fuese otra.

## 3. Arte del menú y de la carga

`assets/ui/menu_background.png` es una ilustración propia (16:9, sala de
contención con la esfera de siete ojos dentro del hexágono cian, la mitad
izquierda despejada para el título). Se usa en dos sitios con velo distinto:

- `UI/MainMenu/Art` · `stretch_mode = 6` (cover), `expand_mode = 1`, velo
  `Background` a alfa 0,45 para que el título NEXUS y los botones sigan legibles.
- `UI/LoadingScreen/Art` · mismo ajuste, velo a 0,62, con el panel de progreso
  semitransparente encima.

## 4. Pruebas y capturas

- `qa/validate_vault_door.gd`: 24 checks (familias del `.glb`, reparto, sellado y
  apertura completa).
- `run_suite`: bloque nuevo `_validate_loading_progress()` con 9 checks (barra
  que se mueve sin informe, techo del suelo, 100 % al montar, orden de los pesos,
  nombre del paso, línea de datos con módulo/dependencias, tamaño y recuento
  leídos del disco). Total **375 checks, 0 fallos**.
- `qa/capture_ui.tscn` toma cuatro imágenes: `reports/ui-main-menu.png`,
  `reports/ui-loading.png`, `reports/vault-opening.png` (t = 14,6 s, disco
  despegado) y `reports/vault-open.png` (t = 21,5 s, disco apartado y umbral
  abierto). El jugador se coloca a partir de la posición real de la puerta
  (`Rig` localizado por meta `vault_rig`), no con coordenadas a mano.

## 5. Pendiente que arrastra la fase

- Las larvas de H–01 siguen sin burbujas ni latido (`Larva.ts`).
- La puerta no tiene sonido de motor ni de sellado (`Vault.ts` usa `AudioContext`
  para el zumbido de la secuencia).
