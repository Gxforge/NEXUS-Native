# Fase 11A · W-01 visible en C-04

Se creó `w01_actor.tscn` combinando núcleo, siete ojos y veinte tentáculos. C-04 instancia el actor en `(0, 0, 22)` con colisión corporal. El script nativo añade respiración, morph de boca, seguimiento ocular limitado y oscilación base de los veinte brazos.

El jugador ahora dispone de mouse-look capturado, límite vertical y movimiento relativo a su orientación. Escape libera el cursor y un clic lo recupera.

## QA

- Actor, colisión y morph cargan.
- Siete ojos y veinte tentáculos presentes.
- Integración en C-04 comprobada.
- Suite acumulada: 55/55.
- Captura gráfica Forward Mobile 1280×720: `reports/w01-c04-first-look.png`.
- SHA-256: `4be1ba667c41c7876a6d360010cd1e58bc5873bf77f5d52357a63b6e40117f5c`.

La captura demuestra visibilidad gráfica, no paridad final: la iluminación/materiales son todavía demasiado oscuros y faltan IA, locomoción, parpadeo, venas, ataques y animación procedural completa.
