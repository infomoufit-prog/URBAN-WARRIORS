# KOMBAX · Child Safety Response Runbook · build 20071

Estado: OPERATIVO PARA PILOTO CONTROLADO · contacto humano y canal público designados.

## 1. Objetivo
Establecer una respuesta trazable, de mínimo acceso y orientada a proteger al menor ante denuncias o indicios de explotación o abuso sexual infantil (EASI/CSAE), material de abuso sexual infantil (CSAM), grooming, sextorsión, trata, sexualización de menores, amenazas o intentos de obtención de datos de localización.

## 2. Principios
1. Prioridad a la seguridad de la persona menor de edad.
2. No descargar, reenviar, duplicar ni reutilizar material potencialmente ilícito salvo cuando sea estrictamente necesario para un proceso legal autorizado.
3. Acceso interno de mínimo privilegio: Moderación recibe únicamente la evidencia asociada al objeto denunciado; no existe acceso general a conversaciones privadas.
4. Preservar metadatos y trazabilidad técnica necesarios sin ampliar innecesariamente la exposición del contenido.
5. Escalado humano obligatorio en casos de seguridad infantil de alta gravedad.
6. No sustituir a las autoridades: cuando exista obligación legal o riesgo inmediato se activa el canal competente.

## 3. Clasificación interna
- **CS-1 Crítica:** riesgo inmediato para un menor, CSAM aparente, grooming activo, sextorsión, amenaza creíble, trata o solicitud sexual dirigida a menor.
- **CS-2 Alta:** sexualización, contacto insistente de adulto hacia menor, solicitud de datos de localización/contacto, conducta de preparación o patrón de acoso.
- **CS-3 Moderada:** contenido inapropiado relacionado con menores sin riesgo inmediato, lenguaje hostil o conducta que requiere revisión contextual.
- **CS-4 Informativa:** reporte sin evidencia suficiente o fuera de alcance, conservando trazabilidad de la decisión.

## 4. Flujo de respuesta
### CS-1
1. Marcar el reporte como escalado y restringir/ocultar el contenido cuando resulte necesario para la protección.
2. Bloquear nuevas interacciones del actor denunciado cuando el mecanismo disponible lo permita y la evidencia lo justifique.
3. Escalar inmediatamente al Responsable de Seguridad Infantil de KOMBAX.
4. Preservar solo los identificadores, timestamps, actor IDs, objeto denunciado y evidencia mínima ya capturada por el flujo de reporte.
5. Determinar y ejecutar, con revisión humana, la comunicación exigible a la autoridad u organismo competente cuando se confirme CSAM o concurra una obligación legal; registrar la autoridad/canal utilizado sin copiar innecesariamente el material.
6. Documentar decisión, acciones, responsable y cierre.

### CS-2
1. Restringir preventivamente el contenido o interacción cuando sea proporcionado.
2. Revisar evidencia mínima y antecedentes de reportes relacionados.
3. Escalar al Responsable de Seguridad Infantil.
4. Aplicar advertencia, suspensión o bloqueo según el riesgo.
5. Documentar la resolución.

### CS-3 / CS-4
1. Revisar la evidencia proporcionada por el reporte.
2. Resolver como permitido, advertido, oculto, suspendido o escalado.
3. Registrar motivo y decisión.

## 5. Datos a los que puede acceder cada rol
- **Usuario:** puede denunciar y bloquear.
- **Moderador:** cola de reportes y evidencia limitada al objeto denunciado; sin Finanzas, documentos privados, administración Owner ni navegación global de chats.
- **Verificador:** documentación profesional estrictamente necesaria para verificaciones; no moderación general ni chats.
- **Owner:** administración privilegiada temporal y auditada; no se utiliza como sustituto de Moderación ordinaria.
- **Responsable de Seguridad Infantil:** función humana designada para escalados CS-1/CS-2 y coordinación legal/autoridades cuando proceda.

## 6. Evidencia
KOMBAX debe evitar ampliar la copia de material sensible. La evidencia técnica preferente es:
- report_id / message_id / publication_id / profile_id;
- actor IDs internos;
- fecha y hora;
- motivo seleccionado y detalle del denunciante;
- snapshot mínimo ya generado por el sistema para el objeto denunciado;
- decisiones y acciones tomadas.

No se debe crear una biblioteca paralela de material denunciado ni exportar contenido sensible a herramientas personales.

## 7. Comunicación con usuarios
- No prometer resultados legales ni revelar información interna de otras personas.
- Cuando una denuncia sea procesada, comunicar únicamente el estado o la acción que sea apropiado compartir.
- En riesgo inmediato, indicar que se contacte con los servicios de emergencia o autoridades competentes de la jurisdicción del usuario.

## 8. Contactos operativos
- Responsable de Seguridad Infantil: BRYAN RIVERA GREY
- Email público de seguridad infantil: childsafety@kombax.es
- Responsable/Owner de plataforma: BRYAN RIVERA GREY
- Canal de seguridad general: seguridad@kombax.es
- El responsable de Seguridad Infantil mantiene capacidad de respuesta a solicitudes de Google Play sobre Child Safety/CSAM y puede coordinar medidas y comunicaciones externas.

## 9. Revisión
Revisar este runbook al menos en cada release que modifique Social, moderación, mensajería, edad mínima, autorización adulta o flujos de denuncia.

Versión 1.0 · build 20071 · 23/08/2026.
