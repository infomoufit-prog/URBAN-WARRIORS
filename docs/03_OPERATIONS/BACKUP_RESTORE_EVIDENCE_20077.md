# KOMBAX RC13 build 20077 · Backup / Restore Evidence

Fecha: 24/08/2026

## Backup real de producción — PASS

Se ha ejecutado un backup lógico real contra el proyecto Supabase de producción `poggsobhtutbuagjiydc` mediante las Edge Functions `backup-export-20077` y `backup-verify-20077`.

Control de seguridad aplicado:
- capability efímera almacenada temporalmente en Supabase Vault;
- el token se transportó exclusivamente por la cabecera `x-kombax-backup-token`, nunca en query string;
- tabla de capabilities con RLS y sin acceso `anon`/`authenticated`;
- capability revocada al finalizar;
- secreto temporal eliminado de Vault al finalizar.

Snapshot validado:
- snapshot: `20077-2026-08-24T13-38-02-170Z`;
- DB: 3 artefactos NDJSON;
- Storage: 47 objetos;
- artefactos esperados: 50;
- artefactos verificados: 50;
- fallos SHA-256: 0;
- tamaño total: 26.269.021 bytes;
- SHA-256 manifest: `533110e29d0ccb179510fb467f61cd63d8ecee52dda1af6b09760d9b2b4c2da3`;
- resultado HTTP export: 200;
- resultado HTTP verify: 200.

Existe además un snapshot previo verificado `20077-2026-08-24T13-13-41-102Z`, con 0 fallos.

## Restore aislado — PENDIENTE

Los scripts de restore y controles de aislamiento existen, pero el drill real NO se considera certificado hasta restaurar contra una base/proyecto independiente de producción y validar conteos, integridad y acceso mínimo.

No se realizará un restore sobre producción ni se considerará equivalente crear un schema temporal dentro de la misma base.
