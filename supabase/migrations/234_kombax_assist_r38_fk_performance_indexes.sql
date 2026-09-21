-- KOMBAX 20.101 R38 · Performance hardening for new Assist/Migrations foreign keys
-- Covers only R38 tables flagged by the Supabase performance advisor.

create index if not exists assistance_turns_user_ref_idx
  on kombax_ai_ops.assistance_turns(user_ref);
create index if not exists assistance_turns_session_id_idx
  on kombax_ai_ops.assistance_turns(session_id)
  where session_id is not null;

create index if not exists assist_chat_messages_user_ref_idx
  on kombax_customer_ops.assist_chat_messages(user_ref);

create index if not exists migration_file_analysis_user_ref_idx
  on kombax_customer_ops.migration_file_analysis(user_ref);
create index if not exists migration_file_analysis_turn_id_idx
  on kombax_customer_ops.migration_file_analysis(turn_id)
  where turn_id is not null;

comment on index kombax_ai_ops.assistance_turns_user_ref_idx is 'R38 advisor hardening: covering index for assistance_turns.user_ref FK.';
comment on index kombax_ai_ops.assistance_turns_session_id_idx is 'R38 advisor hardening: covering partial index for assistance_turns.session_id FK.';
comment on index kombax_customer_ops.assist_chat_messages_user_ref_idx is 'R38 advisor hardening: covering index for assist_chat_messages.user_ref FK.';
comment on index kombax_customer_ops.migration_file_analysis_user_ref_idx is 'R38 advisor hardening: covering index for migration_file_analysis.user_ref FK.';
comment on index kombax_customer_ops.migration_file_analysis_turn_id_idx is 'R38 advisor hardening: covering partial index for migration_file_analysis.turn_id FK.';
