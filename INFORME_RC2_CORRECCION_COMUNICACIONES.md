# Urban Warriors 2.0.0-rc.2 · corrección E2E comunicaciones

## Evidencia real
La certificación local contra el Supabase real superó contrato, diagnóstico SQL, disciplina, edición de disciplina, grado, grupo+horario, tarifa, alumno+matrícula, sesión, asistencia y seguimiento. Se detuvo en `publicacion.guardar` con `Tipo de publicación no válido`.

## Causa
El frontend/E2E usaba el tipo `aviso`, mientras que las RPC SQL reales aceptan únicamente `noticia`, `evento`, `clase` y `cartel`.

## Corrección
- Comunicaciones ofrece exactamente `noticia`, `evento`, `clase`, `cartel`.
- El E2E usa `noticia` para crear y archivar la comunicación de prueba.
- Se añadieron controles estáticos contra la reintroducción de `aviso`.
- No se modifica Supabase, RLS, RPC ni el contrato 1.6.0.

## Próximo paso
Ejecutar de nuevo la certificación E2E local. Debe continuar desde comunicaciones hacia material, logout/login y limpieza de datos.
