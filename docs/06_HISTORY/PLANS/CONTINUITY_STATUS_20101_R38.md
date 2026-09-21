# KOMBAX 20.101 R38 · Continuity Status

R38 sustituye a R37 como base de continuidad una vez verificado el ZIP final.

## Hereda íntegramente
- R32 Profile Matrix.
- R33/R33.1 Federación, licencias y UX transversal.
- R34 migración/preparación histórica, con Migrations ahora separado de Assist.
- R35 Event-Centric Competition Preparation y privacidad de peso.
- R36 conexiones Events + Fighter Discovery.
- R37 Brand Business Hub y opt-in comercial.

## Añade
- KOMBAX Assist como soporte estándar email-first.
- Chat Assist customer-side solo si soporte lo activa.
- KOMBAX Migrations como canal directo separado.
- Chat + subida de documentos dentro del mismo caso de migración.
- Ledger privado y guardrails económicos por plan/caso/período.
- Procesamiento multimodal con vista previa y confirmación humana.
- Hardening de ACL y de índices para la nueva infraestructura R38.

## Reglas de continuidad
- No volver a fusionar Migrations dentro del procedimiento de Assist.
- No permitir autoactivación customer-side de chat estándar Assist.
- No importar datos desde Migrations sin confirmación explícita.
- No exponer modelos internos, tokens ni costes internos al cliente.
- No tocar privacidad de preparación/peso para habilitar estos flujos.
- No incluir `.env`, JKS, `android/keystore.properties` real ni secretos en entregables.
- No desplegar frontend/Netlify ni hacer GitHub push sin autorización expresa.
