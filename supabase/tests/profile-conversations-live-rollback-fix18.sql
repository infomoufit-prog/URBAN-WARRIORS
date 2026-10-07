begin;
insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico)
select '23d246d2-7930-45b9-b09c-0086b9291166',t,'qa-chat-fix18-'||t,'QA '||t
from unnest(array['marca','federacion','profesional','competidor']) t;
do $test$
declare p record; ctx record; n int:=0; denied boolean;
begin
for p in select * from public.perfiles_kombax_directos where slug like 'qa-chat-fix18-%' loop
 if not kombax_ai_ops.org_assist_access_allowed(p.perfil_id,'profile:'||p.id) then raise exception 'OWNER_DENIED %',p.tipo; end if;
 select * into ctx from kombax_ai_ops.resolve_context(p.perfil_id,'profile:'||p.id);
 if ctx.tenant_ref<>'profile:'||p.id then raise exception 'CONTEXT_MIXED';end if;
 if not kombax_ai_ops.migration_access_allowed(p.perfil_id,'profile:'||p.id) then raise exception 'MIGRATION_DENIED';end if;
 if kombax_ai_ops.org_assist_access_allowed('9424403b-44c0-48cc-91f1-80a8114ed375','profile:'||p.id) then raise exception 'FOREIGN_ALLOWED';end if;
 denied:=false;
 begin perform kombax_ai_ops.resolve_context('9424403b-44c0-48cc-91f1-80a8114ed375','profile:'||p.id); exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FOREIGN_FALLBACK';end if;
 insert into kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado) values(p.id,'9424403b-44c0-48cc-91f1-80a8114ed375','editor','activo');
 if not kombax_ai_ops.org_assist_access_allowed('9424403b-44c0-48cc-91f1-80a8114ed375','profile:'||p.id) then raise exception 'EDITOR_DENIED';end if;
 update kombax_perfil_gestores set estado='revocado' where perfil_directo_id=p.id and perfil_id='9424403b-44c0-48cc-91f1-80a8114ed375';
 if kombax_ai_ops.org_assist_access_allowed('9424403b-44c0-48cc-91f1-80a8114ed375','profile:'||p.id) then raise exception 'REVOCATION_IGNORED';end if;
 n:=n+1;
end loop;
if n<>4 then raise exception 'MISSING_FIXTURES';end if;
end $test$;
select jsonb_build_object('types',4,'owner_access',true,'migration_access',true,'explicit_context',true,'foreign_denied_without_fallback',true,'editor_access_and_revocation',true,'rollback',true) as qa;
rollback;
