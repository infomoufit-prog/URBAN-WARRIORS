-- ROLLBACK 067 · BLOQUEADO POR SEGURIDAD/PRIVACIDAD.
--
-- 067 introduce borrado por participante de Contacto KOMBAX mediante:
--   eliminado_remitente_en / eliminado_destinatario_en.
-- Un cliente 20040 usa las RPC v065, que desconocen esos tombstones. Revertir
-- simplemente a v065 podría hacer reaparecer en la bandeja una conversación que
-- el usuario ya eliminó. Por ello NO existe un rollback automático destructivo.
--
-- Estrategia segura si alguna vez hay que revertir:
-- 1. Mantener las dos columnas de tombstone y sus datos.
-- 2. Backportear el filtro de tombstones a las RPC de lectura de la versión destino.
-- 3. Deshabilitar en el frontend las operaciones nuevas de eliminar Social/Showcase.
-- 4. Solo entonces retirar los gateways v067 que ya no consuma ningún cliente.
-- 5. Nunca borrar los tombstones existentes sin una migración de privacidad explícita.
--
-- Este guard evita ejecutar por accidente un rollback que reexponga contenido.
do $$
begin
  raise exception 'ROLLBACK_067_BLOCKED_PRIVACY: requiere rollback coordinado de cliente + RPC preservando tombstones';
end $$;
