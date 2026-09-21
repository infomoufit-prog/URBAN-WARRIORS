select * from (values
 ('public_events_table',to_regclass('public.kombax_eventos_publicos') is not null),
 ('public_list_rpc',to_regprocedure('public.app_kombax_eventos_publicos_v159(text,text,text,integer)') is not null),
 ('public_detail_rpc',to_regprocedure('public.app_kombax_evento_publico_detalle_v159(uuid)') is not null),
 ('legacy_internal_events_intact',to_regclass('public.eventos_competicion') is not null),
 ('no_authenticated_table_select',not has_table_privilege('authenticated','public.kombax_eventos_publicos','SELECT'))
) as v(check_name,ok);
