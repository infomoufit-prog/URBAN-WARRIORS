# KOMBAX · BUILD 20.059 · OPEN CHAT + AUTOSYNC

Fecha de validación: 2026-08-20  
Base: KOMBAX 20.058 · Header Activity Split  
Estado: **CANDIDATA DE VALIDACIÓN — NO FREEZE FINAL**

## 1. Alcance de esta intervención

Esta primera intervención de 20.059 moderniza Contacto KOMBAX sin alterar el Contact Gate validado:

- solicitud con motivo y primer mensaje;
- aceptación previa obligatoria antes de habilitar conversación;
- conversación de texto abierta después de aceptar, sin límite artificial de 20 mensajes;
- eliminación del autocierre histórico al alcanzar el mensaje 20;
- historial paginado, cargando recientes primero y anteriores bajo demanda;
- sincronización automática de mensajes nuevos mientras el chat está visible;
- resincronización al recuperar Internet y al volver la aplicación a primer plano;
- envío con Enter y salto de línea con Shift+Enter;
- reutilización de una solicitud/conversación existente para evitar hilos duplicados;
- preservación de bloqueo, control de identidad, mayoría de edad y privacidad existentes.

Esta intervención **no declara WebSocket/Realtime nativo**. El frontend usa autosincronización incremental aproximadamente cada 2,5 segundos mientras el chat está abierto y visible. La evolución a Supabase Realtime/Broadcast privado queda fuera de este primer corte para no introducir una dependencia externa no versionada en PWA/APK durante la fase final.

## 2. Supabase live

Proyecto verificado: `poggsobhtutbuagjiydc`.

Migración aplicada:

- versión de registro: `20260820020420`
- nombre: `kombax_unlimited_chat_20059`
- archivo: `supabase/migrations/104_kombax_unlimited_chat_20059.sql`

Cambios live comprobados:

- `kombax_social_contacto_mensajes.ordinal`: `integer`;
- constraint histórico `ordinal <= 20`: eliminado;
- constraint vigente: `CHECK (ordinal >= 1)`;
- `app_kombax_contactos_v104()`: presente;
- `app_kombax_contact_mensajes_v104(uuid,integer,integer,integer)`: presente;
- `app_kombax_social_network_mutate_v104(text,jsonb,uuid)`: presente;
- ejecución v104 permitida a `authenticated` y cerrada a `anon`;
- Normas KOMBAX Social `1.3.0`: vigentes.

## 3. QA transaccional real

Se utilizó una conversación aceptada existente exclusivamente dentro de transacciones con `ROLLBACK`.

Evidencia obtenida:

- el actor autenticado puede actuar con su identidad Social;
- acceso al hilo validado por el helper existente;
- envío real mediante `app_kombax_social_network_mutate_v104` correcto;
- la mutación devuelve `cerrado: false`;
- inserción de un mensaje con ordinal **21** aceptada sin violar constraints;
- el hilo permaneció en estado `aceptada`;
- tras los rollbacks: **0 mensajes QA persistidos** y **0 mutation requests QA persistidas**.

Una única llamada de QA que intentaba agrupar 25 mutaciones fue bloqueada por los controles del conector antes de llegar a Supabase. La propiedad crítica se verificó de forma separada: mutación real v104 + aceptación estructural del ordinal 21 + estado abierto + rollback.

## 4. Tests y build

Resultado final:

- `npm test`: **PASS**;
- `npm run build`: **PASS**;
- regresión específica `test-kombax-20059-unlimited-chat.mjs`: **PASS**;
- toda la cadena histórica hasta 20.059: **PASS**.

El build terminó sincronizando las tres superficies.

Comprobación SHA-256 independiente:

- `web`: 65 archivos;
- `dist`: 65 archivos;
- `android/app/src/main/assets/www`: 65 archivos;
- faltantes: 0;
- extras: 0;
- diferencias de hash: 0;
- SHA agregado del árbol web: `2c68f91eb010cf93a05f38a85805b21119a5531bf88662d168da17799eb1e7be`.

## 5. Android

`npm run android:preflight`:

- identidad Android `com.urbanwarriors.app`: OK;
- `versionCode 20059`: OK;
- `assets/www`: OK;
- Firebase push: OK;
- firma local: PENDIENTE deliberadamente, porque `android/keystore.properties` no se empaqueta.

Resultado: **4/5**. La firma se resolverá localmente al generar APK/AAB.

## 6. Secret audit

Escaneo del paquete candidato:

- JKS / keystore / P12 / PFX: 0;
- `.env` real: 0;
- `keystore.properties` real: 0;
- bloques de clave privada: 0;
- candidatos a valor `service_role`: 0.

Las referencias textuales a roles de Supabase en SQL/tests no son credenciales.

## 7. Security Advisor

El Security Advisor **NO se declara limpio**.

Persisten los avisos ya clasificados en 20.057/20.058:

- tablas RLS sin policies directas: arquitectura cerrada por defecto y acceso mediante RPC;
- cinco endpoints `anon` SECURITY DEFINER intencionales para funciones públicas concretas;
- múltiples RPC `authenticated` SECURITY DEFINER que constituyen la API cliente diseñada;
- los nuevos RPC v104 son `SECURITY DEFINER`, tienen `search_path` fijado, validan sesión/propiedad/participación en función y no son ejecutables por `anon`;
- sigue pendiente la configuración externa **Leaked Password Protection** de Supabase Auth.

Remediación oficial de la alerta de contraseña filtrada:  
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## 8. Performance Advisor

No se ha introducido una nueva categoría de problema con 20.059.

El Advisor sigue mostrando únicamente los grupos INFO ya conocidos:

- foreign keys sin índice en relaciones principalmente de actor/auditoría;
- índices aún sin uso, esperables con el tráfico actual y con índices añadidos recientemente.

No han reaparecido `auth_rls_initplan`, `multiple_permissive_policies` ni el warning de índice duplicado ya corregidos en 20.057.

Referencia del linter de base de datos de Supabase:  
https://supabase.com/docs/guides/database/database-linter

## 9. Compatibilidad y rollback

Incluidos:

- `supabase/rollbacks/104_kombax_unlimited_chat_20059_rollback.sql`;
- `supabase/verification/104_kombax_unlimited_chat_20059_verification.sql`.

El rollback no reinstala un límite `<=20`, porque hacerlo después de existir conversaciones largas sería destructivo. El retorno `integer -> smallint` se bloquea si ya existe cualquier ordinal superior a 32767.

Los RPC v067 se mantienen para compatibilidad con clientes cargados anteriormente. El runtime 20.059 usa v104 para las operaciones y lecturas del chat.

## 10. Pendientes manuales antes de freeze

Todavía deben validarse manualmente:

- dos cuentas reales conversando simultáneamente en navegador;
- recepción automática sin pulsar actualizar;
- historial anterior con más de una página;
- pérdida y recuperación de conexión;
- PWA;
- APK/Android;
- aceptación/rechazo de Contact Gate;
- bloqueo durante una conversación;
- contador de mensajes no leídos en cabecera.

**Conclusión:** 20.059 · Intervención 1 supera validación automática, build y QA live del backend, pero permanece como candidata hasta completar E2E manual multiusuario y las fases posteriores de 20.059.
