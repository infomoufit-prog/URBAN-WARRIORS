# KOMBAX · FIX14 acumulativo · 6 de octubre de 2026

Esta entrega contiene FIX13 y las mejoras de acceso, espacios administrativos de identidades, equipos, disciplinas y grados. El informe vigente es `docs/qa/AUDITORIA_ACUMULATIVA_FIX14.md`; los informes anteriores describen sus respectivas revisiones.

## Reunir y actualizar

1. Descarga `KOMBAX_20178_R120_FIX14.zip.001`, `.002`, `.003`, `.004` y `UNIR_KOMBAX_20178_FIX14.cmd` en una misma carpeta. Son fragmentos binarios de un único ZIP, no cuatro ZIP independientes.
2. Ejecuta el CMD. Reúne el archivo y verifica SHA-256 antes de permitir su uso. No mezcles partes de FIX13 y FIX14.
3. Extrae el ZIP completo en una carpeta nueva. Conserva una copia de tu instalación y de sus cambios pendientes. Mantén `.git`, las variables privadas, la configuración local de Android y las claves de firma fuera de la sustitución del código.
4. Traslada el contenido de la carpeta del proyecto a la raíz de tu repositorio; no añadas una carpeta anidada extra. Revisa los cambios antes de tu propio push. No se ha hecho push ni despliegue web en esta entrega.
5. El frontend nuevo requiere un despliegue en Netlify para estar disponible en la webapp. El proyecto conserva `netlify.toml`, el lockfile y los recursos de `dist` sincronizados. La validación y sus límites están en el informe QA.

## Supabase

Estas tres migraciones FIX14 están aplicadas al proyecto `poggsobhtutbuagjiydc` y sus nombres locales coinciden con el registro del servidor:

- `20261006091733_profile_admin_workspace_seller_entry_fix14.sql`
- `20261006093011_club_grade_team_role_fix14.sql`
- `20261006093718_club_owner_final_decisions_fix14.sql`

No vuelvas a ejecutarlas en este proyecto si ya están registradas. En otra instalación deben revisarse y aplicarse en orden después de la base acumulativa. El almacenamiento administrativo es privado; el logo/banner Social permanece independiente.

## Uso

El acceso general conserva correo, contraseña, crear cuenta gratuita, recuperar contraseña, cancelar y entrar. «¿Dónde quieres entrar?» permite abrir un perfil/club o gestionar la cuenta. Con varias identidades se elige cuál abrir; con una sola se entra directamente. La administración general de identidades siempre se puede abrir explícitamente.

Cada espacio conserva su identidad, navegación LED, equipo y servicios. Mi Espacio permite buscar activos/archivados y recuperar una identidad archivada. Archivar aquí no oculta el perfil público ni cancela la suscripción. La eliminación individual sigue siendo una solicitud con seguimiento.

En Mi Club → Disciplinas y grados, cada disciplina tiene sus grados: nombre, nivel, color y meses mínimos. Añadir un grado propone el siguiente nivel disponible. La disciplina se conserva al editar; un grado utilizado no se puede trasladar a otra disciplina desde el backend.

En Mi Club → Equipo, la administración titular puede cambiar el rol de una persona existente. El nuevo rol sustituye las funciones anteriores; coordinación reúne secretaría, tesorería y comunicación. Puede haber varios coordinadores o secretarios. No se crea otra cuenta ni se transfiere la titularidad.

Coordinación gestiona alumnos, matrículas y pagos manuales. La aprobación del equipo, cambios de rol, cambios de plan y solicitud de eliminación del club quedan reservados al titular. El rol interno del titular sigue siendo `direccion`, para conservar la compatibilidad existente. Las restricciones también se aplican a los clubes piloto.

El vendedor puede preparar un borrador antes de verificar su identidad; enviarlo, publicar, vender y cobrar siguen sujetos a sus requisitos vigentes. La tienda corresponde a la identidad seleccionada. No se ha creado un vendedor gratuito ni abierto la contratación pública nueva de Marca/Federación. Las finanzas autorizadas siguen habilitadas y las automatizaciones de cobro no se han activado.

## Android y límites de validación

Los recursos Android están sincronizados con la web; no se incluye ni se afirma una APK/AAB nueva compilada. Para Google Play necesitas compilar con un `versionCode` superior al máximo usado y conservar la firma. La referencia base 20178 ya utilizada no sirve como código de una nueva subida.

Las pruebas en navegador usan datos simulados y las comprobaciones SQL de escritura se revirtieron. No se realizaron cobros, correos, altas reales ni pruebas en teléfonos físicos. La regresión mantiene los tres pendientes históricos de traducción; `npm test` estricto sigue detectándolos. No se amplió su línea base. Los textos nuevos usan el respaldo inglés vigente para los idiomas distintos del español.
