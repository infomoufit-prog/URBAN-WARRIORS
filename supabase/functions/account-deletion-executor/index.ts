import { createClient } from 'npm:@supabase/supabase-js@2.112.3'

type StorageObject = { bucket: string; path: string }
type Json = Record<string, unknown>

const HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'"
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: HEADERS })
}

function serviceKey(): string {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (!raw) throw new Error('KOMBAX_SERVICE_KEY_MISSING')
  const keys = JSON.parse(raw) as Record<string, string>
  const key = keys.default || Object.values(keys)[0]
  if (!key) throw new Error('KOMBAX_SERVICE_KEY_MISSING')
  return key
}

function publishableKey(): string {
  return Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_PUBLISHABLE_KEY') || ''
}

function validUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID()
  try {
    if (request.method !== 'POST') return json({ error: 'Método no permitido', request_id: requestId }, 405)
    const authHeader = request.headers.get('authorization') || ''
    if (!/^Bearer\s+\S+/i.test(authHeader)) return json({ error: 'No autorizado', request_id: requestId }, 401)
    const contentType = String(request.headers.get('content-type') || '').toLowerCase()
    if (!contentType.includes('application/json')) return json({ error: 'Formato no admitido', request_id: requestId }, 415)
    const body = await request.json().catch(() => null) as Json | null
    const solicitudId = body?.solicitud_id
    if (!validUuid(solicitudId)) return json({ error: 'Solicitud no válida', request_id: requestId }, 400)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const anonKey = publishableKey()
    if (!supabaseUrl || !anonKey) throw new Error('KOMBAX_EDGE_CONFIG_MISSING')

    // Cliente Owner: conserva el JWT real para que los RPC validen la sesión maestra MFA.
    const owner = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false }
    })
    const { data: plan, error: planError } = await owner.rpc('app_kombax_deletion_plan_v119', { p_solicitud_id: solicitudId })
    if (planError) return json({ error: planError.message || 'No autorizado', request_id: requestId }, /required|forbidden|authorized/i.test(planError.message || '') ? 403 : 400)

    const targetProfileId = plan?.target_profile_id
    if (!validUuid(targetProfileId)) throw new Error('KOMBAX_DELETION_TARGET_INVALID')
    const objects = (Array.isArray(plan?.storage_objects) ? plan.storage_objects : [])
      .filter((item: unknown): item is StorageObject => {
        const value = item as StorageObject
        return Boolean(value && typeof value.bucket === 'string' && typeof value.path === 'string' && value.bucket && value.path)
      })

    // Service role queda encapsulado en la Edge Function: nunca se expone al navegador/APK.
    const service = createClient(supabaseUrl, serviceKey(), { auth: { persistSession: false, autoRefreshToken: false } })

    let removed = 0
    const grouped = new Map<string, string[]>()
    for (const object of objects) {
      const list = grouped.get(object.bucket) || []
      if (!list.includes(object.path)) list.push(object.path)
      grouped.set(object.bucket, list)
    }
    for (const [bucket, paths] of grouped) {
      for (let i = 0; i < paths.length; i += 100) {
        const batch = paths.slice(i, i + 100)
        const { error } = await service.storage.from(bucket).remove(batch)
        if (error) throw new Error(`KOMBAX_STORAGE_DELETE_FAILED:${bucket}:${error.message}`)
        removed += batch.length
      }
    }

    // Soft-delete administrativo de Supabase Auth: inutiliza la cuenta y elimina
    // identificadores de acceso sin hard-delete del UUID técnico. Es importante
    // conservar ese UUID porque múltiples trazas financieras/auditoría lo referencian.
    const { error: authError } = await service.auth.admin.deleteUser(targetProfileId, true)
    if (authError) throw new Error(`KOMBAX_AUTH_SOFT_DELETE_FAILED:${authError.message}`)

    const { data: finalized, error: finalizeError } = await owner.rpc('app_kombax_deletion_finalize_v119', {
      p_solicitud_id: solicitudId,
      p_auth_anonymized: true,
      p_storage_removed: removed
    })
    if (finalizeError) throw new Error(`KOMBAX_DELETION_FINALIZE_FAILED:${finalizeError.message}`)

    return json({ ok: true, request_id: requestId, removed_storage_objects: removed, result: finalized })
  } catch (error) {
    console.error(`[${requestId}]`, error)
    return json({ error: 'No se pudo completar la eliminación de la cuenta', request_id: requestId }, 500)
  }
})
