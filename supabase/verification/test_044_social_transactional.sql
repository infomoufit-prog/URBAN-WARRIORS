begin;
do $$ begin
  if not exists(select 1 from pg_trigger where tgrelid='public.kombax_social_comentarios'::regclass and tgname='kombax_social_comment_guard_v044' and not tgisinternal) then raise exception '044 one-level guard missing';end if;
  if not exists(select 1 from pg_constraint where conrelid='public.kombax_social_publicaciones'::regclass and conname='kombax_social_publicaciones_comentarios_estado_check') then raise exception '044 comment mode missing';end if;
end $$;
rollback;
