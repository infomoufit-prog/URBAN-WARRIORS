-- Supporting indexes for the private Meta integration; no permission changes.
create index if not exists meta_connections_connected_by_fix20 on kombax_meta.connections(connected_by);
create index if not exists meta_flows_social_fix20 on kombax_meta.flows(social_id);
create index if not exists meta_publications_actor_fix20 on kombax_meta.publications(actor_id);
create index if not exists meta_publications_social_created_fix20 on kombax_meta.publications(social_id, created_at desc);
