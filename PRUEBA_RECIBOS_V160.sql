select jsonb_pretty(
  public.app_diagnostico_recibos_v160(
    '11111111-1111-4111-8111-111111111111'::uuid
  )
) as resultado;
