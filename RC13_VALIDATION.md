# Validación · Urban Warriors RC13 build 20020

> **HISTÓRICO / NO CERTIFICA BUILD 20025.** Consultar `FINAL_RELEASE_AUDIT_RC13_BUILD_20025.md`.

## A. Local / estático

Certificado localmente en la ejecución final de build 20020: 57/57 JS/MJS sin error de sintaxis, `npm test` con 583 comprobaciones `OK`, 29 marcadores `PASS`, contrato 93/93 y build con 51 archivos en paridad exacta.


- [x] `npm test` PASS final.
- [x] `node --check` en todos los JS/MJS PASS.
- [x] `npm run build` PASS.
- [x] `web == dist == android/app/src/main/assets/www`.
- [x] `git diff --check` sin errores.
- [x] sin `requiredOperations=[]`, sin bypass de capability gate.
- [x] `scripts/serve.mjs` usa `127.0.0.1`.
- [x] build/cache/versiones coherentes en 20020.
- [x] Sesiones visibles por semana natural con próxima sesión primero y navegación entre semanas.
- [x] Nomenclatura visible `Comunidad del Club` / `Social Community`.
- [x] PWA maskable + Android adaptive icon incorporados para el logo circular.

## B. Supabase

Base previa certificada durante esta RC:
- [x] 031 Finanzas.
- [x] 032 perfiles deportivos + likes.
- [x] 033 Eventos/Competiciones.

Nuevas (Supabase real):
- [x] preflight/apply/verify/transaccional 034.
- [x] preflight/apply/verify 035.
- [x] preflight/apply/verify 036.

## C. Casos de aceptación

### Notificaciones
- [ ] 20 informativas + 3 accionables → lectura masiva deja exactamente las 3 accionables.
- [x] accionable no admite limpieza masiva y se presenta con `Revisar` en la prueba local.
- [ ] tras revisar, contador se actualiza y navegación llega a la ruta.
- [ ] experiencia usable en APK móvil.

### Perfil público de club
- [x] nombre del club en Comunidad del Club abre ficha en local.
- [x] ficha pública local se carga separada del expediente administrativo; backend/RPC mantiene campos públicos explícitos.
- [ ] edición solo Dirección/Coordinación.
- [ ] búsqueda normalizada devuelve club + miembros visibles.
- [ ] URLs públicas no HTTPS se rechazan; el seed no arrastra URLs administrativas inseguras.

### Edad / social / UGC
- [ ] autorregistro alumno <16 rechazado también en backend.
- [ ] familia/tutor no activa Social Community / Comunidad General.
- [ ] edad social se toma del socio activo verificado por el club y respeta `edad_min_comunidad_general` (nunca inferior a 14).
- [ ] aceptación legal versionada registrada (estructura verificada; falta caso manual dedicado).
- [x] una cuenta de alumno elegible muestra Social Community como servicio opcional y estado `Activada` sin publicar el expediente administrativo.
- [ ] sin aceptación vigente de Normas de Comunidad del Club, `comunidad.publicar` rechaza; tras aceptación explícita permite publicar.
- [ ] retirar esa aceptación bloquea nuevas publicaciones sin cerrar la cuenta administrativa.
- [ ] denuncia de publicación y perfil.
- [ ] bloqueo/desbloqueo.
- [ ] ocultación/resolución por moderador.
- [ ] suspensión/reactivación social con motivo y auditoría.
- [ ] suspendido no se auto-reactiva.

### Regresión RC13
- [ ] Finanzas 031.
- [ ] perfil deportivo + likes 032.
- [ ] Eventos/inscripciones/externos/combates 033.
- [ ] roles y RLS.
- [x] PC y web móvil local: pasada visual preliminar satisfactoria sobre backend real 034–036.
- [ ] APK física build 20020.

## D. Android / distribución

- [ ] Gradle/Android SDK compatible instalado.
- [ ] APK release firmada.
- [ ] AAB release generado.
- [ ] instalación 20020 encima del build anterior sin desinstalar.
- [ ] push y permiso de notificaciones.
- [ ] multimedia/cámara.
- [ ] foreground/background y navegación del sistema.
- [ ] revisión Play Console: público objetivo, UGC, seguridad infantil, privacidad/Data Safety, ficha y cuenta de desarrollador.

## Freeze

Solo marcar freeze cuando A–D estén cerrados. Después: **cero funciones nuevas; solo bug → corrección → regresión**.
