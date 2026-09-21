# Runbook Supabase · KOMBAX RC13 build 20027 · migraciones 043–050

## Principio de seguridad

Este runbook no autoriza a aplicar cambios a ciegas. Se ejecuta únicamente sobre el proyecto Supabase correcto, después de backup y de confirmar el estado real de 037–042. Nunca cargar fixtures DEMO en producción.

## Prerrequisitos

1. Confirmar proyecto/entorno por URL/ref y propietario.
2. Backup verificable antes de cambios.
3. Confirmar que 037–042 están aplicadas exactamente en el estado esperado.
4. Disponer de acceso SQL administrativo autorizado.
5. Tener una ventana de rollback.
6. Mantener fuera del repositorio service-role keys, contraseñas y dumps de producción.

## Secuencia obligatoria

Aplicar **una migración por vez**, en este orden: 043 → 044 → 045 → 046 → 047 → 048 → 049 → 050.

Para cada número `NNN`:

1. ejecutar el `preflight` correspondiente;
2. si preflight no es totalmente compatible, **STOP** y diagnosticar;
3. aplicar solo `NNN_*.sql`;
4. ejecutar `verify`;
5. ejecutar el test transaccional;
6. comprobar logs/errores y que la API recargó esquema;
7. continuar al siguiente ciclo solo con resultado verde.

No agrupar las ocho migraciones en un bloque único sin puntos de control.

## Objetivo de cada ciclo

### 043 · perfiles, verificación y álbum

- perfiles directos KOMBAX;
- solicitudes/estados de verificación;
- documentación privada;
- álbum 10 fotos + 3 vídeos de 15 s;
- Storage/RLS/RPC asociados.

Validar especialmente que documentación de verificación no sea públicamente legible.

### 044 · Social

- límites de publicaciones;
- comentarios + una respuesta;
- guardados privados;
- modos de comentarios;
- razones de contacto por tipo.

Validar límites 30 activas / 3 nuevas día / 10 con vídeo / 15 s.

### 045 · relaciones y límites Showcase

- relaciones confirmadas;
- provider Club/Marca;
- 15 fichas Club / 30 Marca;
- galería hasta 3 adicionales.

Validar que ninguna relación sensible sea visible por creación unilateral.

### 046 · álbum Club

- álbum del tenant Club;
- 10 fotos + 3 vídeos máximo;
- permisos por tenant.

Validar aislamiento con al menos dos clubes.

### 047 · solicitudes de eliminación

- solicitud/cancelación;
- ámbitos cuenta/perfil/club;
- trazabilidad del proceso.

Validar que el flujo no borre registros económicos requeridos por simple cascada.

### 048 · Showcase global

- gestión de Showcase por Marca KOMBAX verificada sin membresía artificial de Club.

Validar que una Marca no pueda administrar el Showcase de otra entidad.

### 049 · Social global + age-gate

- activación Social institucional global;
- integración de perfiles directos;
- **Competidor/Profesional directos bloqueados hasta contar con edad verificada por club**;
- identidad afiliada al Club mantiene la regla Social 14+ verificada por Club.

Prueba negativa obligatoria: Competidor/Profesional directo verificado intenta activar Social → debe fallar con `KOMBAX_SOCIAL_CLUB_VERIFIED_AGE_REQUIRED`.

### 050 · cumplimiento UGC/moderación

- reportes de publicación/comentario/perfil;
- cola de moderación;
- ocultación;
- limitación/suspensión de perfil;
- resolución/descartado con auditoría.

Validar que usuarios no moderadores no acceden a la cola ni a acciones privilegiadas.

## Matriz E2E mínima después de 050

Crear/usar datos QA controlados, no fixtures de carga en producción:

- Club A y Club B.
- Gestor A y Gestor B.
- Competidor adulto afiliado/verificado.
- Perfil 14+ con edad verificada por club para Social cuando corresponda.
- Marca verificada.
- Federación verificada.
- Profesional verificado.
- Moderador KOMBAX.

Comprobar:

1. Club A no lee/escribe datos privados de Club B.
2. Storage respeta identidad/tenant y tipo de bucket.
3. Documentación de verificación nunca aparece en álbum público.
4. Límites de álbum y vídeo se aplican server-side.
5. Límites de Social se aplican server-side.
6. Guardados son privados.
7. Comentarios no admiten más de una capa de respuesta.
8. Denunciar publicación/comentario/perfil genera una incidencia válida.
9. Bloqueo impide interacciones previstas.
10. Moderador puede resolver; usuario común no.
11. Relaciones requieren confirmación/autorización.
12. Marca gestiona solo su propio Showcase.
13. Club respeta 15 fichas; Marca 30.
14. Eliminación crea solicitud trazable y no elimina indiscriminadamente finanzas.
15. Competidor/Profesional directo no activa Social sin age-gate de Club.
16. Flujo afiliado 14+ funciona solo con edad verificada por club.

## Rollback

- No ejecutar rollback de forma automática por una incidencia funcional sin entender dependencias.
- Si se autoriza rollback, hacerlo en orden inverso: 050 → 049 → 048 → 047 → 046 → 045 → 044 → 043.
- Ejecutar únicamente el rollback suministrado para el ciclo correspondiente y volver a verificar esquema/RLS/Storage.
- Restaurar backup si el rollback lógico no puede garantizar integridad.

## Criterio de salida Supabase

Gate Backend solo se considera cerrado cuando:

- 043–050 necesarias están aplicadas y verificadas;
- tests transaccionales reales pasan;
- RLS por roles pasa;
- aislamiento entre al menos dos clubes pasa;
- Storage y borrado pasan;
- age-gate y moderación UGC pasan E2E;
- no hay cruces de tenant ni escalada de privilegios observada.
