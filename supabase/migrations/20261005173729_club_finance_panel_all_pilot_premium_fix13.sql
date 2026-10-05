-- Authorized rollout: manual finance for all clubs; reports for registered pilots.
-- Does not generate fees, payments, subscriptions, or enable automatic collection.
create or replace function private.club_finance_seed_fix13()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_club uuid;v_pilot boolean;
begin
 if tg_table_schema='public' and tg_table_name='clubes' then
  v_club:=new.id;
  v_pilot:=exists(select 1 from kombax_commercial.pilot_entities_r97 where subject_type='club' and subject_id=v_club);
 else
  if new.subject_type<>'club' then return new;end if;
  v_club:=new.subject_id;v_pilot:=true;
  if not exists(select 1 from public.clubes where id=v_club) then return new;end if;
 end if;
 insert into public.config_club(club_id,clave,valor,descripcion)
 values(v_club,'finance_v2_enabled','true'::jsonb,'Panel y cargos manuales'),
       (v_club,'finance_dashboard_v2_enabled','true'::jsonb,'Panel financiero del club')
 on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now();
 insert into public.config_club(club_id,clave,valor,descripcion)
 values(v_club,'finance_reports_enabled',to_jsonb(v_pilot),'Informes Premium para clubes piloto')
 on conflict(club_id,clave) do nothing;
 if v_pilot then
  update public.config_club set valor='true'::jsonb,actualizado_en=now()
  where club_id=v_club and clave='finance_reports_enabled';
 end if;
 return new;
end $$;
revoke all on function private.club_finance_seed_fix13() from public,anon,authenticated;
drop trigger if exists zz_club_finance_seed_fix13 on public.clubes;
create trigger zz_club_finance_seed_fix13 after insert on public.clubes
 for each row execute function private.club_finance_seed_fix13();
drop trigger if exists club_pilot_finance_seed_fix13 on kombax_commercial.pilot_entities_r97;
create trigger club_pilot_finance_seed_fix13 after insert or update of subject_type,subject_id on kombax_commercial.pilot_entities_r97
 for each row execute function private.club_finance_seed_fix13();
insert into public.config_club(club_id,clave,valor,descripcion)
select c.id,k.clave,'true'::jsonb,k.descripcion from public.clubes c
cross join(values('finance_v2_enabled','Panel y cargos manuales'),('finance_dashboard_v2_enabled','Panel financiero del club')) k(clave,descripcion)
on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now();
insert into public.config_club(club_id,clave,valor,descripcion)
select c.id,'finance_reports_enabled','true'::jsonb,'Informes Premium para clubes piloto'
from public.clubes c join kombax_commercial.pilot_entities_r97 p on p.subject_type='club' and p.subject_id=c.id
on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now();
