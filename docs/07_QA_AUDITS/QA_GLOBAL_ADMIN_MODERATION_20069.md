# QA build 20069

| Ámbito | Owner con contexto temporal | Moderador | Usuario/gestor ordinario |
|---|---:|---:|---:|
| Buscar cuentas y entidades privadas | Sí | No | No |
| Abrir modo Administrador KOMBAX | Sí | No | No |
| Finanzas, cobros y recibos | Sí, para soporte autorizado | No | Solo permisos del Club |
| Verificación y servicio | Sí | No | Solo perfil propio permitido |
| Roles críticos | Sí, mediante acción específica | No | No |
| Cola de denuncias | Sí | Sí | No |
| Ocultar/restaurar contenido | Sí | Sí | No |
| Advertir/escalar/suspender | Sí | Sí, según objetivo | No |
| Publicar como entidad | No implícitamente | No | Solo permiso real existente |

## Recorrido manual

1. Entrar en `/admin` con Owner y contraseña.
2. Buscar Urban Warriors y abrirlo indicando un motivo de al menos 10 caracteres.
3. Confirmar `MODO ADMINISTRADOR KOMBAX`, caducidad y ámbitos.
4. Repetir con Club QA, Federación, Marca, Competidor y una cuenta.
5. Salir explícitamente y confirmar que el detalle deja de estar disponible.
6. Con Moderador, abrir Seguridad en KOMBAX Social y comprobar la cola.
7. Registrar revisión, advertencia y escalado; ocultar/restaurar solo contenido y suspender solo perfiles.
8. Confirmar que Moderador no recibe Finanzas ni roles críticos.
9. Confirmar que un usuario ordinario recibe acceso denegado en RPC privilegiadas.

No usar datos reales ni suspender contenido que no esté marcado como QA.

## Resultado automatizado

- Backend LIVE: PASS transaccional y revertido.
- Suite de regresión completa: PASS.
- Test específico build 20069: PASS.
- Build: PASS.
- Paridad: 68/68 archivos iguales en `web`, `dist` y assets Android.
- Preflight Android: 4/5; solo falta la firma local, deliberadamente no incluida. No se generó APK/AAB.
- Prueba visual interactiva del nuevo frontend: pendiente de preview o deploy autorizado; el deploy actual no fue modificado.
