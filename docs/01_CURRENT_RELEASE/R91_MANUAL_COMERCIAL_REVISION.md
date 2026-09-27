# Revisión editorial del Manual KOMBAX de Gestión de Clubes

Esta revisión parte del paquete acumulativo R91 build 20144 facilitado por el propietario. No cambia el runtime, las guías públicas ni el acceso privado al manual.

Cambios del manual:

- Portada con la imagen comercial de las dos peleadoras incluida en los assets de KOMBAX.
- Eliminados del PDF los códigos de edición, la fecha de revisión y las referencias internas de producción.
- Referencias cruzadas expresadas con nombres de guías y territorios, sin códigos editoriales.
- Explicación para el lector de los datos que debe confirmar antes de actuar.
- Conservados el contenido práctico, las fuentes oficiales y los avisos de asesoramiento individualizado.
- Nueva composición premium con titulares Georgia, texto Segoe UI, índice a dos columnas, jerarquía visual más clara, tablas espaciadas y capítulos mejor paginados.
- Se han revisado los saltos de página y el capítulo final para evitar títulos huérfanos.

Archivos mantenidos:

- `artifacts/manuals/KOMBAX_MANUAL_GESTION_DE_CLUBES_R100_1.pdf`: manual privado actualizado.
- `artifacts/manuals/MANUAL_KOMBAX_GESTION_DE_CLUBES_R100_1.md`: texto editable.
- `artifacts/guides-r100-1/_build/KOMBAX_MANUAL_GESTION_DE_CLUBES_R100_1.html`: maquetación comercial reproducible.
- `scripts/build-kombax-guides-r100-1.py`: conserva la maquetación comercial al regenerar el manual.

Verificación de esta revisión: PDF de 73 páginas con texto extraíble, sin páginas vacías, códigos de edición ni marcas «PENDIENTE»; revisión visual de portada, índice, páginas interiores y cierre. El gate R91 se ejecuta de nuevo para el paquete premium.

El plan de reconstrucción de las guías y del Centro KOMBAX se conserva en `docs/01_CURRENT_RELEASE/PLAN_CENTRO_KOMBAX_GUIAS_Y_PERFILES.md`. Describe trabajo futuro y no modifica la biblioteca pública ni la navegación en este paquete.
