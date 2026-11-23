# Exportación masiva de assets

`python3 tools/export_all_assets.py` reconstruye en una sola operación todos los assets ya implementados, actualiza el inventario y genera `reports/export-all-assets.json` con hashes, tamaños y cobertura por archivo fuente.

El lote actual produce cinco GLB y tres PNG. La cobertura real es 5 de 28 archivos inventariados; 23 permanecen pendientes y están enumerados explícitamente en el informe. Esta cifra evita confundir automatización masiva con migración terminada.

Dos ejecuciones completas consecutivas se verificaron byte a byte. Los nuevos exportadores se incorporarán a este comando por familias, sin comandos manuales aislados ni afirmaciones de cobertura que no estén respaldadas por el informe.
