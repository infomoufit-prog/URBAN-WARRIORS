-- ROLLBACK 068 · BLOQUEADO POR PRIVACIDAD.
--
-- 068 elimina una exposición previa: los RPC históricos permitían obtener relaciones
-- confirmadas de otra identidad y los perfiles públicos incluían la lista completa.
-- Restaurar simplemente los GRANT de v045/v052/v053/v065 reabriría esa fuga.
--
-- Si hubiera que volver a un cliente anterior:
-- 1. mantener revocados los RPC históricos inseguros;
-- 2. backportear al cliente anterior app_kombax_relaciones_v068 y perfil_publico_v068;
-- 3. conservar la ausencia de lista/contador público;
-- 4. solo después retirar nombres/versiones que ya no consuma ningún cliente.
do $$
begin
  raise exception 'ROLLBACK_068_BLOCKED_PRIVACY: no restaurar RPC históricos que exponen Relaciones';
end $$;
