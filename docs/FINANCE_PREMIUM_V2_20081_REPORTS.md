# KOMBAX RC13 build 20081 · Finanzas Premium 2.0 · Informes

## Qué añade 20081

20081 continúa 20079+20080 de forma aditiva. No modifica el significado de cuotas, pagos, pagos parciales, validaciones ni recibos.

La nueva capa de Informes se activa exclusivamente con `finance_reports_enabled=true` y requiere además Finanzas V2. Con el flag apagado, el dashboard Premium sigue funcionando y la sección Informes muestra el gate sin escribir datos.

### Snapshot histórico

Cada informe se crea primero dentro del gateway autoritativo `app_mutate_v160` mediante `finance.informe.crear`. El backend congela:

- tipo y título;
- filtros exactos de la vista;
- etiquetas de alumno/grupo/disciplina/regla;
- periodo;
- KPI y totales;
- evolución mensual;
- antigüedad de deuda;
- dataset completo hasta 5.000 filas;
- branding del club;
- actor y fecha/hora;
- versión e identificador.

El snapshot es inmutable por trigger. Los cambios posteriores de pagos, tarifas, membresías o branding no cambian el informe histórico ya generado.

### Tipos incluidos

- Tesorería mensual y anual.
- Cobros, pendientes y vencidos.
- Por grupo, disciplina, categoría y método de pago.
- Licencias, competiciones y eventos.
- Estado de cuenta individual.
- Informe de la vista actual con exactamente los filtros activos.

### Versionado

`Versión actualizada` crea un nuevo informe en la misma serie (`v2`, `v3`...) usando los filtros congelados de la versión anterior, pero consultando los datos consolidados actuales. Nunca sobrescribe el snapshot anterior.

### PDF Premium

La Edge Function `finance-report`:

1. exige JWT válido;
2. verifica por RPC que el usuario tiene acceso financiero al informe;
3. genera un PDF A4 desde el snapshot, no desde el DOM;
4. aplica branding del club cuando el logo es recuperable;
5. incluye título, identificador, actor, periodo, KPI, gráfico mensual, filtros, tabla y nota histórica;
6. numera `Página X/Y`;
7. calcula SHA-256;
8. sube el PDF al bucket privado `finance-reports`;
9. asocia archivo + hash mediante RPC exclusiva de `service_role` y registra auditoría.

Si la generación de PDF falla después de crear el snapshot, el informe permanece como `PDF pendiente`. Puede regenerarse sin recrear ni alterar el snapshot.

### Storage privado

`finance-reports` se crea con `public=false` y límite de 20 MB/PDF. El navegador no obtiene política INSERT/UPDATE/DELETE. La lectura está limitada a roles financieros del club y se realiza mediante signed URL de corta duración.

Ruta física conceptual:

`club_id/año/KX-FIN-YYYY-000001.pdf`

### Estado de cuenta individual

Puede generarse desde:

- el wizard de Informes seleccionando alumno;
- un dashboard previamente filtrado por alumno;
- el drawer de un cargo mediante `Estado de cuenta PDF`.

El informe usa el mismo motor de filtros que el dashboard.

## Rollout seguro

1. Aplicar 143 y 144 si todavía no están aplicadas.
2. Aplicar 145.
3. Desplegar la Edge Function `finance-report` con `verify_jwt=true`.
4. Desplegar web 20081.
5. Verificar RC13/V2 con `finance_reports_enabled=false`.
6. Activar `finance_reports_enabled=true` solo en el club piloto.
7. Generar un informe de vista, uno mensual y un estado de cuenta.
8. Verificar que las signed URLs expiran y que otro club no puede leer el archivo.
9. Generar una versión actualizada y confirmar que el PDF anterior permanece intacto.

`finance_recurring_enabled` debe seguir en `false` hasta la fase Shadow/QA 20082.

## Rollback

Desactivar `finance_reports_enabled`. Los informes existentes permanecen históricos y privados; no se borran. El dashboard 20080 y Finanzas RC13 no dependen de que la capa de informes esté activa.
