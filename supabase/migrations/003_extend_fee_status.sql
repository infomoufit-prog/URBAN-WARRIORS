-- URBAN WARRIORS · FASE 1.2
-- Esta migración se separa para que los nuevos valores enum queden confirmados
-- antes de ser utilizados por la siguiente migración.
alter type public.estado_cuota add value if not exists 'pendiente_validacion';
alter type public.estado_cuota add value if not exists 'aplazada';
