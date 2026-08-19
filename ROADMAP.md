# Roadmap controlado · KOMBAX / Urban Warriors

Estado vigente: **RC13 build 20025**. Urban Warriors sigue siendo el tenant piloto y conserva la identidad Android instalada.

## Implementado localmente

1. **20022 · estabilización**: notificaciones leídas persistentes, nombre completo normalizado, observabilidad de latencia, archivo/papelera, recibos y cuatro temas versionados.
2. **20023 · base multiclub**: puerta KOMBAX, búsqueda de club, contextos aislados, Urban Warriors real y cinco fichas DEMO sin acceso real.
3. **20024 · KOMBAX Social Alpha**: perfiles públicos, feed, likes privados, solicitud estructurada de contacto, bloqueo, denuncia y moderación. No incluye chat, seguidores ni contacto con menores.
4. **20025 · KOMBAX Showcase**: escaparate puramente informativo. No incluye tienda, carrito, pedidos, pagos, stock, envíos ni marketplace.
5. **Preparación de capacidad**: fixtures protegidos y escenario K6 progresivo para 10/50/100 clubes. Preparación no equivale a certificación de carga.

## Siguiente secuencia obligatoria

1. Aplicar 037–042 en un Supabase autorizado siguiendo el runbook vigente.
2. Certificar SQL, RLS, aislamiento entre al menos dos clubes y flujos E2E por rol.
3. Validar PC, móvil web y Android físico; medir P50/P95 y errores.
4. Añadir Firebase y el JKS existente solo en el entorno local de firma.
5. Generar APK/AAB 20025, verificar certificados e instalar encima de 20021 sin desinstalar.
6. Ejecutar carga progresiva y corregir cuellos de botella antes de afirmar soporte demostrado para 100 clubes.
7. Desactivar datos DEMO para producción y desplegar Netlify desde el mismo estado certificado.

## Evolución posterior, no habilitada ahora

- Alta, suscripción y cobro de perfiles directos: competidor, marca, federación, espectador y profesional vinculado.
- Reglas y beneficios concretos de cada perfil directo.
- Seguidores, amistades, chat o mensajería.
- Operaciones comerciales en Showcase.
- Brackets automáticos y servicios avanzados multiclub.

Estas ampliaciones requieren un ciclo propio de concepto, privacidad, permisos, datos, RPC/RLS, pruebas, migración y validación real. No deben activarse mediante un simple cambio visual o un flag sin backend autorizado.
