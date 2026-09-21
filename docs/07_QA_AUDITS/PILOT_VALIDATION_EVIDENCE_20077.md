# KOMBAX 20077 PILOT · VALIDATION EVIDENCE

Date: 2026-08-24

## npm test

Result: PASS

Log SHA-256: 2d6bbe0f8c97297a0cfefa279f29b18f78a4747d046701c47aa54733c662bb34

Tail:
```
KOMBAX 20072 verifier Storage least-privilege: PASS
OK backup completo incluye PostgreSQL
OK backup completo incluye todos los buckets Storage
OK backup completo genera manifiesto de integridad
OK script no incrusta secreto
OK restore DB exige destino aislado y credencial separada
OK restore DB usa pg_restore controlado
OK tooling Storage admite backup total y bloquea restore live
KOMBAX 20072 disaster recovery tooling: PASS
KOMBAX health endpoint contract (>=20072, current 20077): PASS
KOMBAX 20072 auth email templates: PASS
KOMBAX 20073 premium auth email templates: PASS
KOMBAX 20073 email UX polish/build identity: PASS
KOMBAX 20072 platform legal acceptance: PASS
KOMBAX 20074 team email invitations: PASS
KOMBAX 20075 student email invitations: PASS
KOMBAX 20076 banner positioning: PASS
PASS KOMBAX 20077 · data lifecycle & history hardening
```

## npm run build

Result: PASS

Log SHA-256: bade0408015f076732bb45630bcdcc10c0722eeda25d199afeddcf6be434ae2b

Tail:
```
OK backup completo incluye PostgreSQL
OK backup completo incluye todos los buckets Storage
OK backup completo genera manifiesto de integridad
OK script no incrusta secreto
OK restore DB exige destino aislado y credencial separada
OK restore DB usa pg_restore controlado
OK tooling Storage admite backup total y bloquea restore live
KOMBAX 20072 disaster recovery tooling: PASS
KOMBAX health endpoint contract (>=20072, current 20077): PASS
KOMBAX 20072 auth email templates: PASS
KOMBAX 20073 premium auth email templates: PASS
KOMBAX 20073 email UX polish/build identity: PASS
KOMBAX 20072 platform legal acceptance: PASS
KOMBAX 20074 team email invitations: PASS
KOMBAX 20075 student email invitations: PASS
KOMBAX 20076 banner positioning: PASS
PASS KOMBAX 20077 · data lifecycle & history hardening
OK build 73 archivos · web = dist = Android
```

## npm run android:preflight

Result: EXPECTED INCOMPLETE (4/5; local signing secret absent)

Log SHA-256: 8cc7f49a7c224d74530076038d8aaff4279d3a889a4b7177fc4233085aaeafa2

Tail:
```

> urban-warriors-2.0.0-rc13@2.0.0-rc.13 android:preflight
> node scripts/android-release-preflight.mjs


Urban Warriors · preflight Android RC13 build 20077

OK · Identidad Android estable — com.urbanwarriors.app
OK · Versionado de actualización — versionCode 20077
OK · Aplicación web embebida — assets/www presente
OK · Firebase para notificaciones push — configuración presente
PENDIENTE · Firma local — copia android/keystore.properties.example como android/keystore.properties

Resultado: 4/5 comprobaciones preparadas.
No generes la release definitiva hasta resolver los elementos PENDIENTE.
```

## 24/08/2026 · Auth E2E y backup real

### Auth alojado
- Registro QA: HTTP 200 y correo real recibido en Gmail.
- Plantilla de confirmación activa en español: `Confirma tu cuenta de KOMBAX`.
- Recuperación: HTTP 200 y correo real recibido en Gmail: `Restablece tu contraseña de KOMBAX`.
- Usuario confirmó recepción humana de los correos de prueba.
- Pendiente de publicación: los links alojados todavía usan `redirect_to=https://urban01.netlify.app/`; Site URL debe cambiarse a `https://kombax.es` coordinadamente con el deploy.

### Backup producción
- Snapshot: `20077-2026-08-24T13-38-02-170Z`.
- Export HTTP 200.
- Verify HTTP 200.
- 50/50 artefactos verificados.
- 0 fallos SHA-256.
- 26.269.021 bytes.
- Manifest SHA-256: `533110e29d0ccb179510fb467f61cd63d8ecee52dda1af6b09760d9b2b4c2da3`.
- Capability revocada y secreto temporal eliminado de Vault.
- Restore aislado: pendiente.
