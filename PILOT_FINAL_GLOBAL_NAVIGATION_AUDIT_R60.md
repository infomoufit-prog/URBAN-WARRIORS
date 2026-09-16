# KOMBAX 20.110 R60 · Pilot Final · Global Navigation / Privacy / History / Hero Audit

## Alcance
Esta iteración cierra la navegación de subventanas y capas para PWA, Android móvil y tablet, manteniendo las correcciones de privacidad, historial, mensajería y hero de KOMBAX Social.

## Política de navegación aplicada
- **Volver** retrocede un nivel y restaura el contexto anterior cuando existe una capa o modal padre.
- **Cerrar (X)** sale de la capa/subventana actual mediante su ruta de salida validada; en cadenas modales genéricas cierra la cadena completa.
- Los subviews de pantalla completa que ya tienen una ruta `Volver` válida reciben automáticamente un control `Cerrar` coherente.
- Las páginas raíz de módulo no reciben controles artificiales si no existe una vista padre real.
- Visores fullscreen de foto/vídeo incluyen `Volver` + `Cerrar`, respetando safe areas y targets táctiles.

## Cobertura relevante
La mejora se aplica al sistema común de modales y a subviews de Gateway/directorio, perfiles gestionados, Federación, módulos globales, preparación de competición, Showcase, Assist, Migrations, Soporte guiado, Conversaciones KOMBAX y álbumes multimedia. Los módulos que usan el componente común heredan el comportamiento sin duplicar lógica.

## Navegación anidada
Se añadió una pila de modales. Abrir un detalle desde otro modal suspende el modal padre; `Volver` restaura ese modal y el foco anterior. Esto evita rutas de escape alternativas y evita reabrir duplicados, por ejemplo álbum → media → volver al mismo álbum.

## Privacidad Social
- En un perfil ajeno, `Actividad KOMBAX` no expone la audiencia de la publicación (Todo KOMBAX, club, federación u otros destinos).
- La audiencia sigue disponible para el autor/gestor autorizado en sus herramientas de gestión.
- El backend `app_kombax_social_profile_posts_v256` mantiene la comprobación de visibilidad y redacta metadatos de audiencia para terceros.

## Historial Assist / Migrations
- El flujo de borrado usa la sesión autenticada real del usuario para el finalizador propietario `app_kombax_customer_history_delete_finalize_v256`.
- La Edge Function `kombax-history-delete-r60` live está en v6 con esta ruta.
- Las cuotas consumidas se preservan tras borrar contenido.
- La confirmación final en un dispositivo Android autenticado sigue siendo prueba manual obligatoria del piloto.

## KOMBAX Social hero
Se consolidó un override final sin zoom transformado y con headroom específico para teléfono/tablet/desktop y portrait/landscape. El objetivo es mantener al peleador ligeramente a la derecha, recuperar la cabeza completa y mostrar más acompañantes. La geometría está validada estáticamente; la confirmación final corresponde a la prueba física del APK/PWA.

## QA ejecutado
- `npm test`: PASS completo.
- `npm run test:20110:r60`: PASS.
- R60 Migrations: 32/32.
- Assist / Support / Conversations: 28/28.
- Profile / Chat polish: 24/24.
- Nav / Support / Privacy / Delete / Hero: 16/16.
- Global Back / Close Navigation: 16/16.
- Legal release gate: PASS.
- Build: 197 archivos · `web = dist = Android`.
- Android preflight: 4/5; solo falta `android/keystore.properties` local.

## Estado de seguridad global
La auditoría global de Supabase todavía contiene backlog histórico de hardening (RLS/policies, exposición de funciones SECURITY DEFINER, índices y protección de contraseñas filtradas). Este backlog no se declara resuelto por esta iteración y debe tratarse como carril separado antes de producción general.

## Criterio de piloto
Este paquete es candidato de validación física del piloto. No incluye claves ni material de firma Android.
