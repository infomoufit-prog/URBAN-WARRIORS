# R104 · Logo público como identidad del club

## Hallazgo

El club de demostración conserva un logo administrativo JPG anterior en `clubes.logo_url`, mientras su perfil público usa un WebP posterior en `perfiles_club_publicos.logo_url`. Social ya mostraba el segundo. La pantalla de configuración seguía mostrando el primero. Los recibos y algunos informes leían el logo administrativo; los tickets de entidades vinculadas leían el avatar de Social.

## Corrección

- El perfil público es el lugar principal para configurar el logo. Configuración muestra ese mismo logo y abre el perfil público para cambiarlo.
- `287` sincroniza al guardar el perfil público el logo administrativo heredado dentro de la transacción existente, con control de permisos y versión de branding. Si se restaura un branding antiguo, actualiza también el perfil público.
- `288` reconcilia imágenes propias del club subidas al perfil público después de la última publicación administrativa. Conserva el historial previo.
- `289` toma primero el logo público al emitir nuevos recibos y crear nuevos informes financieros. No reescribe recibos ni informes ya emitidos.
- Los tickets de entidades vinculadas siguen tomando el avatar de Social, que ya se sincroniza desde el perfil público. La selección de logos del evento sigue bajo control del organizador.
- Los logos nuevos se almacenan como PNG o JPG para que el generador PDF pueda incrustarlos. Las imágenes anteriores no se borran, porque pueden estar referenciadas por documentos históricos.

## Estado de despliegue y entrega

Las migraciones `287`, `288` y `289` se aplicaron, en ese orden, al proyecto Supabase `poggsobhtutbuagjiydc` el 27 de septiembre de 2026. La comprobación posterior confirmó tres triggers R104 activos y, para el club demo, coincidencia entre el logo público, el administrativo y Social, con la versión anterior preservada en el historial. El frontend y Android están incluidos en el build 20156; el usuario realizará la subida a GitHub y el despliegue en Netlify.

El AAB de Google Play aún requiere la firma release privada: `android/keystore.properties` o las cuatro variables `UW_*`. El preflight Android pasó 4 de 5 comprobaciones; no se generó un AAB firmado. Esta entrega congela el código acumulativo, pero no sustituye el gate integral de seguridad y recuperación del piloto.

El WebP que ya tiene el club de demostración seguirá visible en la web y en recibos. Mientras ese WebP no se vuelva a cargar desde el perfil público, los nuevos informes PDF conservan el último logo JPG compatible para evitar un documento sin imagen. Tras volver a cargarlo, R104 lo guarda como PNG/JPG y los nuevos informes usarán el logo público. No afirmar que un PDF anterior cambia: los snapshots históricos permanecen intactos.
