# KOMBAX R103 · Créditos IA, cierre técnico y QA

## Auditoría anterior al cambio

La base acumulativa R102 ya contenía un monedero R97 por `tenant_ref`, grants mensuales y de piloto, reservas por turno, Assist y Migrations en la misma función Edge, un límite de 12 turnos para pilotos y contadores históricos. SISO no existe como agente separado. Había 24 turnos históricos, pero ningún monedero ni entidad piloto inscrita cuando se inició esta fase.

Faltaban precisión inferior al crédito, `usage` oficial completo, tarifa central para caché y herramientas, analítica de costes por entidad y agente, indicador compacto en ambos agentes, resumen de consumo por trabajo de migración y acceso a créditos fuera del piloto. Los contadores antiguos podían bloquear Assist/Migrations aunque hubiera saldo; los turnos normales no siempre tenían límite de 12. El frontend seguía mostrando los cupos antiguos y refrescaba el saldo solo en piloto.

## Implementación acumulativa

- Migraciones SQL `275` a `286`: conservan las tablas R97 y convierten sus importes a tres decimales, con un único saldo por entidad. La conversión central `ai_usage_to_credits_r103` toma `usage` oficial, tarifas por modelo, caché, herramientas, FX y margen configurables. Los detalles de tokens y costes permanecen en `kombax_ai_ops` sin permiso de lectura para clientes.
- Assist y Migrations comparten reserva y liquidación. Se bloquea la fila del monedero para evitar doble gasto concurrente. La liquidación toma el coste real de la ejecución, libera sobrantes y registra el déficit si el consumo excede el saldo. Los fallos liberan la reserva.
- La función `kombax-assist-r38` v14 publicada en Supabase exige `usage` y `response.id`; registra un `run` por turno antes de completarlo. Reintentos con el mismo identificador devuelven el resultado existente y no vuelven a cobrar. El contador histórico sigue internamente como `old_usage_count`.
- 500/1.000/2.000 créditos mensuales para Basic/Premium/Enterprise; 2.000/2.000/4.000 en piloto y primer mes pagado; prueba segura de 150 créditos. El piloto está fechado del 1 de octubre al 15 de noviembre de 2026. El grant de onboarding exige una suscripción pagada con referencia confirmada.
- Los headers de Assist y Migrations muestran un control compacto de Créditos IA con saldo, plan, renovación, explicación y aviso por consumo. Migrations muestra por caso los archivos, pendientes, revisión, créditos usados y la reserva máxima del siguiente análisis. La interfaz consolida el saldo cada cinco interacciones; el backend liquida cada una.
- El panel Owner añade coste, créditos, ahorro estimado por caché, media por entidad, fallos, comparativa por plan, desglose por entidad y modelo, alerta de déficit y comparación del contador anterior. La pantalla del cliente no incluye tokens, moneda ni tarifas.
- Para fichas de imagen se permite un lote de hasta ocho archivos (32 MB por lote); 80 imágenes ordinarias requieren diez lotes, dentro de doce turnos si no hubo otras consultas en ese caso.

## Configuración y calibración

La equivalencia inicial es 400 créditos por euro de presupuesto interno, con margen 1,20. El coste GPT-6 Luna se guarda por modelo en base de datos y se puede cambiar sin tocar el frontend. El cambio USD/EUR usa como referencia inicial el tipo del BCE del 25 de septiembre de 2026 (1 EUR = 1,1403 USD); debe recalibrarse con la factura y el piloto. Las medias de 80/160/320 interacciones son hipótesis internas, no promesas comerciales.

## QA ejecutado

- Las migraciones `275` a `286` se aplicaron a `poggsobhtutbuagjiydc`; la Edge Function quedó ACTIVE v14 con JWT obligatorio.
- Consulta real de la función central: llamada corta de 1.000 tokens de entrada/100 de salida = 0,063 créditos con el FX configurado; llamada extensa de 30.000/8.000 = 2,947 créditos. La precisión se conserva a milésimas. Se confirmó la tarifa del modelo y que no hay monederos piloto aún.
- Una prueba transaccional con cinco turnos reales ya archivados verificó una reserva de 10 y liquidación de 7,440 créditos por turno, el saldo acumulado de 37,200 créditos y la idempotencia de un reintento. Otra prueba comprobó que un trabajo Migrations fallido libera toda su reserva. Ambas transacciones se revirtieron: siguen habiendo cero monederos, grants y reservas de prueba en producción.
- Se comprobó que `authenticated` no puede leer la tabla privada de `usage` ni ejecutar la función central de conversión. El RPC Owner concede `EXECUTE` pero su propia comprobación de administrador impide el acceso a una sesión sin ese rol.
- Tres módulos frontend pasaron `node --check`; `scripts/build.mjs` produjo 615 archivos idénticos en `web`, `dist` y Android.
- La prueba R102 de insignias pasó. Dos pruebas estáticas antiguas de R60 fallan porque esperan textos/rutas históricas de cupos que se han sustituido y porque ya no reflejan la navegación actual; no sirven como certificación R103.
- Se abrió `http://127.0.0.1:4173/` y se verificó la navegación de inicio. La sesión disponible mostró una cuenta con club y federación. Los botones de gestión de esa sesión no abrieron el área de agentes en la prueba visual; por tanto no se certifica interacción real de popover ni la APK instalada.

## Límites operativos para el piloto

- El lote de imágenes cubre 80 fichas de una fila con tamaño total razonable; no se ha certificado un caso real de 80 imágenes ni una hoja Excel de 80 filas. La extracción por documento conserva el límite previo de cinco filas; una hoja mayor requiere partición o una ampliación posterior. No debe anunciarse importación completa de grandes hojas sin esa verificación.
- No hay entidad piloto inscrita ni nueva ejecución OpenAI real en esta fase. La exactitud del cargo de punta a punta se verificará con la primera llamada autenticada y `usage` devuelto, comparando OpenAI y el ledger.
- Las tarifas, el FX y los presupuestos son configurables. El precio real de herramientas ajenas al token se cargará en `ai_tool_cost_rates_r103` cuando se activen y conozcan sus tarifas.
- Una reserva puede quedar corta ante un uso excepcional; el exceso se carga del saldo disponible y se registra `shortfall` para alerta interna. No se ejecuta ningún nuevo turno si la reserva inicial no cabe en el saldo.
- El límite de doce turnos afecta a la conversación, no al monedero. El siguiente caso puede usar los créditos restantes.
