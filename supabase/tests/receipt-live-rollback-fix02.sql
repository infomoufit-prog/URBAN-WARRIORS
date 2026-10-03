begin;
do $test$
declare c uuid; s uuid; fee uuid; material uuid; partial_fee uuid; r jsonb;
begin
 select club_id,id into c,s from public.socios order by creado_en,id limit 1;
 if s is null then raise exception 'TEST_STUDENT_REQUIRED';end if;
 insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen)
 values(c,s,date_trunc('month',current_date)::date,'FIX02 TEST FEE','FIX02 TEST FEE',41.25,current_date,'pendiente','cuota') returning id into fee;
 update public.cuotas set estado='pagada' where id=fee;
 insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,origen_id)
 values(c,s,date_trunc('month',current_date)::date,'Material: FIX02 TEST [00000000]','Material: FIX02 TEST',27.50,current_date,'pendiente','material',gen_random_uuid()) returning id into material;
 update public.cuotas set estado='pagada' where id=material;
 insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen)
 values(c,s,date_trunc('month',current_date)::date,'FIX02 TEST PARTIAL','FIX02 TEST PARTIAL',80,current_date,'pendiente','cuota') returning id into partial_fee;
 update public.cuotas set estado='parcialmente_pagada' where id=partial_fee;
 select jsonb_build_object('fee_receipt',count(*) filter(where cuota_id=fee)=1,'material_receipt',count(*) filter(where cuota_id=material and origen='material')=1,'fee_amount',count(*) filter(where cuota_id=fee and importe=41.25)=1,'material_amount',count(*) filter(where cuota_id=material and importe=27.50)=1,'public_material_concept',count(*) filter(where cuota_id=material and concepto='Material: FIX02 TEST' and actividad='Material: FIX02 TEST')=1,'partial_without_final_receipt',count(*) filter(where cuota_id=partial_fee)=0,'two_receipts_only',count(*)=2) into r from public.recibos_cuota where cuota_id in(fee,material,partial_fee);
 perform set_config('kombax.receipt_test_result',r::text,true);
exception when others then perform set_config('kombax.receipt_test_result',jsonb_build_object('ok',false,'error',SQLERRM,'state',SQLSTATE)::text,true);
end $test$;
select current_setting('kombax.receipt_test_result',true)::jsonb as receipt_database_test;
rollback;
