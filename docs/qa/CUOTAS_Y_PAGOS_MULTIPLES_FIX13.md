# Comprobación de varias cuotas y pagos · FIX13

Se leyeron las funciones y restricciones actuales de Supabase. La relación cuotas/pagos permite varias cuotas por alumno y varios pagos por cuota. Las funciones reales se ejecutaron en una base aislada: 15 casos aprobados, sin modificar saldos ni cobrar a usuarios reales.

Caso positivo: un alumno tiene cuotas Karate 50 €, Kickboxing 70 € y Licencia 15 € en el mismo periodo. Karate se liquida con pagos de 20 y 30; Kickboxing con 10, 20 y 40. Licencia sigue pendiente. Revalidar un pago no aumenta el total; el sobrepago se rechaza. Un usuario sin vínculo no puede comunicar pagos ni validarlos.

El asistente «Nuevo cargo» del panel avanzado permite crear cuotas individuales y otros cargos. La función de generación mensual antigua utiliza una tarifa principal por alumno; añadir disciplinas o grupos no genera automáticamente una cuota por cada grupo. Para conceptos adicionales se crean cargos o reglas explícitas; no se promete facturación automática derivada de cada matrícula.

Un alumno o tutor solo puede tener un justificante pendiente de validar por cuota: para comunicar el siguiente pago parcial debe revisarse el anterior. Puede haber pagos pendientes de cuotas distintas. Este control evita solicitudes duplicadas y se conserva.

Se verificó por lectura en producción que el panel avanzado está activado en CLUB MOUFIT DEMO y QA-CLUB-001 · KOMBAX QA TEST; está desactivado en Urban Warriors y Sant Pedro urban warrios. Tras la autorización del usuario, se aplicó la migración 20261005173729_club_finance_panel_all_pilot_premium_fix13.sql: panel y cargos manuales para todos los clubes existentes y futuros; informes Premium para los registrados como piloto. Read-back: cuatro clubes activos con panel habilitado; los dos piloto con informes activos; recurrencia y ejecución automática desactivadas en los cuatro. Las activaciones anteriores de informes en Demo/QA se conservaron. Ocho pruebas adicionales de la migración comprueban clubes existentes, altas futuras, registro piloto y conservación de los cierres de cobro automático. No se cambiaron cuotas, pagos ni suscripciones. El botón de nuevo cargo se limita a dirección/secretaría/economía, coherente con la autorización actual del servidor.

Alcance: funciones reales de creación manual de cargos y comunicación/validación de pagos, con tablas y permisos de prueba. No es una prueba completa de las capas de mutación en producción ni una prueba de Stripe. Stripe/SEPA y sus cobros efectivos no se ejecutaron. No se confirma un cargo bancario múltiple o una remesa por extender el resultado de estas pruebas.

También pasaron cuatro comprobaciones Chrome del asistente: dos cargos de 50/70 para un mismo alumno, conceptos separados y botón coherente con el rol. Transporte simulado; no se crearon cuotas reales.
