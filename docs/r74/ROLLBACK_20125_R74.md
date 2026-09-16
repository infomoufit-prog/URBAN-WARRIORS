# Rollback / recovery notes · R74

R74 es acumulativa sobre R73. Para rollback de aplicación, conservar el ZIP R73 original como artefacto previo y restaurar sus assets Web/Android. No debe ejecutarse un rollback destructivo de base de datos sin respaldo.

Las migraciones 260–263 son aditivas/hardening salvo el cambio controlado de la restricción 1:1 de conexiones Events. Dado que al momento de la auditoría no existían conexiones Events reales, no hubo datos existentes que transformar. Ante recuperación, preferir roll-forward con una migración compensatoria antes que eliminar tablas/columnas R74.

No revertir Stripe, tickets, QR ni productos Showcase: R74 no los modifica.
