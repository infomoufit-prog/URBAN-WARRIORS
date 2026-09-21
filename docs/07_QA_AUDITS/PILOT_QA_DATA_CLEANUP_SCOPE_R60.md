# Datos QA antes del piloto · alcance frontend R60

La auditoría de código no encontró hardcodeados en `web/` los registros QA reportados en capturas (`QA-CLUB-001`, `NORA VEGA`, `COMPETIDORA QA`, `[QA TEST]`, `Vídeo de prueba`).

Por la restricción explícita de esta iteración, **no se toca backend** y no se borran esos registros desde Supabase.

Antes de abrir el piloto, la limpieza debe ejecutarse como una tarea separada y autorizada, con este orden:
1. Identificar cada registro QA y su tenant/propietario real.
2. Confirmar que no corresponde a datos reales del piloto.
3. Exportar/registrar evidencia mínima de qué se va a retirar.
4. Eliminar o despublicar únicamente los registros QA autorizados.
5. Revalidar directorio público, Social, solicitudes y perfiles desde una cuenta piloto.

No se recomienda ocultarlos mediante filtros CSS o nombres especiales: eso solo enmascararía datos reales y crearía una regla de producción innecesaria.
