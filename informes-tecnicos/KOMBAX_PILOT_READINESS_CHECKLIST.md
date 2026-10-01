# KOMBAX R116 — Pilot Readiness Checklist

Fecha: 2026-10-01 · Build 20169 · Ventana piloto: 01/10/2026–15/11/2026

Leyenda: GREEN = verificado local/estático · AMBER = requiere credencial, servicio remoto o dispositivo · RED = bloqueante conocido.

| Estado | Gate | Resultado |
|---|---|---|
| GREEN | Baseline | R113 preservada con SHA-256 conocido |
| GREEN | R116 QA | 12/12 PASS |
| GREEN | R115 identidad | 11/11 PASS |
| GREEN | Release gate | 60 PASS · 5 P2 históricos · 0 fallos nuevos |
| GREEN | Build | 621 archivos web = dist = Android |
| GREEN | Cuenta gratuita | neutra; no se asigna Espectador automáticamente |
| GREEN | Onboarding | 8 recorridos visibles |
| GREEN | Miembro/Familiar | reutiliza vinculación/claim con club |
| GREEN | Social Miembro | requiere membresía activa confirmada por club |
| GREEN | Competidor | vía autónoma verificada + evolución desde Miembro |
| GREEN | Compras/Eventos | navegación/compra gratuita preservada según edad/reglas |
| GREEN | Precios piloto | ocultos; catálogo interno preservado |
| GREEN | Owner Command Center | frontend + SQL + PDF incluidos |
| GREEN | Push Owner global | fix incluido en función local |
| GREEN | Android identity | `com.urbanwarriors.app` |
| GREEN | Android target | API 36 |
| GREEN | Firebase config | presente |
| GREEN | Java/Gradle contract | JDK 17/21 compatible; wrapper 8.11.1 |
| GREEN | Netlify config | build `release:build`, publish `dist`, headers/CSP/redirects |
| GREEN | Supabase remoto | proyecto esperado activo/saludable en lectura |
| GREEN | Supabase dependencies | dependencias de patch comprobadas en lectura |
| AMBER | DB R116 | ejecutar preflight → patch explícito → postflight |
| AMBER | notification-dispatch | redeploy requerido |
| AMBER | Owner PDF function | deploy requerido |
| AMBER | health | redeploy build 20169 requerido |
| AMBER | Push físico miembros | probar foreground/background/cerrada |
| AMBER | Push físico Owner | probar alerta global y deep-link |
| AMBER | Owner PDF remoto | generar, abrir URL firmada y verificar permisos |
| AMBER | Netlify | enlazar al proyecto KOMBAX correcto y hacer preview/prod |
| AMBER | Firma Google Play | configurar upload key registrada fuera del ZIP |
| AMBER | APK/AAB real | compilar en PC con acceso Gradle/Maven |
| AMBER | Closed test | 12 testers continuos durante 14 días si aplica a la cuenta personal |
| AMBER | Web Vitals | medir tras deploy real |
| RED | Fallos nuevos conocidos | ninguno |

## Decisión

**Código congelable:** GO.

**Inicio del piloto remoto:** GO después de cerrar DB/Functions, preview Netlify, firma/AAB y una prueba física mínima de push.
