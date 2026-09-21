# PACKAGING_CERTIFICATION_20101_R40.md

## Criterios de certificación
El ZIP R40 debe cumplir:
- raíz única `KOMBAX_20101_R40_CONTINUITY_SOURCE/`;
- manifiesto SHA-256 de todos los archivos salvo el propio manifiesto;
- extracción limpia sin faltantes, extras ni hashes distintos;
- `testzip` y `unzip -t` sin errores;
- 0 `.env`, JKS/keystore privados, claves privadas o symlinks;
- 0 rutas inválidas Windows;
- test R40/R39 y build ejecutados desde extracción limpia.

## Evidencia previa al ZIP definitivo
- ZIP candidato: 2.049 entradas; raíz única; `testzip=None`; `unzip -t` sin errores.
- Extracción candidata: manifiesto 2.048/2.048, faltantes 0, extras 0, hash diff 0.
- R40 desde extracción candidata: PASS 74/74.
- R39 desde extracción candidata: PASS 30/30.
- Build desde extracción candidata: exit 0; `OK build 189 archivos · web = dist = Android`.

## Árbol definitivo antes de empaquetar
- manifiesto: 2.051 entradas; archivos totales incluyendo manifiesto: 2.052;
- secretos/JKS/.env: 0;
- claves privadas: 0;
- symlinks: 0;
- rutas Windows inválidas: 0;
- longitud máxima de ruta relativa del source: 122 caracteres.

El ZIP definitivo se vuelve a validar de forma independiente después de su generación.
