# Continuidad — KOMBAX 20.101 R50

## Baseline
Usar R50 como continuación de R49 una vez superado QA manual. R49 permanece como base congelada anterior.

## Contratos que no deben romperse
1. KOMBAX Social: Like público separado de Me interesa / No me interesa privado.
2. KOMBAX Social: visibilidad se filtra antes del ranking y nunca se concede por ranking.
3. Multimedia: 16:9 horizontal, 9:16 vertical, 1:1 cuadrado; click/tap abre original completo.
4. Encuadre: Mostrar completo es opción segura; Rellenar marco puede recortar de forma controlada y respeta foco.
5. Vídeo: UX <=60 s, backend <=60,2 s, <=100 MB, HD 1080p orientation-safe. MP4 recomendado.
6. KOMBAX Events: preservar Main Event, Co-Main Event, Fight Card estructurada, cartel adicional y fotos opcionales.
7. Nomenclatura de producto: **KOMBAX Social** y **KOMBAX Events**.

## Backend
Cadena R50 local: migraciones 241–244. No reescribir historial vivo. El helper HD final debe conservar `search_path=public` y permanecer sin EXECUTE directo para anon/authenticated.

## Protocolo siguiente
Antes de convertir R50 en baseline de producción:
- QA autenticada móvil con foto horizontal, vertical y cuadrada.
- QA de vídeo MP4 horizontal/vertical cercano a 60 s.
- comprobar fullscreen y foco.
- generar APK/AAB firmada únicamente en entorno que tenga `android/keystore.properties` local.
- revisar Advisors en una fase de hardening independiente.

No desplegar frontend ni hacer push a GitHub sin autorización explícita.
