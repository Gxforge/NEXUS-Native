# Fase 7 · Recursos de interacción y cámara

El lote directo de constructores TypeScript se amplió con siete poses completas del guante, polvo biológico, pantalla de telemetría, display genérico, pantalla de cabina y el conjunto geométrico de primera persona creado por `Touch`. Son 12 GLB adicionales; `touch_rig_assets.glb` reúne 60 mallas de guantes, mangas, protectores e instrumentos.

Las pantallas conservan dimensiones y malla, pero CanvasTexture se elimina del GLB: su pintura y datos vivos siguen pendientes como SubViewport/Control. El polvo conserva sus 170 posiciones fuente en una primitiva POINTS; su actualización y calidad dinámica siguen pendientes. Las poses del guante son geometría fuente, no un rig interpolado.
