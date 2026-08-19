# KOMBAX RC13 · build 20046 · Security Hardening & Production Audit

Fecha de cierre técnico: 2026-08-19 (Europe/Madrid)
Base congelada: build 20045 PUBLIC PROFILES + AUDIENCES
Proyecto Supabase auditado: `poggsobhtutbuagjiydc`

## Objetivo

Endurecer la superficie de seguridad de KOMBAX sin alterar las reglas funcionales certificadas. La estrategia fue conservadora: inspección previa, migraciones pequeñas, verificación inmediata y conservación de compatibilidad con el cliente 20045 durante la transición cuando era necesario.

Esta auditoría no declara "riesgo cero". Declara el estado y las evidencias verificadas al cierre del build 20046.

## Hallazgos de prioridad alta corregidos

1. **RPC Social supersedidas capaces de saltarse las audiencias 083.**
   - Corregido por 084 y 088.
   - Feeds, mutaciones, comentarios, perfiles y proyecciones antiguas dejan de ser ejecutables directamente por clientes.

2. **Multimedia de publicaciones restringidas almacenada en bucket público.**
   - Corregido por 085 + 091.
   - Bucket privado `kombax-restricted-media`.
   - La lectura de objetos privados exige que el mismo usuario pueda ver la publicación por el guard de audiencia 083.
   - Una publicación pública exige media pública; una restringida exige media privada.
   - Avatares, álbumes públicos y Showcase permanecen públicos por diseño.
   - Las implementaciones preservadas `*_pre_media_v085` quedaron internalizadas explícitamente en 091.

3. **Validación pública de códigos cortos sin limitación de intentos.**
   - Corregido por 086.
   - Usuarios autenticados: 5 fallos / bloqueo 15 min por cuenta-club-tipo.
   - Compatibilidad anónima temporal 20045: 10 fallos / bloqueo 15 min por huella IP+navegador.
   - Comparador raw de código no es ejecutable por cliente.
   - Smoke real ejecutado dentro de transacción y revertido: 9 intentos permitidos, 10º bloquea y el siguiente continúa bloqueado.
   - Los códigos actuales de 5 dígitos se mantienen para no romper clientes/QR 20045. La ampliación de longitud debe hacerse después de retirar la compatibilidad 20045.

4. **Privilegios anónimos directos heredados y policies RLS con comparaciones tautológicas.**
   - Corregido por 087.
   - Se crea un catálogo público mínimo de alta (`app_kombax_registro_catalogo_publico_v087`).
   - DML anónimo directo se cierra.
   - Solo se conservan temporalmente SELECT de transición en cinco catálogos de alta para compatibilidad 20045: clubes, disciplinas, grupos, tarifas y textos legales.
   - `club_ambitos_trabajo`: se corrige `ae.club_id = ae.club_id`.
   - `registros_acceso_clase`: se corrige `s.club_id = s.club_id` y el INSERT queda explícitamente para `authenticated`.
   - Revisión final: 0 tautologías RLS detectadas.

5. **Superficie RPC innecesaria de triggers, helpers y versiones supersedidas.**
   - Corregido por 088, 089 y 092.
   - 0 funciones `trigger` ejecutables por anon/authenticated.
   - Helpers no usados directamente por 20045/20046 ni por policies quedan internalizados.
   - `service_role` se conserva donde lo requieren operaciones/Edge Functions.

6. **Objetos futuros expuestos por privilegios por defecto.**
   - Corregido por 089 + 090.
   - Nuevas tablas, secuencias y funciones en `public` quedan deny-by-default para roles cliente/service hasta que una migración conceda permisos explícitos.
   - ACL final por defecto: únicamente `postgres`.

## Migraciones de hardening 20046

- 084 · `kombax_social_legacy_rpc_shutdown_20046`
- 085 · `kombax_restricted_social_media_confidentiality_20046`
- 086 · `kombax_access_code_rate_limit_20046`
- 087 · `kombax_api_surface_hardening_20046`
- 088 · `kombax_superseded_rpc_shutdown_20046`
- 089 · `kombax_internal_rpc_default_privileges_20046`
- 090 · `kombax_default_privileges_complete_20046`
- 091 · `kombax_media_preserved_impl_shutdown_20046`
- 092 · `kombax_internal_helper_shutdown_20046`

Cada una tiene migración local, verificación SQL y rollback correspondiente.

## Contrato de seguridad verificado en Supabase real

Al cierre se verificó:

- Administrador global `owner` sigue activo.
- Relaciones: sin SELECT directo para anon/authenticated.
- Documentación de verificación: tabla privada y bucket privado.
- `kombax-restricted-media`: bucket privado.
- 0 tautologías RLS detectadas.
- 0 funciones SECURITY DEFINER sin `search_path` fijado.
- 0 funciones trigger ejecutables por roles cliente.
- Feed/mutación Social antiguos cerrados.
- Feed/mutación 085 activos para authenticated.
- Implementaciones preservadas pre-085 cerradas a clientes.
- Comparador raw de códigos cerrado a clientes.
- Tablas de rate-limit privadas.
- Generación recurrente cerrada al cliente y conservada para `service_role`.
- Privilegios futuros por defecto: solo `postgres`.

## Aislamiento multiclub

Se cruzaron las RPC actuales que aceptan `club_id` con sus controles de identidad, membresía, rol o delegación a helpers de permisos. No se encontró una RPC actual de negocio que acceda a datos sensibles de un club sin control de tenant.

El diagnóstico multiclub histórico, ejecutado únicamente desde contexto administrativo después de retirar su ejecución cliente, confirma para los recursos auditados:

- `club_id` presente;
- RLS activo;
- índice de tenant presente;
- DML directo de cliente deshabilitado.

## Endpoints anónimos SECURITY DEFINER restantes y clasificación

Se mantienen únicamente porque forman parte del contrato público o de transición:

- `app_buscar_clubes_kombax_v040`: descubrimiento público de clubes.
- `app_kombax_registro_catalogo_publico_v087`: catálogo mínimo de alta.
- `app_kombax_showcase_categorias_v042`: categorías públicas del escaparate.
- `app_kombax_showcase_list_v054`: elementos públicos del escaparate.
- `app_kombax_codigo_validar_v060`: compatibilidad temporal con cliente 20045; ya protegido con rate-limit. Debe retirarse como endpoint anónimo cuando 20046 sea el cliente mínimo soportado.

La revisión de sus retornos no mostró exposición de Relaciones, documentación privada, alumnos, finanzas ni administración.

## Avisos RLS sin policy directa

Las tablas señaladas por Supabase como `RLS enabled / no policy` fueron comprobadas: no conceden acceso directo a `anon` ni `authenticated`. Funcionan como deny-all deliberado dentro de una arquitectura RPC-first. No se añadieron policies artificiales para silenciar el linter.

## Ajuste manual pendiente antes de producción

**Supabase Auth · Leaked Password Protection** continúa desactivado. El conector disponible en esta sesión no expone una operación segura para modificar esa configuración de Auth, por lo que debe activarse desde el panel de Supabase antes de la certificación definitiva de producción y volver a probar alta, login, recuperación de contraseña y sesión.

## Performance Advisor

Se revisó también el Advisor de rendimiento. Detecta deuda histórica (FK sin índice, `auth_rls_initplan`, múltiples policies permisivas, índices sin uso y un índice duplicado). No se modificó en este build porque una campaña masiva de índices/RLS no corrige una vulnerabilidad y mezclarla con el hardening aumentaría el riesgo de regresión.

Se recomienda una fase separada de **Performance Hardening** después de certificar funcionalmente 20046.

## Pruebas locales

- `scripts/test-kombax-20046-security.mjs`: PASS.
- Suite completa `npm test` desde arquitectura histórica hasta 20046: PASS antes del empaquetado final.
- El build final debe volver a ejecutar `npm test` mediante `npm run build` y comprobar `web = dist = Android`.

## Restricciones deliberadas de transición

- Cinco SELECT anónimos de catálogos antiguos se conservan temporalmente para no romper un cliente 20045 aún abierto. El runtime 20046 ya usa `app_kombax_registro_catalogo_publico_v087`.
- `app_kombax_codigo_validar_v060` conserva acceso anónimo temporal, pero ya no es ilimitado.
- La retirada total de estas compatibilidades deberá hacerse únicamente cuando 20046 sea la versión mínima desplegada en PWA/Android.

## Conclusión de auditoría

No se identificó al cierre una vía conocida de prioridad crítica/alta sin corregir dentro del alcance auditado. Los avisos restantes se clasifican como endpoints públicos intencionados, arquitectura RPC-first deny-all, deuda de rendimiento o el ajuste manual de Leaked Password Protection indicado arriba.

## Resultado final de build y Android

- `npm run build`: PASS.
- Builder: 62 archivos, `web = dist = Android`.
- Verificación SHA-256 independiente de árboles:
  - web: `2955682bc1096f32503b87316c9a79bf7299a13061aace68be1634f425c81383`
  - dist: `2955682bc1096f32503b87316c9a79bf7299a13061aace68be1634f425c81383`
  - Android assets: `2955682bc1096f32503b87316c9a79bf7299a13061aace68be1634f425c81383`
- Diferencias web↔dist: 0.
- Diferencias web↔Android: 0.
- Android preflight: 4/5.
  - applicationId estable: OK.
  - versionCode 20046: OK.
  - assets Android: OK.
  - Firebase: OK.
  - firma local: PENDIENTE deliberadamente; no se empaquetan JKS ni contraseñas de firma en el ZIP.
- Escaneo de nombres sensibles: no se encontró JKS, keystore real, `.env`, PEM, P12 ni clave privada. Solo existe `android/keystore.properties.example` con placeholders para la firma local.
