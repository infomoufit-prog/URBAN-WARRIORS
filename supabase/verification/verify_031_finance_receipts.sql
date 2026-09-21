-- Solo lectura. Resultado requerido: todas las filas OK.
select control,estado,detalle from public.app_finance_receipts_audit_v031();

select
  q.origen,
  count(*) filter(where q.estado='pagada') cargos_pagados,
  count(r.id) filter(where q.estado='pagada') recibos_emitidos,
  count(*) filter(where q.estado='pagada' and r.id is null) pagados_sin_recibo
from public.cuotas q
left join public.recibos_cuota r on r.club_id=q.club_id and r.cuota_id=q.id
group by q.origen
order by q.origen;
