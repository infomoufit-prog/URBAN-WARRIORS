# KOMBAX RC13 build 20.091 · Fase 2 · Plan previo de implementación

## Objetivo
Convertir la ficha pública de KOMBAX Eventos en un ecosistema institucional multiidentidad, conservando Mi Club > Eventos como dominio privado separado.

## Orden antes de código
1. Partir solo de la build completa 20.090.
2. Auditar 159 y verificar que ninguna nueva consulta usa `eventos_competicion`.
3. Añadir relaciones públicas de organizadores, coorganizadores, avales, colaboradores y patrocinadores.
4. Abrir escritura únicamente por `events.public.organize`, sin concederla automáticamente a `club_saas`.
5. Activar Federación institucional; dejar Club Premium/Profesional Pro/Competidor Pro preparados mediante entitlement.
6. Añadir invitación/aceptación para gestión compartida.
7. Enlazar identidades KOMBAX a sus perfiles públicos y permitir entidades externas no gestoras.
8. Crear UX visual y motion para logos/partners sin API externa.
9. Ejecutar regresión 20.090 + Fase 2 + build determinista.

## Fuera de alcance
Inscripciones, participantes, combates, Fight Cards con datos reales, Social sharing, QR, live y highlights.

## Gate de seguridad
Ningún evento interno de Mi Club se copia, consulta o publica desde esta capa. Un coorganizador no obtiene permisos hasta aceptar y disponer del entitlement de organización.
