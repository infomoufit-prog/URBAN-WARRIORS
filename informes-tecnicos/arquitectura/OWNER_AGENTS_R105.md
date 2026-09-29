# Owner Agents R105

## Implementación

R105 incorpora dos agentes al Owner existente, sin crear una segunda consola:

- **Owner Operations**: operaciones, solicitudes y verificaciones.
- **Pilot Intelligence**: análisis agregado y preparación de informes del piloto.

## Flujo técnico

1. El Owner autenticado envía una instrucción desde la consola.
2. La RPC `app_kombax_owner_agent_turn_start_r105` valida que sea administrador de plataforma y registra el turno.
3. `app_kombax_owner_agent_turn_context_r105` construye un snapshot mínimo autorizado.
4. La Edge Function `kombax-owner-agents-r105` llama a Responses API con `gpt-6-luna` y salida estructurada.
5. Una RPC reservada a `service_role` registra respuesta, riesgo, hallazgos, próximos pasos y usage privado.
6. La interfaz muestra el resultado sin tokens ni coste técnico.

## Seguridad

- Persistencia en esquema privado `kombax_owner_ai`.
- Sin acceso directo para `anon` o `authenticated`.
- Entrada limitada a Owner por validación backend.
- Escritura de resultados reservada a `service_role`.
- `verify_jwt = true` en la Edge Function.
- `store: false` en Responses API.
- Contexto minimizado; no se copian valores de documentos de identidad.
- Salida estructurada y limitada.
- Acciones sensibles conservan revisión humana y las RPC existentes.

## Despliegue requerido

1. Aplicar `supabase/migrations/293_kombax_owner_agents_r105.sql`.
2. Desplegar `supabase/functions/kombax-owner-agents-r105`.
3. Configurar `OPENAI_API_KEY` en secretos de Edge Functions.
4. Opcional: configurar `KOMBAX_OWNER_AGENT_MODEL=gpt-6-luna`.
5. Desplegar frontend R105.

## Validación

La prueba R105 comprueba contrato SQL, privacidad, permisos, función Edge, modelo, razonamiento, interfaz, actualización optimista del chat y configuración JWT. La prueba en vivo requiere Supabase desplegado y una cuenta Owner autenticada.

