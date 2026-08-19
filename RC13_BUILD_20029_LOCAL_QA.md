# QA LOCAL · KOMBAX RC13 build 20029

Ejecutar únicamente después de aplicar/verificar 051–056 en el Supabase real.

## Arranque
```bash
npm install
npm run dev
```
Abrir `http://127.0.0.1:4173`.

## Social · bloque obligatorio
- Entrar como Gestor/Coordinación y confirmar `Actuar como <Club> · Club`.
- En `KOMBAX Social > Actualidad`, el compositor de texto debe estar visible sin abrir modal.
- Publicar texto y confirmar aparición inmediata en el feed.
- Abrir `Foto / vídeo`, subir foto y publicar.
- Subir vídeo <=15 s; probar >15 s y confirmar rechazo.
- Hacer scroll largo: el feed debe cargar más de forma progresiva, sin salto horizontal ni duplicados.
- Confirmar likes, comentarios, guardados, compartir, denuncia y bloqueo.

## Comunidad
- Entrar en `Comunidad del Club`.
- Debe indicarse claramente que la publicación es interna.
- `Ir a KOMBAX Social` debe llevar a la red pública.
- Una publicación interna no debe aparecer automáticamente en Social.

## Showcase
- Entrar como Club/Marca autorizado.
- Crear ficha en borrador.
- Subir imagen principal desde dispositivo.
- Subir hasta 3 imágenes de galería.
- Guardar, volver a editar y publicar.
- Confirmar que la ficha publicada aparece en Showcase público.
- Probar CTA, guardar y compartir.
- Archivar y confirmar que desaparece del catálogo público.

## Visual
- Confirmar rojo sangre intenso y contraste correcto.
- Microanimaciones suaves, no invasivas.
- Probar 360/390/412/430 px, tablet y escritorio.
- Confirmar scroll vertical fluido y ausencia de overflow horizontal.

## Seguridad
- Usuario sin permiso no puede publicar como Club ni gestionar su Showcase.
- Segundo Club QA no puede editar/eliminar media del primero.
- platform_admin sí puede entrar en Administración KOMBAX, usuario normal no.
