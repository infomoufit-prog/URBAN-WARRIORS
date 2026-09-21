# R64.4 - Rollback seguro

## Frontend / paquete
Volver al ZIP R64.3 restaura la UI anterior. No desplegar frontend implica que este rollback es local hasta que se autorice publicación.

## Destacar
La migración R64.4 solo actualiza `kombax_commercial.runtime_config_r64.content_promotion`.
Para rollback comercial a R64.3:

```sql
update kombax_commercial.runtime_config_r64
set value='{"7":1500,"15":2400,"30":3500,"max_promoted_events_per_user_day":2,"same_event_frequency_hours":72,"no_consecutive_promotions":true}'::jsonb,
    description='Único servicio Destacar para Events/Showcase con amplificación Social.',
    updated_at=now()
where config_key='content_promotion';
```

## Stripe checkout
La función desplegada es acumulativa: elimina el bloqueo de platform fee y añade `application_fee_amount`. Un rollback de Edge Function debe restaurar la versión 9 únicamente si también se revierte el modelo de platform fee a 0; no debe hacerse de forma aislada.
