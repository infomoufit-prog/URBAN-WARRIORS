# Supabase Audit · KOMBAX Eventos · build 20.098

## Proyecto
Proyecto principal KOMBAX: `poggsobhtutbuagjiydc`.

## Migración 173 aplicada
`kombax_events_large_format_experience_20098`

Añade de forma aditiva a `kombax_eventos_publicos`:
- dirección/código postal/mapa;
- web oficial;
- URL y ventanas de inscripción;
- precio orientativo de inscripción;
- URL/proveedor/ventanas/precio de tickets;
- streaming;
- aforo;
- información de acceso.

Añade validaciones de:
- HTTPS obligatorio en URLs externas;
- ventanas apertura/cierre coherentes;
- precios y aforo no negativos;
- longitudes acotadas.

Lectores v173:
- `app_kombax_eventos_publicos_v173`
- `app_kombax_evento_publico_detalle_v173`
- `app_kombax_evento_publico_slug_v173`

El discovery incluye teaser Main Event desde Fight Card pública real.

Gateway:
- `app_kombax_eventos_mutate_v173`
- authenticated only;
- llama primero a v171 para conservar aislamiento de workspace.

## Migración 174 aplicada
`kombax_events_large_format_helper_acl_20098`

Los helpers:
- `app_kombax_evento_inscripciones_estado_v173`
- `app_kombax_evento_entradas_estado_v173`

quedan sin EXECUTE directo para `anon` ni `authenticated`; `service_role` conserva EXECUTE. Los lectores públicos v173 continúan disponibles para `anon`/`authenticated`.

## Verificación ACL real
- anon mutation v173: bloqueada.
- authenticated mutation v173: permitida.
- anon direct SELECT `kombax_eventos_publicos`: bloqueado.
- authenticated direct SELECT: bloqueado.
- anon public list/detail/slug v173: permitido.
- helper registration/tickets standalone para anon/auth: bloqueado.

## Aislamiento Urban Warriors
La definición del RPC v171 mantiene dos ramas mutuamente excluyentes:
- con `p_club_id`: solo el perfil Club correspondiente al workspace autenticado;
- sin `p_club_id`: identidades directas.

Por tanto, el perfil Federación QA de la misma cuenta no puede aparecer dentro del contexto Urban Warriors.

Urban Warriors sigue con `events.public.organize = false` hasta post-deploy.

## Advisors
Performance Advisor: no introdujo nuevas foreign keys sin índice en 20.098. Los índices de ventanas pueden aparecer como `unused_index` mientras no existan eventos/tráfico, lo que es esperado.

Security Advisor: los lectores públicos SECURITY DEFINER v173 son intencionales porque la tabla subyacente no se expone directamente. Se redujo la superficie pública retirando EXECUTE directo de los dos helpers internos mediante 174. El baseline histórico del proyecto no se modifica en esta fase.
