# KOMBAX · Storage orphan cleanup · build 20072

## Regla
Un objeto de Storage no se elimina solo porque no aparezca en una primera consulta de referencias. Debe pasar por:
1. Inventario completo de referencias conocidas.
2. Clasificación del bucket y propietario.
3. Comprobación de que no está referenciado por tablas históricas, URLs persistidas o recursos legales/auditoría.
4. Periodo de gracia mínimo definido por operación (recomendado para piloto: 30 días salvo datos que deban eliminarse antes por solicitud válida).
5. Reporte previo con bucket, path hash, fecha, tamaño y motivo; no incluir contenido.
6. Eliminación por service_role solo tras aprobación operativa.

## Estado detectado 23/08/2026
La auditoría encontró candidatos no enlazados en algunos buckets de pruebas/históricos. No se ha borrado ninguno automáticamente. `kombax-verification-docs` no presentó candidatos huérfanos en el barrido ampliado.

## Excepción: eliminación de cuenta
El ejecutor de privacidad utiliza el plan de objetos asociado al usuario y elimina esos objetos como parte de una solicitud confirmada; no depende de la limpieza genérica de huérfanos.
