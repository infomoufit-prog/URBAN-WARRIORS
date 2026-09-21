# KOMBAX R75 · Showcase Multiclub Context Separation

**Build:** 20126  
**Base:** R74 / build 20125  
**Release tag:** `r75-showcase-multiclub-context`  
**Fecha de cierre:** 2026-09-16  
**Estado:** candidata de congelación de piloto, no desplegada

## 1. Incidencia corregida

R74 acopló dos experiencias que deben ser independientes:

- **Mi Showcase**: espacio privado de gestión del Showcase correspondiente al club activo.
- **Explorar Showcase**: catálogo público global de KOMBAX Showcase.

El estado privado `manage` podía permanecer activo y contaminar la siguiente entrada a `Explorar Showcase`. Además, el render público consultaba indirectamente los espacios privados. Si la RPC privada fallaba, el error se ocultaba con un `catch(()=>[])`, dando una falsa impresión de que el Showcase del club no existía.

## 2. Causa raíz backend

`app_kombax_showcase_mis_espacios_v048(p_club_id)` mezclaba dos contextos: al abrir el Showcase de un club también intentaba autoprovisionar perfiles directos del usuario (Marca/Federación/Competidor). Una validación histórica de Showcase todavía asumía un proveedor de tipo Marca y podía lanzar `SHOWCASE_BRAND_PROFILE_REQUIRED`.

Urban Warriors ya tenía un Showcase válido; el problema no era ausencia de datos sino una resolución incorrecta de contexto.

## 3. Solución R75

### Navegación

- `Explorar Showcase` fuerza siempre la ruta pública de catálogo.
- El catálogo público no llama a `myBrands()` ni depende de espacios privados.
- `Mi Showcase` usa una ruta privada dedicada.
- Volver/cerrar desde gestión privada retorna de forma explícita al catálogo público.
- Se elimina el acoplamiento basado en `sessionStorage.kombax_showcase_view`.

### Multiclub

- El espacio privado se resuelve por **`club_id` activo**.
- Un usuario multiclub obtiene el Showcase del club actualmente seleccionado, sin mezclar Showcases de otros clubes.
- La creación/vinculación del proveedor de club sigue siendo idempotente.
- Los perfiles directos Marca/Federación/Competidor se resuelven en su propio contexto, no durante la apertura de un club.
- No se duplican proveedores, productos, permisos, identidades ni información Stripe.

### Supabase

Nueva migración local:

`supabase/migrations/264_kombax_showcase_multiclub_context_r75.sql`

Cambios principales:

1. `app_kombax_showcase_mis_espacios_v048(uuid)` separa el contexto de club del contexto de perfiles directos.
2. Con `p_club_id` devuelve exclusivamente el Showcase gestionable de ese club.
3. Sin `p_club_id` mantiene el contexto separado de Marca/Federación/Competidor.
4. Se retira del validador histórico la suposición obsoleta de que todo proveedor directo es una Marca.
5. La RPC privada mantiene `SECURITY DEFINER`, `search_path` cerrado, sin ejecución `anon`, y solo `authenticated` puede invocarla.

## 4. Verificación live de Urban Warriors

Se probó la RPC con el mismo perfil gestor de Dirección de Urban Warriors:

- Club: Urban Warriors.
- Plan activo: Premium.
- Proveedor Showcase: **1**.
- Proveedores duplicados de club: **0**.
- Estado del proveedor: `publicada`.
- Productos publicados: **5**.
- Capacidad visible: **25**.
- La llamada con `club_id` devuelve solo Urban Warriors.
- La llamada de contexto directo devuelve separadamente las identidades directas gestionables.

La prueba de lectura se realizó dentro de transacción con rollback; no creó datos de prueba.

## 5. QA

- R75 Showcase context separation: **PASS 10/10**.
- R74 cumulative gate: **PASS 47/47**.
- R36: **PASS 49/49**.
- R73: **PASS 7/7**.
- R72 release: **PASS 22/22**.
- Commercial: **PASS 18/18**.
- Identity: **PASS 15/15**.
- Showcase Seller Center: **PASS 13/13**.
- Events Center: **PASS 15/15**.
- Sidebar/navigation: **PASS 9/9**.
- Reputation/catalog: **PASS 14/14**.
- `npm test`: **PASS**.
- i18n runtime: **PASS 4687/4687**, 0 no resueltos.
- English quality: **PASS 2180/2180**.
- Locales activos: ES, EN, FR, PT, IT, DE, TH, FIL.
- JS syntax checks: **PASS**.
- Secret/keystore scan del paquete: **PASS, 0 hallazgos**.

## 6. Build y Android

- Runtime web: build **20126**.
- Android `versionCode`: **20126**.
- Android `versionName`: `2.0.0-rc.13-r75-showcase-multiclub-context`.
- Paridad de frontend: **450 archivos · web = dist = Android**.
- Android preflight: **4/5**. El único pendiente es la firma release local porque `android/keystore.properties` no se distribuye ni debe formar parte del ZIP.

## 7. Estado de cierre

| Área | Estado | Resultado |
|---|---|---|
| Explorar Showcase público | PASS | Independiente del contexto privado |
| Mi Showcase | PASS | Resuelve el club activo |
| Multiclub | PASS | Aislamiento por `club_id` |
| Urban Warriors | PASS | Provider existente recuperado correctamente |
| No duplicación | PASS | 0 proveedores de club duplicados |
| Supabase migration | PASS | Aplicada y verificada |
| QA acumulativa | PASS | Regresión completa verde |
| Web/Android parity | PASS | 450 archivos sincronizados |
| Firma Android release | BLOCKED externo | Requiere keystore local; no es defecto de código |
| Smoke autenticado en dispositivo real | EXTERNAL | Requiere sesión/dispositivo del piloto |
| GitHub / Netlify / Play | NOT DEPLOYED | No autorizado/solicitado en este cierre |

## 8. Nota de seguridad fuera de alcance

El advisor global de Supabase sigue mostrando deuda histórica de seguridad en el proyecto, incluida la protección contra contraseñas filtradas desactivada y un gran número de avisos sobre RPC/RLS previos. R75 no amplía esa superficie: la RPC privada modificada no es ejecutable por `anon` y el trigger validador no es ejecutable desde API. No se ha realizado una refactorización global de seguridad dentro de esta corrección funcional.

Referencia de Supabase para la protección de contraseñas filtradas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## 9. Base válida siguiente

Tras verificar el ZIP final y su SHA-256, **R75/build 20126 sustituye a R74 como única base acumulativa válida para el siguiente trabajo**.
