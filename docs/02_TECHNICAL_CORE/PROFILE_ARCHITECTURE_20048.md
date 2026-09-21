# KOMBAX 20.048 · Arquitectura de perfil canónico

## Regla de producto

Una persona Miembro tiene **una sola identidad pública KOMBAX**.

`Mi perfil` = el perfil que abre KOMBAX Social = el perfil que abre Comunidad del Club = el perfil que devuelve el directorio canónico.

## Capas que no deben confundirse

1. **Cuenta KOMBAX**: autenticación humana.
2. **Membresía de Club**: relación privada/operativa con un Club.
3. **Perfil KOMBAX Social**: identidad pública canónica.
4. **Verificación**: estado de identidad oficial, si el tipo es elegible.
5. **Suscripción/entitlements**: servicio/capacidades.
6. **Expediente privado del Club**: asistencia, cuotas, documentos, seguimiento, datos protegidos.

## Miembro

Tiene perfil público enriquecido sin badge KOMBAX. Puede personalizar presentación, banner/avatar, álbum, publicaciones y datos deportivos declarados.

## Competidor

Es una evolución del mismo perfil Social. Cuando se verifica/activa, el mismo Social ID cambia de sujeto a Competidor y añade capacidades oficiales. Si el servicio se desactiva, vuelve a Miembro sin perder Social ID ni contenido.

## Perfil deportivo legacy

`perfiles_deportivos` se conserva temporalmente como fuente histórica privada. Desde 20.048 no es una superficie actual del cliente ni alimenta el sincronizador vigente de Miembro. Su eliminación física requiere una fase posterior con comprobación de clientes antiguos y dependencias cero.
