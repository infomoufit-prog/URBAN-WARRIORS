# Verificación después de guardar los secrets

7 de octubre de 2026. Pruebas HTTP reales, sin leer secretos ni usar tokens de una cuenta Instagram.

| Función | Resultado | Interpretación |
|---|---|---|
| meta-instagram | 401 sin Authorization | Gateway protege el control autenticado |
| meta-instagram-callback | 303 sin estado OAuth | Configuración aceptada; redirección de intento inválido, no autorización correcta |
| meta-instagram-deauthorize | 400 con firma inválida | Rechaza solicitud sin firma válida |
| meta-instagram-data-deletion | 404 con confirmación inexistente | No expone una solicitud de borrado inexistente |

Los callbacks ya no devuelven 503 configuration_pending. Esto confirma que la configuración supera la validación de formato del backend; no prueba todavía que el App Secret corresponda a la app ni que Meta conceda permisos.

Pendientes: registrar/verificar tres URLs en Meta, desplegar frontend actualizado por el usuario, habilitar la integración en entorno autorizado, OAuth profesional vinculado a Página, comprobación de conexión cifrada, publicación solo con autorización expresa sobre cuenta y contenido, desconexión y eliminación de la conexión de prueba.

No se han publicado contenidos, cambiado GitHub, desplegado Netlify ni ejecutado una eliminación real. La configuración pasa la comprobación inicial, pero la integración de extremo a extremo sigue pendiente.
