# R110 · Alta Club Piloto y continuidad como Club Fundador

## Objetivo
Habilitar una puerta temporal de alta para un máximo de cuatro Clubes piloto sin exigir al usuario el flujo documental de verificación, manteniendo intacta la arquitectura oficial para las altas normales.

## Regla de continuidad
El resultado del alta piloto es un Club KOMBAX real y permanente. El 15/11/2026 no se elimina, suspende ni vuelve a verificar. Solo se cierra la puerta temporal de alta. El Club conserva el mismo identificador y todos sus datos y relaciones. Queda marcado como fundador elegible.

## Seguridad de la ventana
Owner genera códigos de acceso de un solo uso. En base solo se almacena SHA-256 del código; el valor en claro se muestra una vez al generarlo. Un código puede ligarse a un email. Los códigos pendientes reservan plaza y la suma de Clubes ya inscritos + códigos pendientes no puede superar 4.

## Validación automática del programa
Se exige Auth, email confirmado, tipo de cuenta Club y datos básicos operativos (nombre, ubicación, disciplina, teléfono y declaración). No se solicita CIF/documento/evidencia. La aplicación se registra internamente como `verified`, con fuente `pilot_program_r110` y `document_verification_required=false`. Se reutiliza el núcleo certificado de provisión de Club.

## Premium y fundador
Durante el piloto se concede `PILOT_ACCESS` con plan Premium sin Stripe Billing. La condición `founder_eligible` persiste. El beneficio fundador concreto posterior no se inventa ni se uniformiza: Owner conserva las acciones para asignar el programa aprobado que corresponda a cada Club. R102 no cambia: un beneficio piloto no finge una suscripción pagada ni su insignia.

## Miembros
Se reutilizan R58/R59: miembros existentes, invitaciones, claims de cuentas existentes, deduplicación y tutoría. No se crea una identidad paralela de Miembro.
