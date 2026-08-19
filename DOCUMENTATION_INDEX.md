# Índice documental vigente · RC13 build 20030

## Fuente de verdad operativa

1. `README.md`: alcance y orden de continuación.
2. `STATUS.md`: estado honesto de puertas locales y externas.
3. `FINAL_RELEASE_AUDIT_RC13_BUILD_20025.md`: auditoría de entrega.
4. `ARCHITECTURE.md`, `DATABASE.md`, `SECURITY.md` y `PLATFORM_EVOLUTION_RULES.md`: contratos vigentes.
5. `SUPABASE_KOMBAX_RC13_20022_20025_RUNBOOK.md`: única secuencia SQL nueva autorizada.
6. `ANDROID_STUDIO_KOMBAX_RC13_BUILD_20025.md`: única guía de firma de esta candidata.
7. `NETLIFY_KOMBAX_BUILD_20025_RUNBOOK.md`: única guía de despliegue web de esta candidata.
8. `LOAD_TEST_RUNBOOK_KOMBAX_100_CLUBS.md`: preparación y criterio de carga, no certificación actual.

## Evidencia histórica

Los documentos cuyo título o nombre indica RC10, RC12, build 20018, 20019, 20020, 20021, 20022, 20023 o 20024 conservan decisiones y resultados de su fase. No deben usarse para desplegar, firmar o migrar build 20025. En caso de discrepancia prevalece siempre la fuente de verdad anterior.

## Regla anti-contradicción

No combinar pasos SQL o Android de dos runbooks. Para build 20025 se parte del estado real verificado del entorno, se ejecuta el preflight vigente y se detiene el proceso ante cualquier diferencia; nunca se fuerza una migración porque un informe histórico la describa como pendiente o aplicada.

## KOMBAX build 20028
- `RC13_BUILD_20028_IMPLEMENTATION_REPORT.md` — implementación y límites de certificación.
- `SUPABASE_KOMBAX_RC13_20028_RUNBOOK.md` — secuencia 051–056.
- `RC13_BUILD_20028_LOCAL_QA.md` — gates local/Supabase/Android.
- `CHANGELOG_RC13_BUILD_20028.md` — cambios funcionales.
- `BUILD_MANIFEST_SHA256_20028.txt` — integridad del paquete final.
## KOMBAX build 20030
- `RC13_BUILD_20030_IMPLEMENTATION_REPORT.md` — arquitectura 057 y validación local.
- `SUPABASE_KOMBAX_RC13_20030_RUNBOOK.md` — fuente operativa vigente; continuar desde 052 y aplicar 057 después de 056.
- `RC13_BUILD_20030_LOCAL_QA.md` — matriz de privacidad Monitor A/B, ámbitos y cartera.
- `CHANGELOG_RC13_BUILD_20030.md` — cambios del build.
- `BUILD_MANIFEST_SHA256_20030.txt` — integridad del paquete final.

