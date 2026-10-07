# Integración Instagram FIX20 — plan de ejecución

## Auditoría inicial (7 octubre 2026)

El checkout usa una web ES modules en `web/`, copiada por el build a `dist/` y Android. Netlify sirve estáticos; no existe un directorio de Netlify Functions. Supabase Auth autentica por JWT y las integraciones Stripe ya usan Edge Functions, `authenticatedUser`, RPC de usuario y RPC internas. No existe almacenamiento KOMBAX de OAuth/Instagram (las tablas OAuth de `auth` pertenecen a Supabase Auth y no deben reutilizarse).

Identidad canónica: `kombax_social_perfiles`, con referencias a `clubes`, `perfiles_kombax_directos` e `identidades_sociales`. Permisos actuales: titular del club en `miembros_club` con dirección activa; gestores de perfiles en `kombax_perfil_gestores`; publicación en `app_kombax_social_puede_actuar_v051`. Los pilotos conservan esa regla. No se cambiarán permisos ni cuotas existentes.

## Secuencia aprobada

1. Almacenamiento privado con RLS: metadatos, credenciales AES-GCM separadas, estados OAuth, intentos de publicación y auditoría sin secretos.
2. Edge Functions de control, callback, desautorización y eliminación de datos de Meta. Toda ruta sensible vuelve a comprobar permisos de la identidad.
3. OAuth por redirección. State aleatorio, caducidad y consumo atómico. El callback entrega un código de continuación opaco; solo la sesión iniciadora con una prueba aleatoria guardada temporalmente en sessionStorage puede finalizar el intercambio. Nunca guardar tokens Meta ni códigos OAuth en el navegador.
4. Elección explícita de página/Instagram. No conectar la primera página de la lista.
5. Publicación básica de una imagen JPEG de una publicación pública y activa de Social. Contenido y archivo se resuelven en servidor; no aceptar URLs arbitrarias ni contenidos retirados. Intento único por publicación/conexión para evitar duplicados; un resultado incierto exige revisión, nunca reintento automático de publicación.
6. UI mínima en Social para conectar, elegir cuenta, consultar estado y desconectar. Acción explícita para publicar una publicación existente en Instagram, sin alterar el guardado de Social.
7. Tests de handlers con Graph simulado, SQL/RLS en base aislada si hay runtime disponible, regresión y build. Separar pruebas aisladas de pruebas reales; no introducir secretos ni aplicar migraciones a producción.

## Límites

Sin despliegues, secretos reales, publicaciones reales, App Review ni cambios de catálogo. La nueva integración requiere un despliegue posterior autorizado. El OAuth móvil se hace desde la web/PWA del dominio configurado; un WebView Android local no comparte sessionStorage con el navegador externo: se debe abrir y completar la conexión en la web autenticada. Videos, carruseles y stories quedan fuera de esta fase.
