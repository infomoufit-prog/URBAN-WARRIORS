# KOMBAX · Auditoría visual y assets aprobados de nuevas capas
**Base:** R81 build 20134 auditada  
**Fecha:** 21/09/2026  
**Estado:** assets de KOMBAX Guías, KOMBAX Consultoría y KOMBAX Formación APROBADOS

## 1. Referencia visual auditada en el ZIP maestro
La referencia de diseño no parte de una estética externa. Se ha contrastado con los assets ya existentes en la base acumulativa, especialmente:

- `web/assets/brand-heroes/hero-social.webp`
- `web/assets/brand-heroes/hero-showcase.webp`
- `web/assets/brand-heroes/hero-events.webp`
- shell y superficies dark-premium del frontend actual.

El sistema comparte negro/gris profundo, iluminación cinematográfica, atmósfera de recinto o gimnasio, objetos propios de deportes de contacto, profundidad visual y acentos por ecosistema. Social utiliza rojo/naranja; Showcase, amarillo/dorado; Events, cian/neón. El rojo KOMBAX actúa como firma transversal.

## 2. Criterio corregido y definitivo
Se descarta la propuesta anterior basada en reuniones o personas genéricas. Las tres nuevas capas deben sentirse como productos comerciales del mismo universo visual que Social, Showcase y Events.

Reglas aprobadas:

1. **No utilizar personas de stock o escenas humanas gratuitas** como concepto principal.
2. Priorizar **ring/cage, guantes, sacos, material técnico, planos, tablet, documentación, métricas, certificación y objetos de gestión** vinculados al deporte de contacto.
3. El **nombre/símbolo KOMBAX debe estar reconocible** en el asset aprobado, sin depender del texto generado dentro de la imagen para transmitir información jurídica o funcional.
4. Los títulos, precios, estados, CTA y explicaciones reales serán siempre HTML/UI o texto PDF accesible; nunca se tomará como fuente de verdad el texto incrustado en una imagen generada.
5. Mantener espacio negativo suficiente para copy y CTA superpuestos.
6. Conservar variantes horizontal, 4:3 y 1:1 para desktop, tablet y tarjetas.
7. KOMBAX Formación se prepara visualmente, pero **permanece oculta por defecto** hasta que exista entitlement para la federación/colegio profesional piloto.

## 3. KOMBAX Guías
**Rol:** normativa, procedimientos, recursos, checklists y puerta de acceso a consulta específica.

**Dirección aprobada:** recinto/gimnasio oscuro, material de combate KOMBAX, tablet y documentación técnica. Debe comunicar conocimiento operativo aplicado al mundo real, no una biblioteca escolar ni un despacho jurídico.

Assets aprobados:

- `artifacts/assets/kombax-guides-hero.webp` - horizontal.
- `artifacts/assets/kombax-guides-tablet.webp` - 4:3.
- `artifacts/assets/kombax-guides-card.webp` - 1:1.
- originales: `artifacts/assets/sources-approved/kombax-guides-*.png`.

## 4. KOMBAX Consultoría
**Rol:** revisión de situaciones concretas que no pueden resolverse de forma responsable con una guía genérica: territorio, recinto, federación, documentación, permisos, menores, participantes extranjeros, venta de entradas u otros condicionantes.

**Dirección aprobada:** escenario de deporte de contacto + herramientas de estrategia, análisis y documentación; sin reunión de stock ni imagen de “abogado genérico”. Debe sentirse como una capa premium de acompañamiento operativo KOMBAX.

Assets aprobados:

- `artifacts/assets/kombax-consulting-hero.webp` - horizontal.
- `artifacts/assets/kombax-consulting-tablet.webp` - 4:3.
- `artifacts/assets/kombax-consulting-card.webp` - 1:1.
- originales: `artifacts/assets/sources-approved/kombax-consulting-*.png`.

## 5. KOMBAX Formación
**Rol:** módulo privado por entitlement para el piloto con federación/colegio profesional: cursos, práctica, módulos formativos, recursos ISO que aporte la entidad, licencias formativas, evaluaciones, seguimiento, acreditaciones/certificados y formación práctica en el uso de KOMBAX como plataforma de gestión.

**Dirección aprobada:** equipamiento de entrenamiento, interfaz de aprendizaje, documentación/certificación y ambiente de gimnasio/recinto. Sin alumnado o formadores genéricos como reclamo principal.

Assets aprobados:

- `artifacts/assets/kombax-training-hero.webp` - horizontal.
- `artifacts/assets/kombax-training-tablet.webp` - 4:3.
- `artifacts/assets/kombax-training-card.webp` - 1:1.
- originales: `artifacts/assets/sources-approved/kombax-training-*.png`.

## 6. Capa de Consultoría preparada, sin precios inventados
El bloque previo solo define el catálogo y la información que deberá poder mostrar la futura capa. No activa venta ni asigna importes.

Servicios iniciales de referencia:

- creación/estructura de club o asociación deportiva;
- revisión de evento o interclub antes de publicación;
- revisión documental del organizador;
- licencias y encaje federativo;
- menores, protección de datos e imagen;
- ticketing, condiciones de venta y cancelación;
- participantes extranjeros;
- patrocinio y operativa comercial;
- digitalización y configuración operativa con KOMBAX.

El futuro catálogo soportará `fixed`, `from` o `quote`, pero `price_minor` seguirá vacío mientras KOMBAX no haya validado comercialmente el precio. Cuando el asunto requiera asesoramiento jurídico, fiscal, laboral o técnico reservado a un profesional habilitado, KOMBAX Consultoría deberá identificarlo y derivarlo, no simular ese dictamen.

## 7. Estado de implementación de este bloque
Los assets están **preparados y aprobados**, pero aún no se han añadido rutas, menús, permisos, tablas, entitlements ni UI funcional a producción. Su integración pertenece a las fases funcionales posteriores del Plan Maestro.
