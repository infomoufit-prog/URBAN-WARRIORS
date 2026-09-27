# KOMBAX R102 · Insignias visibles

## Regla de producto

- Miembro mantiene un perfil público y puede mostrar la afiliación confirmada al club. Esa afiliación no le concede una insignia de competidor.
- Competidor obtiene una insignia propia cuando su identidad competitiva está verificada y activa. Su ficha pública lleva un sello y un marco distintivos; sus apariciones en Social llevan un indicador compacto.
- Club, Marca y Federación reciben la insignia de su tipo solo con identidad válida y una suscripción activa cuyo pago esté confirmado. Una prueba, el beneficio de piloto o la activación manual del plan sin cobro no constituyen confirmación de pago.
- El estado de pago se reconoce mediante `proveedor` `stripe`, `stripe_billing` o `kombax_manual_paid`, con `referencia_externa` no vacía y fechas vigentes. El último valor queda reservado para un cobro manual confirmado; la activación administrativa habitual (`kombax_manual_admin`) no lo utiliza.

## Aplicación

- Migración `274_kombax_paid_organization_badges_r102.sql`: calcula la elegibilidad, protege `kombax_social_perfiles.verificado`, actualiza insignias tras cambios de suscripción y corrige perfiles existentes.
- La interfaz comparte una sola regla visual para la ficha pública y Social. Las cuentas gratuitas y los miembros carecen de sello oficial; la afiliación al club conserva su distintivo independiente.
- Los cuatro clubes piloto mantienen sus beneficios funcionales sin adquirir una insignia que sugiera un pago realizado.

## Verificación

- Base de datos posterior a la migración: dos clubes sin insignia, dos miembros sin insignia, una federación con servicio manual sin insignia y un competidor verificado con insignia.
- `scripts/test-kombax-verified-competitor-r102.mjs` cubre la separación de tipos y la presencia de los elementos visuales.
