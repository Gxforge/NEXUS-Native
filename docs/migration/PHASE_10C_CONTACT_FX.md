# Fase 10C · ContactFX nativo

`ContactFx3D` sustituye la base de sprites de `ContactFX` por un emisor GPUParticles3D reutilizable con dos perfiles:

- impacto: 24 partículas, impulso corto, gravedad y color cálido;
- gas: 48 partículas, expansión lenta, flotación y transparencia.

Ambos perfiles aceptan posición y normal física, reinician un emisor one-shot y comparten material/proceso para evitar crear nodos en cada impacto. La QA estructural valida cantidades, tiempos, ubicación y recursos. Falta comparación gráfica y conexión con armas/interacciones de SceneExperience.
