# KOMBAX 20.101 R53 · Auditoría definitiva · Mi red y perfiles públicos

## Alcance
R53 convierte **Mi red** en una red KOMBAX real y privada, disponible desde cualquier perfil público activo/visible, sin obligar a que exista una relación profesional entre las identidades. Los vínculos profesionales existentes se mantienen como semántica adicional y no como requisito de conexión.

## Hallazgo previo
El buscador podía mostrar perfiles, pero la acción de relación dependía de combinaciones profesionales concretas. Esto dejaba fuera a perfiles válidos —especialmente Miembro y otras combinaciones— y la ficha pública no ofrecía una acción universal para solicitar conexión.

## Corrección R53
- Nuevo tipo privado `conexion_kombax` en backend.
- Solicitud genérica entre dos perfiles KOMBAX distintos, siempre que el perfil destino esté activo y visible y el origen pertenezca al usuario autenticado.
- Prevención de duplicados en ambos sentidos para solicitudes pendientes o conexiones confirmadas.
- El botón **Añadir a mi red** aparece en fichas públicas ajenas y el directorio reutiliza el mismo flujo.
- La conexión requiere aceptación; no se publica la lista de contactos ni el tamaño de la red.
- Se conservan aceptar, rechazar y eliminar de Mi red.
- Los vínculos Club↔Federación, Competidor↔Club, Marca↔Club, etc. permanecen diferenciados de la conexión social genérica.

## Perfil público universal
El layout se aplica a **Miembro, Club, Federación, Marca, Competidor, Profesional y cualquier identidad pública KOMBAX visible**. La información se filtra por las políticas públicas existentes; R53 no abre datos privados.

### Estructura
1. Cabecera pública coherente: identidad, tipo, verificación/afiliación cuando proceda y acciones.
2. CTA de red: **Añadir a mi red / Solicitud enviada** en perfiles ajenos.
3. Álbum clasificado: **Todo / Fotos / Vídeos**.
4. **Últimas 5 publicaciones** visibles para el espectador, con acceso a ver más.
5. Área **Showcase** propia del perfil: hasta 4 fichas inicialmente, opción de expandir las publicaciones activas disponibles; estado vacío si no hay productos.

## Privacidad y visibilidad
- Solo se permite solicitar conexión hacia perfiles `visible=true` y `estado='activo'`.
- El perfil público sigue dependiendo de los RPC/políticas existentes para decidir qué publicaciones, multimedia y Showcase puede ver cada espectador.
- Datos financieros, administrativos, familiares, documentos y demás áreas privadas no se incorporan a la ficha pública.

## Backend aplicado
Migración: `247_kombax_network_public_profiles_r53.sql`.
Aplicada al proyecto Supabase principal como `kombax_network_public_profiles_r53`.

## Verificación automática
`npm run test:20101:r53` → **21/21 PASS**.
`npm test` completo → **EXIT 0**.

## QA manual recomendado para piloto
- Solicitud Miembro→Miembro y Miembro→Club.
- Club→Federación y Marca→Club manteniendo la distinción entre conexión KOMBAX y vínculo profesional.
- Aceptar/rechazar desde la cuenta destino.
- Confirmar que no se duplica una solicitud invertida.
- Eliminar una conexión confirmada.
- Probar perfiles con visibilidades distintas y confirmar que no se filtra contenido no autorizado.
