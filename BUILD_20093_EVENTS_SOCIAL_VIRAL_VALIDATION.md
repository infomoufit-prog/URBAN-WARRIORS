# KOMBAX RC13 build 20.093 · Events Social & Viral · Validación

## Funcional
- Landing pública de evento por slug antes de login.
- `Me interesa` / `Asistiré` preparado para identidades actuales y futuro Espectador.
- Bridge Social enlaza publicación con evento/combate/resultado sin duplicar la fuente.
- Social mantiene cuotas, moderación, audiencia y su gateway propio.
- Generación local de posts/Stories de evento, combate y resultado.
- QR local escaneable validado con decodificación de prueba.
- Compartir externo con enlace de retorno a KOMBAX.
- Espectador permanece cerrado hasta gate edad/privacidad.

## Backend live
- Migraciones 159–163: aplicadas y registradas.
- RLS/ACL: verificadas.
- Mutadores: no ejecutables por anon.
- 12 índices FK de Eventos: aplicados/verificados.
- `health`: versión 13 / build 20093.

## QA local
- Sintaxis módulos modificados: PASS.
- `test-architecture`: PASS.
- QA 20.090: PASS.
- QA 20.091: PASS.
- QA 20.092: PASS.
- QA 20.093: PASS.
- `npm test`: PASS.
- `npm run build`: PASS.
- Build determinista: web = dist = Android (101 archivos).

## Incidencias detectadas y resueltas
1. Migración 160: `ORDER BY` de alias de salida no aceptado por PostgreSQL en la función SQL. La transacción falló limpia, se corrigió y se reaplicó completa.
2. Visual Engine: el gate arquitectónico rechazó `fetch` directo en módulo UI. Se sustituyó por carga de imagen del navegador sin debilitar el test.
3. Canvas: añadido fallback para path redondeado cuando `ctx.roundRect` no está disponible.

## Validación externa pendiente
- QA visual/manual en APK/PWA real.
- Validación de sharing nativo según dispositivo/app instalada.
- No se declara E2E HTTP `curl` desde el contenedor por falta de resolución DNS externa.
