# KOMBAX RC13 build 20078 · Presentación funcional pública

## Objetivo

Ampliar la portada pública de KOMBAX sin alterar el flujo principal de acceso. La nueva sección aparece debajo del gateway actual y explica de forma breve qué aporta la plataforma a cada tipo de perfil.

## Implementación

- **Clubes primero** y con la tarjeta de mayor jerarquía visual.
- Tarjetas específicas para **Federaciones**, **Competidores** y **Marcas**.
- Cada tarjeta explica qué representa el perfil, qué funciones aporta y qué capacidades están todavía en evolución.
- Iconografía reutilizada del sistema visual KOMBAX (`featureIcon`).
- Diseño responsive premium en escritorio y móvil, con reducción de movimiento accesible.
- Acciones conectadas a los accesos existentes del gateway; no se crea una navegación paralela.
- Mensaje público actualizado para incluir explícitamente **deportes de contacto y artes marciales**.
- Franja de disciplinas: Boxeo, Kickboxing, Muay Thai, MMA, Karate, Judo, Jiu-Jitsu, Taekwondo, Grappling, Lucha, Sambo y más.

## Alcance técnico

- Build web: **20078**.
- Android `versionCode`: **20078**.
- `web`, `dist` y assets Android incluyen la misma sección pública.
- Se añade `test-kombax-20078-public-product-overview.mjs` a la suite.
- No hay cambios de Supabase, esquema, RLS, endpoints o permisos.
- No se ha realizado deploy de producción desde esta implementación.

## Criterio de salida

Antes de fusionar a `main` y disparar el deploy final, ejecutar la suite completa y el build del repositorio en un entorno Node compatible y revisar visualmente la portada en escritorio y móvil.
