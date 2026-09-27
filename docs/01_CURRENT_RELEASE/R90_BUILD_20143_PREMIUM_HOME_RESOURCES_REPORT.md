# KOMBAX R90 · build 20143 · Premium Home + Resources

## Objetivo
R90 parte exclusivamente de la base certificada R89 build 20142 y mejora la experiencia de entrada al piloto sin alterar la arquitectura de datos cerrada en R89.

## Implementado
- Home post-login premium utilizando assets oficiales existentes de KOMBAX.
- Cuatro superficies principales visuales: Social, Showcase, Events y Mi espacio.
- Zona visual Recursos KOMBAX para Guías, Consultoría y Formación.
- Accesos persistentes a KOMBAX Guías y KOMBAX Consultoría dentro de la sidebar privada, separados de la navegación principal.
- Accesos adicionales desde el hub de Mi Club.
- Hero premium propio para Guías y Consultoría.
- Guías con acciones explícitas Abrir PDF y Descargar PDF.
- Resolución de URLs mediante `document.baseURI` para navegador/PWA.
- Android: puente nativo para abrir PDFs incluidos en assets y guardarlos mediante selector del sistema.
- Android: FileProvider privado y limitado a `shared-pdf/`.
- i18n completo ES/EN/FR/PT/IT/DE/TH/FIL de la nueva superficie.

## PDFs
El runtime-index conserva 53 entradas de catálogo y el paquete contiene 56 archivos PDF físicos bajo `assets/guides/` (incluidos dossieres maestros). El gate R90 valida existencia y cabecera `%PDF-` de cada PDF indexado.

## QA
- Gate R90: 35/35 PASS.
- Regresión acumulativa completa `npm test`: PASS.
- `npm run release:build`: PASS.
- Legal gate: PASS.
- i18n: 1614 claves master, 1099 referencias activas, 8 idiomas al 100 %, 0 warnings.
- Runtime copy audit: 4653/4653, 0 unresolved.
- Full product i18n audit: 4798 candidatos, 0 unresolved.
- Paridad build: 556 archivos `web = dist = Android`.
- Android preflight: 4/5; únicamente firma local pendiente por diseño.

## Supabase
R90 no añade migraciones. Se conserva el historial acumulativo hasta R89 y el endpoint `health` se actualiza al build 20143. No se ejecutaron cobros reales ni cambios en la lógica de Stripe durante esta release.

## Limitación de compilación Android en el entorno de certificación
La firma real y el JKS no se incluyen en la base. Si Gradle 8.11.1 no está disponible en caché, este entorno puede no resolver `services.gradle.org`; por tanto el AAB firmado se genera en el ordenador local con Android Studio y la clave de subida.

## Base de continuidad
R90 build 20143 sustituye a R89 como única base acumulativa para el siguiente cambio.
