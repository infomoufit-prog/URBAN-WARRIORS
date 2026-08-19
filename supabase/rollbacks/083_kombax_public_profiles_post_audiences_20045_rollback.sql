-- ROLLBACK 083 · BLOQUEADO POR PRIVACIDAD.
--
-- 083 introduce audiencias restringidas y cierra RPC históricas que las ignorarían.
-- Reabrir las RPC antiguas o retirar las columnas de audiencia podría exponer contenido
-- de Club/Federación como público. El rollback seguro debe ser un forward-fix que conserve
-- app_kombax_social_puede_ver_publicacion_v083 y la privacidad de cada publicación.
do $$
begin
  raise exception 'ROLLBACK_083_BLOCKED_PRIVACY: no restaurar rutas que omiten audiencias de publicaciones';
end $$;
