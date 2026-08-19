# KOMBAX RC13 · build 20042

## Entrada de marca
- La pantalla de elección de acceso incorpora un escenario visual KOMBAX con símbolo rojo, wordmark y tagline como fondo editorial.
- La marca ambiental no intercepta interacción y está oculta a lectores de pantalla por ser decorativa.
- Los accesos `Entrar con mi club` y `Crear o acceder a un perfil KOMBAX` conservan funcionalidad y jerarquía.

## PWA / escritorio
- Logo de esquina ampliado.
- Símbolo/wordmark de fondo de gran formato.
- Halo rojo y profundidad visual reforzados sin reducir contraste del copy.

## Móvil
- Adaptación específica: se mantiene solo el símbolo ambiental a baja opacidad.
- El wordmark/tagline de fondo se ocultan en viewport pequeño para evitar saturación.

## QA
- Nueva regresión `test-kombax-20042-gateway-brand.mjs`.
- Suite completa RC4→20042 PASS.
- Build determinista web/dist/Android PASS.
- Android preflight 4/5; firma JKS sigue siendo local y no se incluye.
