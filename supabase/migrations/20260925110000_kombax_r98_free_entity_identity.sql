-- WORK phase 1: an entity may request a reviewed public identity without a paid plan.
-- Existing paid-plan requests and verification checks remain separate.
begin;

create or replace function public.app_kombax_club_plan_application_guard_r642()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
        v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
begin
 if new.tipo<>'club' then return new; end if;
 if v_plan<>'' and v_plan not in ('club','premium','enterprise') then raise exception 'KOMBAX_CLUB_PLAN_INVALID'; end if;
 if v_plan<>'' and v_cycle not in ('monthly','annual') then raise exception 'KOMBAX_CLUB_BILLING_CYCLE_INVALID'; end if;
 if v_plan<>'' then
  new.datos_verificacion:=jsonb_set(coalesce(new.datos_verificacion,'{}'::jsonb),'{plan_codigo}',to_jsonb(v_plan),true);
  new.datos_verificacion:=jsonb_set(new.datos_verificacion,'{billing_cycle}',to_jsonb(v_cycle),true);
 else
  new.datos_verificacion:=coalesce(new.datos_verificacion,'{}'::jsonb)-'plan_codigo'-'billing_cycle';
 end if;
 return new;
end $$;
revoke all on function public.app_kombax_club_plan_application_guard_r642() from public,anon,authenticated;

create or replace function public.app_kombax_direct_commercial_plan_application_guard_r66()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
        v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
begin
 if new.tipo not in ('marca','federacion') then return new; end if;
 if new.tipo='marca' and v_plan<>'' and v_plan not in ('brand_start','brand_growth','brand_enterprise') then raise exception 'KOMBAX_BRAND_PLAN_INVALID'; end if;
 if new.tipo='federacion' and v_plan<>'' and v_plan not in ('federation','federation_partner') then raise exception 'KOMBAX_FEDERATION_PLAN_INVALID'; end if;
 if v_plan<>'' and v_cycle not in ('monthly','annual') then raise exception 'KOMBAX_COMMERCIAL_BILLING_CYCLE_INVALID'; end if;
 if v_plan<>'' then
  new.datos_verificacion:=jsonb_set(coalesce(new.datos_verificacion,'{}'::jsonb),'{plan_codigo}',to_jsonb(v_plan),true);
  new.datos_verificacion:=jsonb_set(new.datos_verificacion,'{billing_cycle}',to_jsonb(v_cycle),true);
 else
  new.datos_verificacion:=coalesce(new.datos_verificacion,'{}'::jsonb)-'plan_codigo'-'billing_cycle';
 end if;
 return new;
end $$;
revoke all on function public.app_kombax_direct_commercial_plan_application_guard_r66() from public,anon,authenticated;

commit;
