# Arquitectura · Urban Warriors 1.2

## Capas

```mermaid
flowchart TD
  U[Usuario] --> W[Web / PWA en Netlify]
  U --> A[APK Android]
  W --> DS[Data Store]
  A --> DS
  DS -->|Demo| L[localStorage]
  DS -->|Producción| S[Supabase Auth + REST/RPC]
  S --> P[PostgreSQL + RLS]
  S --> ST[Storage privado]
  C[Supabase Cron] --> EF[Edge Function payment-reminders]
  EF --> P
  EF --> F[Firebase Cloud Messaging opcional]
  F --> U
```

## Cuenta, persona y alumno

La cuenta autenticada no se confunde con el alumno. Un adulto puede ser tutor, alumno y miembro del equipo a la vez. Los menores quedan vinculados a uno o varios tutores.

## Ciclo de mensualidad

```mermaid
flowchart LR
  Q[Cuota generada] --> A1[Aviso 1]
  A1 --> A2[Aviso 2]
  A2 --> A3[Aviso 3]
  A3 --> A4[Aviso 4]
  A4 --> A5[Aviso 5]
  A5 --> V[Vencida día 15]
  Q --> CP[Usuario comunica pago]
  CP --> PV[Pendiente de validación]
  PV --> OK[Validada / pagada]
  PV --> NO[Rechazada / vuelve a pendiente]
  Q --> PA[Pausa administrativa]
```

Reglas principales:

- Calendario inicial: 1, 4, 8, 11 y 14.
- La combinación cuota, destinatario, número de aviso y canal es única.
- Los hermanos se pueden agrupar en un único mensaje, manteniendo una fila histórica por cuota.
- Un pago comunicado detiene los avisos hasta su revisión.
- Dirección, secretaría y tesorería pueden registrar cobros, pausar, reactivar, validar o rechazar.
- Una pausa con fecha final caduca automáticamente.

## Migraciones

- `001`: núcleo multi-club y RLS.
- `002`: cuentas, accesos, publicaciones, material y notificaciones.
- `003`: estados `pendiente_validacion` y `aplazada`.
- `004`: cinco avisos, justificantes privados, cobros, pausas, historial y RPC.
