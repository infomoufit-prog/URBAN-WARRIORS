# KOMBAX RC13 build 20064 · MASTER ADMIN + FRONTEND CLEANUP

## 1. Objetivo de la intervención

La build 20064 parte exclusivamente de la 20063 `SOCIAL_MESSAGING_FINAL_QA` y tiene dos objetivos de cierre de producto:

1. separar completamente la administración global KOMBAX de la experiencia ordinaria de cualquier club; y
2. impedir que errores, nombres de contratos, mensajes de base de datos u otros tecnicismos internos aparezcan en el frontend de usuarios.

La intervención también corrige la distribución de la barra inferior móvil de cuatro accesos.

## 2. Reglas de release

- Fuente de verdad de código: build 20063.
- Nueva candidata: build 20064.
- `applicationId`: `com.urbanwarriors.app` sin cambios.
- `versionName`: `2.0.0-rc.13` sin cambios.
- `versionCode`: 20064.
- Netlify: **NO desplegar 20064 durante esta intervención**. La 20062 continúa como referencia web publicada.
- Supabase live: **NO aplicar migración 108 al cerrar el paquete**. Se entrega preparada, con preflight, verificación y rollback.
- Firma Android: reutilizar exactamente el JKS histórico. Nunca crear un keystore nuevo para esta release.

## 3. Arquitectura de acceso maestro

### 3.1 Separación de identidades

La autorización de plataforma es independiente del rol de un club. Una misma cuenta puede tener un rol dentro de Urban Warriors u otro club y, de forma separada, estar autorizada en `kombax_platform_admins`.

La UI normal del club no muestra:

- Administración KOMBAX;
- Diagnóstico;
- Certificación E2E;
- Herramientas técnicas;
- nivel `owner`;
- enlaces a la consola global.

### 3.2 Entrada móvil oculta

En la pantalla del directorio que se abre desde `Entrar con mi club`, el símbolo KOMBAX de la cabecera actúa como puerta de acceso oculta.

Regla implementada:

- 8 pulsaciones sobre el símbolo;
- las 8 deben producirse dentro de una ventana de 5 segundos;
- si se supera el intervalo, el contador se reinicia;
- no hay texto, badge, tooltip ni pista visible;
- el gesto no concede ninguna autorización: únicamente abre el formulario maestro.

### 3.3 Entrada PWA / navegador

La aplicación detecta la ruta privada `/admin` antes de iniciar el flujo ordinario de club.

Netlify ya dispone de fallback SPA `/* -> /index.html`, por lo que la ruta funcionará cuando se despliegue una build que contenga 20064.

No se añade ningún enlace público hacia `/admin`.

## 4. Autenticación maestra

### 4.1 Flujo

1. abrir la puerta oculta móvil o `/admin`;
2. introducir correo de administrador global y contraseña;
3. autenticar con contraseña en Supabase Auth;
4. backend crea un `challenge` administrativo de 5 minutos únicamente si el usuario está en `kombax_platform_admins` y la autenticación por contraseña es reciente;
5. solicitar OTP de correo con `create_user=false`;
6. introducir el código recibido;
7. Supabase verifica el OTP y emite la sesión autenticada correspondiente;
8. backend consume el `challenge` y crea una sesión maestra de 30 minutos ligada al `session_id` del JWT actual;
9. solo entonces `app_kombax_es_platform_admin_v055()` devuelve `true`;
10. la Consola KOMBAX se abre fuera del shell del club.

### 4.2 Límites de seguridad

- challenge: 5 minutos;
- limitación de creación de challenge: 30 segundos entre solicitudes activas;
- challenge de un solo uso;
- sesión maestra backend: 30 minutos;
- cierre por inactividad frontend: 15 minutos;
- cierre manual invalida la sesión maestra y la sesión Auth;
- el usuario debe ser platform admin activo;
- un login normal del mismo owner no habilita la consola;
- no existe código maestro estático dentro de JS, APK o PWA.

## 5. Migración Supabase 108

Archivo canónico:

`supabase/migrations/108_kombax_master_admin_otp_20064.sql`

Incluye:

- `kombax_platform_admin_challenges`;
- `kombax_platform_admin_sessions`;
- RLS activado en ambas tablas;
- revocación de acceso directo a `public`, `anon` y `authenticated`;
- helper de AMR reciente basado en JWT;
- RPC de inicio de challenge;
- RPC de confirmación de challenge;
- RPC de cierre de sesión maestra;
- endurecimiento de `app_kombax_es_platform_admin_v055()`;
- contexto de administración con expiración.

Los endpoints de challenge son `SECURITY DEFINER` intencionados y se limitan a usuarios autenticados. Validan identidad, pertenencia a `kombax_platform_admins`, método AMR reciente y challenge consumible. Tras activarlos deben revisarse los Security Advisors de Supabase.

## 6. Preparación de Email OTP en Supabase

Antes de validar E2E:

1. Authentication -> Email Templates -> Magic Link.
2. Cambiar el contenido para incluir `{{ .Token }}` y enviar un código de seis dígitos en lugar de un Magic Link.
3. Authentication -> Providers -> Email -> Email OTP Expiration: objetivo 300 segundos.
4. Confirmar rate limits de OTP.
5. Para producción, configurar SMTP propio; el envío integrado de Supabase no debe considerarse el canal definitivo de producción.

En el código actual de KOMBAX, el nuevo flujo de administración es el único consumidor de `/auth/v1/otp`, por lo que esta configuración no sustituye el flujo existente de recuperación de contraseña.

## 7. Consola de Plataforma

La consola global se presenta con shell propio y dos pestañas principales:

### Plataforma

Reutiliza los contratos globales ya existentes para:

- dashboard de plataforma;
- todos los clubes;
- creación controlada de clubes;
- apertura de un club y su equipo;
- permisos públicos de equipo;
- perfiles e identidades KOMBAX;
- búsqueda global de perfiles;
- solicitudes de verificación;
- documentación privada de verificación;
- moderación e incidencias;
- asignación de moderadores;
- servicios de perfiles verificados;
- auditoría reciente;
- estado técnico del contrato global.

### Mantenimiento

Visible solo después del acceso maestro:

- build de frontend;
- estado de autorización global;
- nivel administrativo;
- caducidad de sesión admin;
- contrato de plataforma;
- últimas trazas técnicas de la sesión.

Los tecnicismos se concentran aquí y dejan de formar parte del frontend ordinario.

## 8. Auditoría transversal de mensajes técnicos

### Riesgo detectado

El helper anterior podía concatenar `message`, `details` y `hint` del backend y devolverlos sin filtrar. Esto permitía que errores de RLS, PostgREST, SQL, constraints, nombres de RPC o tablas llegasen al usuario.

### Solución implementada

`web/js/core/utils.js` incorpora:

- `technicalError(error)` para preservar el detalle interno;
- `humanError(error)` como única representación segura para usuario;
- detección de RLS, RPC, PGRST, SQLSTATE, PostgreSQL, Supabase, schema, constraints, claves, UUID/JSON, nombres `app_*`, códigos `KOMBAX_*`, URLs internas y códigos SQL;
- mensajes humanos para sesión caducada, red, límites de frecuencia, credenciales, OTP, autorización y contenido inexistente;
- fallback genérico seguro.

Se sustituyeron renderizados directos de `e.message`/`error.message` en módulos ordinarios por `humanError` o `setError` sanitizado.

### Limpieza de copy

- `No recibe insignia KOMBAX en 20.044` retirado del perfil Profesional.
- etiquetas internas `CLUB ACCESS / 01`, `KOMBAX ID / CUENTA` y `KOMBAX ID / 02` retiradas del gateway.
- administración global y herramientas técnicas retiradas del menú/configuración del club.

## 9. Barra inferior móvil

La navegación móvil actual muestra cuatro accesos. El grid mantenía cinco columnas, generando el desequilibrio visual observado.

Corrección:

- número de columnas calculado con `--bottom-nav-count` según los botones realmente renderizados;
- en la configuración actual de cuatro accesos, cada uno ocupa el 25 %;
- alineación y área táctil centradas;
- texto multilínea controlado;
- safe-area Android preservada.

## 10. Pruebas automáticas

Se añade `scripts/test-kombax-20064-master-admin-cleanup.mjs`, integrada en `npm test`.

Valida:

- build 20064 web/Android;
- bottom nav de cuatro columnas;
- ausencia de admin global en navegación normal;
- ausencia de herramientas técnicas en configuración del club;
- existencia de `/admin`;
- gesto de 8 taps/5 s;
- retirada de labels internos;
- flujo OTP frontend;
- contratos 108;
- RLS/grants estáticos;
- sanitizador central;
- ausencia de render directo de errores backend en módulos públicos.

Las pruebas históricas RC5, RC9, 20028 y 20063 se actualizaron únicamente donde su expectativa antigua contradecía deliberadamente el nuevo requisito de seguridad/separación.

## 11. Matriz QA obligatoria antes de freeze

### Acceso maestro

- [ ] 7 taps no hacen nada.
- [ ] 8 taps dentro de 5 s abren Acceso Maestro.
- [ ] 8 taps lentos no abren Acceso Maestro.
- [ ] ninguna pista de administración es visible.
- [ ] `/admin` abre el acceso maestro en PWA desplegada 20064.
- [ ] una cuenta no owner es rechazada.
- [ ] contraseña incorrecta es rechazada con mensaje humano.
- [ ] contraseña correcta solicita OTP.
- [ ] OTP incorrecto no abre consola.
- [ ] OTP caducado no abre consola.
- [ ] reenvío genera un nuevo código.
- [ ] challenge usado no se puede reutilizar.
- [ ] consola expira al caducar la sesión backend.
- [ ] inactividad 15 min cierra la administración.
- [ ] cierre manual invalida el acceso.
- [ ] login normal del owner no muestra administración en Urban Warriors.

### Frontend técnico

- [ ] provocar error de red: solo mensaje humano.
- [ ] provocar error RLS controlado: no aparece `RLS`.
- [ ] provocar RPC inexistente en entorno QA: no aparece nombre de función.
- [ ] comprobar Profesional/Representante: sin referencias a builds.
- [ ] recorrer gateway, Social, Showcase, finanzas, eventos, documentos y configuración sin textos internos.

### Barra móvil

- [ ] cuatro accesos ocupan ancho equilibrado.
- [ ] Showcase en dos líneas no desplaza iconos.
- [ ] safe area no tapa navegación.
- [ ] Pixel/Android en vertical y apaisado.

## 12. Secuencia de activación posterior

No ejecutar hasta iniciar QA móvil de 20064:

1. congelar copia de Supabase previa;
2. si 107 sigue pendiente, aplicar 107 y verificar Social/Showcase;
3. configurar Email OTP y SMTP/plantilla;
4. ejecutar `preflight_108_kombax_master_admin_otp_20064.sql`;
5. aplicar migración 108;
6. ejecutar `verify_108_kombax_master_admin_otp_20064.sql`;
7. revisar Security Advisor y Performance Advisor;
8. generar APK release signed 20064 con JKS histórico;
9. validar matriz móvil con cuenta owner y cuenta no owner;
10. mantener Netlify en 20062 hasta aprobación;
11. tras freeze: desplegar 20064 -> PWA -> AAB signed -> Google Play.

## 13. Rollback

Si la activación 108 falla:

`supabase/rollbacks/108_kombax_master_admin_otp_20064_rollback.sql`

El rollback restaura el helper 055 previo y retira endpoints/tablas 108. Después debe ejecutarse verificación funcional y revisar el esquema de PostgREST.

## 14. Criterio de cierre

La 20064 solo se considerará congelable cuando:

- build/tests estén verdes;
- paridad web/dist/Android sea total;
- firma APK use el JKS existente;
- OTP llegue por correo real;
- owner acceda después de password + OTP;
- no-owner no pueda iniciar challenge;
- el shell normal no revele privilegios globales;
- no haya mensajes técnicos visibles en rutas de usuario;
- no haya regresiones en Social/Showcase 20063.
