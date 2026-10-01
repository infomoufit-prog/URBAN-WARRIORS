# KOMBAX R114 — Guía CMD local, verificación y despliegue

Release: `2.0.0-rc.13-r114-owner-command-center-performance` · Build 20167

> Ejecutar los comandos desde **CMD de Windows**. No pegar claves privadas ni service-role keys en archivos del proyecto.

## A. Si recibes un ZIP único

```bat
certutil -hashfile KOMBAX_R114_GOLDEN_PILOT.zip SHA256
powershell -NoProfile -Command "Expand-Archive -LiteralPath '.\KOMBAX_R114_GOLDEN_PILOT.zip' -DestinationPath '.\KOMBAX_R114' -Force"
cd /d KOMBAX_R114
```

Compara el hash con el `.sha256` entregado.

## B. Si recibes cuatro partes

Coloca las cuatro partes en la misma carpeta y ejecuta:

```bat
copy /b KOMBAX_R114_GOLDEN_PILOT_PART_00+KOMBAX_R114_GOLDEN_PILOT_PART_01+KOMBAX_R114_GOLDEN_PILOT_PART_02+KOMBAX_R114_GOLDEN_PILOT_PART_03 KOMBAX_R114_GOLDEN_PILOT.zip
certutil -hashfile KOMBAX_R114_GOLDEN_PILOT.zip SHA256
powershell -NoProfile -Command "Expand-Archive -LiteralPath '.\KOMBAX_R114_GOLDEN_PILOT.zip' -DestinationPath '.\KOMBAX_R114' -Force"
cd /d KOMBAX_R114
```

## C. Verificación de runtime

```bat
node --version
npm --version
npm run test:20167:r114
npm run pretest
npm run release:build
npm run android:preflight
```

Resultado esperado del gate principal:

```text
KOMBAX Netlify pilot gate: 56 PASS, 7 P2 conocidos, 0 fallos nuevos.
OK build 619 archivos · web = dist = Android
```

El preflight Android puede mostrar **PENDIENTE Firma local** si el keystore no está configurado en ese PC. Eso es intencionado: las claves no se distribuyen dentro del ZIP.

## D. Abrir KOMBAX en local

```bat
npm run dev
```

Abrir:

```text
http://127.0.0.1:4173
```

Si el puerto 4173 está ocupado:

```bat
set PORT=4174
npm run dev
```

Comprobar manualmente:

1. login y recuperación de sesión;
2. Home;
3. Social y scroll;
4. Descubrir/búsqueda;
5. perfil público;
6. competidores/filtros;
7. Showcase y detalle;
8. Events y detalle;
9. Mi Club;
10. Owner;
11. Owner > alertas;
12. Owner > Analytics: cambiar 30/90/180/365 días;
13. cambiar serie del gráfico;
14. filtrar/ordenar tabla de clubes;
15. descargar CSV;
16. tras desplegar backend R114, generar PDF Owner.

## E. Supabase — antes del deploy web

La configuración web apunta al project ref público `poggsobhtutbuagjiydc`. Confirma que es el proyecto correcto de piloto antes de aplicar nada.

```bat
supabase --version
supabase login
supabase projects list
supabase link --project-ref poggsobhtutbuagjiydc
supabase migration list
supabase db push --dry-run
```

**STOP si el dry-run muestra migraciones inesperadas.** No ejecutar `db push` hasta revisar que el historial remoto y local están alineados.

Si el dry-run es correcto:

```bat
supabase db push
```

Después desplegar las funciones R114:

```bat
supabase functions deploy notification-dispatch --project-ref poggsobhtutbuagjiydc
supabase functions deploy kombax-owner-report-r114 --project-ref poggsobhtutbuagjiydc
supabase functions deploy health --project-ref poggsobhtutbuagjiydc
supabase functions list --project-ref poggsobhtutbuagjiydc
```

Si el CLI necesita bundling remoto por no tener Docker, el CLI actual admite `--use-api` en `functions deploy`.

## F. Validación Supabase R114

Tras aplicar la migración y desplegar funciones:

1. Entrar como Owner con MFA/condiciones ya exigidas por KOMBAX.
2. Abrir Owner Command Center.
3. Confirmar que la pantalla carga métricas sin error 403/404 RPC.
4. Crear una solicitud de verificación de prueba controlada.
5. Confirmar alerta interna Owner.
6. Confirmar push Owner en dispositivo registrado.
7. Ejecutar un agente de prueba dentro del flujo existente; no provocar acciones reales sensibles.
8. Generar un PDF Owner y abrir el signed URL.
9. Confirmar que el PDF contiene KPIs, tendencia y tabla, sin detalle de miembros.

## G. Validación push de miembros y Owner

Probar al menos:

- miembro con app abierta;
- miembro con app en background;
- miembro con app cerrada;
- Owner app abierta;
- Owner background;
- Owner cerrada;
- permiso push denegado;
- token inválido/expirado;
- dos dispositivos del mismo Owner;
- sesión caducada al tocar una notificación.

Criterio: la notificación interna debe permanecer aunque el push no llegue. Una alerta Owner global no debe depender de `club_id`; una notificación tenant-scoped de club sí conserva el filtro de club.

## H. Netlify — preview primero

Verificar que `dist` está actualizado:

```bat
npm run release:build
```

Con Netlify CLI instalado y el sitio correcto enlazado:

```bat
netlify --version
netlify login
netlify status
netlify link
netlify deploy --dir=dist
```

Validar la URL preview completa. Solo después:

```bat
netlify deploy --prod --dir=dist
```

Si el sitio usa Continuous Deployment desde Git, el despliegue de producción puede realizarse por el flujo Git ya configurado en vez del deploy manual.

## I. Verificación después del deploy

Abrir `https://kombax.es` y confirmar:

- build 20167 en Health/diagnóstico;
- login/logout/sesión;
- carga de Home;
- Social/Showcase/Events bajo navegación real;
- Owner Command Center;
- PDF Owner;
- push real de miembro;
- push real Owner;
- Android/PWA;
- ausencia de errores JS en consola;
- ausencia de 4xx/5xx inesperados en Network.

Medir en navegador real:

- FCP;
- LCP;
- INP;
- requests iniciales;
- payload transferido;
- imágenes above-the-fold.

Registrar como `NO VALIDADO` cualquier métrica que no se haya medido realmente.

## J. Rollback

Si aparece una regresión crítica:

1. no seguir desplegando;
2. conservar evidencias/logs;
3. rollback de Netlify a la release anterior;
4. redeploy de funciones R113 si el problema está en Edge Functions;
5. para DB, usar una migración de rollback controlada; no borrar tablas/datos manualmente;
6. volver a baseline R113 congelada cuyo SHA-256 es `63f4ed73777179f8dcefcf84d6c3476e59e0b70eb6f7e1797459b790969ec2a8`.
