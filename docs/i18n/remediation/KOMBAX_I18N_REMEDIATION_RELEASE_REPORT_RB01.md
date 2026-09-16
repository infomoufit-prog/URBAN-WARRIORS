# KOMBAX i18n · Remediation RB01 R01-R05 · Release report

## Resultado

**RB01 cerrado como base acumulativa de continuidad.** No equivale todavía a «inglés completo en toda la aplicación»; ese gate queda explícitamente abierto para RB02 R06-R10.

### Implementado
- detector reproducible de hardcodes KOMBAX;
- separación entre cobertura de catálogo y cobertura de extracción;
- catálogo ES/EN ampliado a 1.077 claves;
- 645 referencias i18n activas;
- landing/public overview migrado;
- gateway de identidades migrado;
- entrada principal, directorio de club y autenticación global migrados;
- common UI prioritario;
- Sports Profile completo/prioritario y Public Profile prioritario;
- Finanzas core prioritarias;
- Social Network y capas prioritarias de Social;
- contrato no operativo para futura traducción derivada de user content preservando el original.

### No se declara completado todavía
- Events/Ticketing profundo;
- Showcase/Commerce profundo;
- Platform Admin completo;
- Finance Premium completo;
- gateway/forms privados restantes;
- Social profundo restante;
- HTML públicos/legal/PWA/Auth templates/system channels;
- sweep global de 0 hardcodes visibles.

### No regresión
- 0 archivos eliminados respecto al ZIP B04 fuente.
- `npm test` PASS.
- build PASS (408 archivos sincronizados).
- Legal Gate PASS.
- Android 4/5 sólo por firma local externa.
