# R110 · Seguridad de Alta Club Piloto

- Dos tablas privadas en `kombax_commercial`, con RLS activado y sin privilegios DML para `anon` ni `authenticated`.
- Los códigos se almacenan únicamente como SHA-256.
- Funciones `SECURITY DEFINER` con `search_path=''` y referencias cualificadas.
- Estado público de la ventana expone únicamente capacidad/fechas, nunca códigos ni identidades.
- Activación requiere usuario autenticado, correo confirmado, código pendiente válido, account type Club y límite transaccional de cuatro plazas mediante advisory lock.
- Generación de códigos requiere autenticación y validación `platform_admin`.
- La ventana piloto no relaja RLS, roles, reglas de menores ni gates propios de Stripe/Commerce.
- R102 (badges pagados) permanece intacto.

Supabase Advisor muestra las dos tablas como `RLS enabled/no policy` a nivel INFO; es deliberado porque no se exponen directamente y se revocó SELECT/INSERT/UPDATE/DELETE a anon/authenticated. No se ha detectado exposición directa añadida por R110.
