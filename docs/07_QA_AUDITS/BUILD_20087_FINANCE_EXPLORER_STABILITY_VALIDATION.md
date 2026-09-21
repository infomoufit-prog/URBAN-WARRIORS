# KOMBAX RC13 build 20.087 — Evidencia de validación

## Resultado general
Candidato de estabilización Finance Premium. No se afirma garantía matemática del 100%; se documentan las pruebas ejecutadas y las incidencias residuales conocidas.

## Auditoría de producción
- Sobrepagos: 0.
- Pagos huérfanos de cuota: 0.
- Pagos huérfanos de alumno: 0.
- Pagos de importe <= 0: 0.
- Pagos validados sobre cuotas anuladas/exentas: 0.
- Dobles pagos exactos/rápidos detectados: 0.
- Cargos negativos: 0.
- Cargos activos a cero: 0.
- Duplicados de ejecución automática: 0.
- Duplicados manuales rápidos existentes: 0.
- Números de recibo duplicados: 0.
- Más de un recibo activo por cuota: 0.
- Recibos huérfanos: 0.
- Recibos con importe incoherente: 0.
- Identificadores de informe duplicados: 0.
- PDFs con metadatos incompletos: 0.
- PDFs registrados pero ausentes de Storage: 0.
- Registros lifecycle huérfanos: 0.

## Incidencias residuales de datos existentes
`app_finance_v2_integrity_v155` devuelve 0 bloqueantes y 3 avisos:
1. una cuota de 55 EUR ya pagada conserva un segundo pago pendiente;
2. ese mismo pago pendiente supera el saldo restante (0 EUR);
3. un snapshot histórico antiguo (`KX-FIN-2026-000001`) quedó sin PDF durante los fallos iniciales.

No se modificaron automáticamente estos registros reales. El pago pendiente debe revisarse/rechazarse por el club y el informe antiguo puede regenerarse o archivarse.

## Pruebas de guards en transacción reversible
- Intentar validar el pago pendiente de 55 EUR sobre cuota ya cubierta: BLOQUEADO con `FINANCE_PAYMENT_ALREADY_COVERED`.
- Crear dos cargos manuales idénticos en menos de 2 minutos: segundo intento BLOQUEADO con `FINANCE_CHARGE_DUPLICATE`.
- Archivar un informe y consultarlo desde scope `archived`: PASS; transacción revertida.
- Explorer de pagos devuelve `can_validate=false`, saldo restante 0 y motivo explícito para la incidencia real.

## Frontend / build
- `npm test`: PASS, incluida regresión 20.087.
- `npm run release:build`: PASS.
- Legal release gate: PASS.
- Build: 79 archivos en web, 79 en dist, 79 en Android; contenidos idénticos.
- Android preflight: identidad OK, versionCode 20087 OK, assets OK, Firebase OK, firma local PENDIENTE por ausencia deliberada de `android/keystore.properties`.

## Seguridad del artefacto
Escaneo del candidato:
- JKS/keystore: 0.
- `.env`: 0.
- PEM/P12/PFX: 0.
- claves privadas detectadas: 0.
- prefijos secretos incrustados fuera de documentación/tests: 0.

## Backend
- Migraciones 155–158 aplicadas en producción.
- Runtime contract incluye `finance.documento.estado`.
- `health` Edge Function: v12 ACTIVE, build 20087.
- Recurrencia real y gates de piloto: no activados.
