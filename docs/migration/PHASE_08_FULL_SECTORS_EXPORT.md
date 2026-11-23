# Fase 8 · Exportación integral de sectores

`laboratory_all_sectors.glb` ejecuta el constructor original `Sectors`, que compone Transit, ZoneGates, Files, Operations, BenchCycle, Vault, Facility y Power. La salida contiene 2.361 mallas y 74.010.152 bytes.

El recurso conserva la composición geométrica y jerárquica fuente, pero no sustituye las escenas de zona Godot: debe fraccionarse por límites reales, añadir colisiones y conectar sistemas nativos antes de usarse en runtime. Las pantallas Canvas y estados dinámicos permanecen explícitamente pendientes.

Dos ejecuciones fueron idénticas byte a byte y Godot 4.4.1 importó e instanció el GLB.
