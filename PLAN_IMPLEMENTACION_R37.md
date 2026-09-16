# KOMBAX 20.101 R37 · Plan de implementación · Brand Business Hub

## Objetivo
Evolucionar el perfil **Marca** desde una identidad pública ligera hacia un **Business Hub especializado en deportes de contacto**, sin crear identidades duplicadas y conservando las fronteras de privacidad de Club, Competidor, Profesional, Events y el seguimiento privado de peso R35/R36.

## Principios permanentes
1. Una Marca conserva una sola identidad KOMBAX.
2. Social, Showcase, Campañas, Colaboraciones, Patrocinios, Events, Equipo y Analítica son capacidades de esa identidad.
3. Ser público/contactable no equivale a aceptar propuestas comerciales.
4. Competidor, Club y Evento deben activar expresamente su disponibilidad comercial.
5. Una colaboración no concede acceso a pesos privados, preparación, documentos, alumnos, finanzas ni datos administrativos.
6. Las oportunidades de combate y las oportunidades comerciales son autorizaciones independientes.
7. R37 no convierte las propuestas en contratos jurídicos ni procesa pagos.

## Alcance funcional
### Mi Marca
- Business Hub / resumen operativo.
- Configuración de sector, territorios, disciplinas y posicionamiento comercial.
- Campañas privadas y abiertas.
- Modelos: embajadores, competidores, clubes, eventos, lanzamiento, contenido y otras colaboraciones.
- Descubrimiento de competidores, clubes y eventos con opt-in explícito.
- CRM de propuestas: pendiente, interesado, evaluación, aceptada, rechazada, retirada y finalizada.
- Patrocinios de KOMBAX Events.
- Equipo de Marca con roles comerciales sobre gestores ya autorizados.
- Analítica operacional de campañas y propuestas.

### Perfil público Marca
- Presentación comercial pública controlada.
- Sector, territorios y disciplinas publicables.
- Indicador voluntario “abierta a colaboraciones”.
- Campañas abiertas activas.
- Showcase y actividad Social ya existentes.
- Nunca expone CRM, equipo interno ni datos privados de colaboradores.

### Competidor / Profesional
- Centro “Colaboraciones con marcas”.
- Opt-in separado de Fighter Discovery.
- Control de localización comercial, recepción de propuestas y vía de contacto.
- Bandeja para aceptar/rechazar propuestas.
- Posibilidad de mostrar interés en campañas abiertas.

### Club
- Nueva configuración “Colaboraciones y patrocinios”.
- Un Club no es descubrible comercialmente por tener Social activo: debe activar `discoverable_by_brands` e `inbound_enabled`.
- Define categorías y nota de colaboración.

### KOMBAX Events
- Nueva configuración “Patrocinios · Marcas”.
- Publicar un evento no lo introduce automáticamente en Brand Discovery.
- El organizador activa expresamente `sponsorship_open` e `inbound_enabled`.
- Define tipos de patrocinio buscados y nota para Marcas.

## Seguridad y privacidad
- Tablas de negocio con RLS activa y acceso directo revocado.
- Escritura/lectura privada por RPC autenticada y autorizada.
- Proyección pública de Marca separada y limitada.
- Trigger de backend impide insertar propuestas a Club/Event/Competidor sin el opt-in correspondiente, incluso si se intenta saltar el buscador.
- Las RPC R37 no consultan `kombax_weight_measurements_v216` ni `kombax_competition_preparations_v216`.

## Fuera de alcance R37
- Firma contractual/e-signature.
- Pasarela de pagos o liquidación de patrocinios.
- Compra de anuncios/campañas promocionadas pagadas.
- Ranking comercial basado en datos privados.
- Marketplace abierto de menores.
- Creación de datos ficticios de Marca en producción.

## QA de cierre
- Prueba específica R37.
- Regresión histórica completa.
- Build web/dist/Android.
- Paridad SHA-256 web = dist = Android.
- Preflight Android sin incluir JKS.
- Auditoría live de RLS/RPC/anon/search_path.
- Empaquetado limpio sin secretos, keystore ni `.env`.
