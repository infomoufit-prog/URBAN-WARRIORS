import { createClient } from 'npm:@supabase/supabase-js@2.112.3'
import { authorizeCronRequest, jsonResponse, validIsoDate, validUuid } from '../_shared/cron-security.ts'

function getSecretKey(): string {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (!raw) throw new Error('No se encontró una clave secreta de Supabase')
  const keys = JSON.parse(raw) as Record<string, string>
  const key = keys.default || Object.values(keys)[0]
  if (!key) throw new Error('SUPABASE_SECRET_KEYS no contiene ninguna clave')
  return key
}

function localDate(timeZone: string, now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(now)
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]))
  return `${values.year}-${values.month}-${values.day}`
}

Deno.serve(async (request) => {
  let requestId = crypto.randomUUID()
  try {
    const guard = await authorizeCronRequest(request)
    requestId = guard.requestId
    if (guard.response) return guard.response

    const body = guard.body
    if (body.club_id != null && !validUuid(body.club_id)) {
      return jsonResponse({ error: 'club_id no válido', request_id: requestId }, 400, requestId)
    }
    if (body.date != null && !validIsoDate(body.date)) {
      return jsonResponse({ error: 'date no válida', request_id: requestId }, 400, requestId)
    }

    const requestedClub = typeof body.club_id === 'string' ? body.club_id : null
    const requestedDate = typeof body.date === 'string' ? body.date : null
    const shadow = body.shadow !== false
    const forceCurrentCycle = body.force_current_cycle === true

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, getSecretKey(), {
      auth: { persistSession: false, autoRefreshToken: false }
    })

    let clubsQuery = supabase
      .from('clubes')
      .select('id,zona_horaria')
      .eq('activo', true)
    if (requestedClub) clubsQuery = clubsQuery.eq('id', requestedClub)

    const { data: clubs, error: clubsError } = await clubsQuery
    if (clubsError) throw clubsError

    const processed: Record<string, unknown>[] = []
    let created = 0
    let simulated = 0
    let errors = 0

    for (const club of clubs || []) {
      const date = requestedDate || localDate(String(club.zona_horaria || 'Europe/Madrid'))
      const { data, error } = await supabase.rpc('procesar_cargos_recurrentes', {
        p_fecha: date,
        p_club_id: club.id,
        p_shadow: shadow,
        p_forzar_ciclo_actual: forceCurrentCycle
      })

      if (error) {
        errors += 1
        processed.push({
          club_id: club.id,
          date,
          ok: false,
          error: String(error.message || error.code || 'Error de recurrencia')
        })
        continue
      }

      const result = (data || {}) as Record<string, unknown>
      created += Number(result.cargos_creados || 0)
      simulated += Number(result.cargos_simulados || 0)
      processed.push({ club_id: club.id, date, ...result })
    }

    return jsonResponse({
      ok: errors === 0,
      request_id: requestId,
      shadow,
      clubs: processed.length,
      cargos_creados: created,
      cargos_simulados: simulated,
      errors,
      processed
    }, errors ? 207 : 200, requestId)
  } catch (error) {
    console.error(`[${requestId}]`, error)
    return jsonResponse({ error: 'Error interno', request_id: requestId }, 500, requestId)
  }
})
