# KOMBAX R274 · Entrega acumulativa

Incluye la base acumulativa R272 y los cambios R273/R274 de ayuda, créditos y navegación. Marca, Federación, Competidor, Profesional y Media comparten el orden visual: Inicio, Perfil público, Social, Events, Showcase, Recursos y herramientas específicas de la identidad. Las herramientas están plegadas y conservan colores LED y permisos.

## Reunificar

Guarda las cuatro partes y `UNIR_KOMBAX_R274_ACUMULATIVO.cmd` juntas. Ejecuta el reunificador. Obtendrás `KOMBAX_R274_AYUDA_PERFILES_ACUMULATIVO.zip`; el script verifica SHA-256 antes de indicar que está listo.

Las cuatro partes son fragmentos binarios de un solo ZIP: no se extraen individualmente. El ZIP reunificado sí se puede extraer normalmente.

## Actualizar la web

1. Conserva una copia de tu carpeta actual.
2. Extrae el ZIP reunificado en una carpeta nueva. La raíz correcta contiene `package.json`, `netlify.toml`, `web`, `scripts`, `supabase` y `android`.
3. Copia ese contenido completo a la raíz de tu repositorio local, conservando su carpeta `.git`. Evita crear una carpeta de proyecto adicional dentro del repositorio.
4. Tú haces la actualización de GitHub y el despliegue de Netlify. La configuración conservada ejecuta `npm run release:build` y publica `dist`.
5. Comprueba el identificador del despliegue y recarga la aplicación; una pestaña ya abierta puede seguir usando recursos anteriores hasta actualizarse.

No se ha hecho push, commit, merge, PR ni deploy de Netlify desde esta entrega.

## Backend ya aplicado

La migración `universal_help_free_quota_r274` ya está aplicada en el proyecto KOMBAX, versión remota `20261015214436`. El archivo local se llama `20261015182614_universal_help_free_quota_r274.sql`: la marca de tiempo local es distinta. No lo ejecutes de nuevo ni hagas un db push indiscriminado por esa diferencia.

Funciones desplegadas: `kombax-usage-help` v3 y `kombax-assist-r38` v24. No hay secrets nuevos que introducir para esta fase. Los secrets reales existentes permanecen en Supabase y no se incluyen en el ZIP.

La configuración OAuth/Meta y su código anterior se conservan. Esta entrega no acredita una conexión Instagram o publicación real nueva; las pruebas de ayuda utilizan proveedor simulado.

## Créditos y ayuda

- Guías y tutoriales locales sin inferencia para todas las cuentas.
- Cuenta gratuita: cinco consultas IA completadas por mes y por cuenta, compartidas entre identidades.
- Cuentas de pago: cartera existente compartida por Ayuda, Assist y Migrations, con saldo mensual plegado en el chat. No se han elevado artificialmente las asignaciones de planes.
- Sin identidad: información genérica. Los procedimientos se seleccionan según identidad, rol, verificación y capa contratada.
- El competidor verificado conserva la orientación Social gratuita; publicar sigue sujeto a los permisos reales del servidor.

## QA y límites

Consulta `docs/INFORME_AYUDA_R274.md` y `docs/ENTREGA_FINAL_R274.md`. Se distinguen pruebas SQL reales con rollback, pruebas aisladas y revisión visual con datos ficticios.

Las tres incidencias P2 de traducción heredadas continúan documentadas; la suite estricta no se declara totalmente limpia. No se han activado automatizaciones de cobro ni abierto la contratación pública nueva de Marca/Federación.

Se incluyen fuentes Android y recursos web sincronizados. No se ha generado una APK/AAB nueva: compilar y firmar Android es un paso aparte, con un código de versión no utilizado.
