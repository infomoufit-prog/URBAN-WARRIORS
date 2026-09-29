import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read=(path)=>readFile(new URL(`../${path}`,import.meta.url),'utf8');
const [sql,edge,ui,repositories,css,config,knowledge]=await Promise.all([
  read('supabase/migrations/293_kombax_owner_agents_r105.sql'),
  read('supabase/functions/kombax-owner-agents-r105/index.ts'),
  read('web/js/modules/platform-admin.js'),
  read('web/js/core/repositories.js'),
  read('web/css/kombax-premium.css'),
  read('supabase/config.toml'),
  read('docs/owner-agents/KOMBAX_OWNER_AGENTS_KNOWLEDGE_R105.md')
]);

assert.match(sql,/create schema if not exists kombax_owner_ai/i);
assert.match(sql,/revoke all on schema kombax_owner_ai from public,anon,authenticated/i);
assert.match(sql,/create table if not exists kombax_owner_ai\.agent_turns/i);
assert.match(sql,/create table if not exists kombax_owner_ai\.pilot_reports/i);
assert.match(sql,/app_kombax_owner_agents_dashboard_r105/i);
assert.match(sql,/app_kombax_owner_agent_turn_context_r105/i);
assert.match(sql,/SERVICE_ROLE_REQUIRED/i);
assert.match(sql,/grant execute on function public\.app_kombax_owner_agent_turn_complete_r105[\s\S]*to service_role/i);
assert.doesNotMatch(sql,/grant execute on function public\.app_kombax_owner_agent_turn_complete_r105[\s\S]{0,220}to authenticated/i);
assert.match(sql,/select public\.app_kombax_pilot_metrics_r97\(\) into v_context/i);

assert.match(edge,/gpt-6-luna/);
assert.match(edge,/https:\/\/api\.openai\.com\/v1\/responses/);
assert.match(edge,/reasoning:\{effort\}/);
assert.match(edge,/store:false/);
assert.match(edge,/json_schema/);
assert.match(edge,/owner_operations/);
assert.match(edge,/pilot_intelligence/);
assert.match(edge,/requires_human/);
assert.doesNotMatch(edge,/sk-[A-Za-z0-9_-]{20,}/);

assert.match(config,/\[functions\.kombax-owner-agents-r105\][\s\S]*?verify_jwt\s*=\s*true/);
assert.match(repositories,/ownerAgents:\(\)=>backend\.globalReadRpc\('app_kombax_owner_agents_dashboard_r105'/);
assert.match(repositories,/ownerAgentChat:[\s\S]*kombax-owner-agents-r105/);

assert.match(ui,/Owner Operations/);
assert.match(ui,/Pilot Intelligence/);
assert.match(ui,/data-owner-agent-form/);
assert.match(ui,/insertAdjacentHTML\('beforeend'/);
assert.match(ui,/data-owner-agent-context="seller_application"/);
assert.match(ui,/data-owner-agent-context="platform_application"/);
const agentUi=ui.slice(ui.indexOf('function ownerAgentMessages'),ui.indexOf('function pilotProgramPanel'));
assert.doesNotMatch(agentUi,/input_tokens|output_tokens|reasoning_tokens|cost_eur|cost_usd/);
assert.match(css,/\.kx-owner-agent-grid/);
assert.match(css,/@media\(max-width:900px\)[^{]*\{/);

assert.match(knowledge,/Autonomía/);
assert.match(knowledge,/Pagos, reembolsos|pagos, reembolsos/i);
assert.match(knowledge,/NO VERIFICADO/);

console.log('PASS R105 Owner Operations + Pilot Intelligence');

