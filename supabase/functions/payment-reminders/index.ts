import { createClient } from 'npm:@supabase/supabase-js@2'
import { importPKCS8, SignJWT } from 'npm:jose@6'

type Json = Record<string, unknown>

type FirebaseServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

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

function localParts(timeZone: string, date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
  }).formatToParts(date)
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]))
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    hour: Number(values.hour),
    minute: Number(values.minute)
  }
}

async function firebaseAccessToken(account: FirebaseServiceAccount): Promise<string> {
  const privateKey = await importPKCS8(account.private_key.replace(/\\n/g, '\n'), 'RS256')
  const now = Math.floor(Date.now() / 1000)
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(account.token_uri || 'https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)

  const response = await fetch(account.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion
    })
  })
  const payload = await response.json()
  if (!response.ok || !payload.access_token) {
    throw new Error(`No se pudo obtener token FCM: ${JSON.stringify(payload)}`)
  }
  return payload.access_token as string
}

async function sendFcm(
  account: FirebaseServiceAccount,
  accessToken: string,
  token: string,
  notification: { title: string; body: string; route?: string; data?: Json }
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: notification.title, body: notification.body },
          data: {
            route: notification.route || 'notifications',
            payload: JSON.stringify(notification.data || {})
          },
          android: {
            priority: 'high',
            notification: { channel_id: 'urban_warriors_alerts' }
          },
          webpush: {
            fcm_options: { link: notification.route ? `/#/${notification.route}` : '/#/notifications' }
          }
        }
      })
    }
  )
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(JSON.stringify(payload))
  return payload
}

Deno.serve(async (request) => {
  try {
    const expectedSecret = Deno.env.get('UW_CRON_SECRET')
    const suppliedSecret = request.headers.get('x-uw-cron-secret')
    if (!expectedSecret || suppliedSecret !== expectedSecret) {
      return Response.json({ error: 'No autorizado' }, { status: 401 })
    }

    const body = request.method === 'POST'
      ? await request.json().catch(() => ({} as Json)) as Json
      : ({} as Json)
    const force = body.force === true
    const requestedClub = typeof body.club_id === 'string' ? body.club_id : null
    const requestedDate = typeof body.date === 'string' ? body.date : null

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabase = createClient(supabaseUrl, getSecretKey(), {
      auth: { persistSession: false, autoRefreshToken: false }
    })

    let configQuery = supabase
      .from('configuracion_avisos_cuota')
      .select('club_id,activo,hora_envio,zona_horaria,canal_push')
      .eq('activo', true)
    if (requestedClub) configQuery = configQuery.eq('club_id', requestedClub)
    const { data: configs, error: configError } = await configQuery
    if (configError) throw configError

    const processed: Json[] = []
    const pushClubIds: string[] = []
    for (const config of configs || []) {
      const local = localParts(config.zona_horaria || 'Europe/Madrid')
      const configuredHour = Number(String(config.hora_envio || '10:00').slice(0, 2))
      if (!force && local.hour !== configuredHour) continue
      const processDate = requestedDate || local.date
      const { data, error } = await supabase.rpc('procesar_avisos_cobro', {
        p_fecha: processDate,
        p_club_id: config.club_id
      })
      if (error) throw error
      processed.push({ club_id: config.club_id, date: processDate, result: data })
      if (config.canal_push) pushClubIds.push(config.club_id)
    }

    const firebaseRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    let pushSent = 0
    let pushErrors = 0

    if (firebaseRaw && pushClubIds.length) {
      const account = JSON.parse(firebaseRaw) as FirebaseServiceAccount
      const accessToken = await firebaseAccessToken(account)
      const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString()
      const { data: notifications, error: notificationsError } = await supabase
        .from('notificaciones')
        .select('id,club_id,perfil_id,tipo,titulo,cuerpo,ruta,datos,push_intentos')
        .not('perfil_id', 'is', null)
        .in('tipo', ['cuota','aviso_cobro','pago','validacion_pago','recibo'])
        .in('club_id', pushClubIds)
        .is('push_enviado_en', null)
        .gte('creado_en', since)
        .limit(500)
      if (notificationsError) throw notificationsError

      const profileIds = [...new Set((notifications || []).map((item) => item.perfil_id))]
      const devicesByProfile = new Map<string, string[]>()
      const pushFinanceDisabled = new Set<string>()
      if (profileIds.length) {
        const { data: prefs, error: prefsError } = await supabase
          .from('preferencias_notificacion')
          .select('perfil_id,push_finanzas')
          .in('perfil_id', profileIds)
        if (prefsError) throw prefsError
        for (const pref of prefs || []) if (pref.push_finanzas === false) pushFinanceDisabled.add(pref.perfil_id)
        const allowedProfileIds = profileIds.filter((id) => !pushFinanceDisabled.has(id))
        if (allowedProfileIds.length) {
          const { data: devices, error: devicesError } = await supabase
            .from('dispositivos_push')
            .select('perfil_id,token')
            .eq('activo', true)
            .in('perfil_id', allowedProfileIds)
          if (devicesError) throw devicesError
          for (const device of devices || []) {
            const list = devicesByProfile.get(device.perfil_id) || []
            list.push(device.token)
            devicesByProfile.set(device.perfil_id, list)
          }
        }
      }

      for (const notification of notifications || []) {
        const tokens = devicesByProfile.get(notification.perfil_id) || []
        if (!tokens.length) continue
        let delivered = false
        const errors: string[] = []
        for (const token of tokens) {
          try {
            await sendFcm(account, accessToken, token, {
              title: notification.titulo,
              body: notification.cuerpo,
              route: notification.ruta,
              data: notification.datos
            })
            delivered = true
            pushSent += 1
          } catch (error) {
            pushErrors += 1
            errors.push(error instanceof Error ? error.message : String(error))
          }
        }
        await supabase
          .from('notificaciones')
          .update({
            push_enviado_en: delivered ? new Date().toISOString() : null,
            push_intentos: Number(notification.push_intentos || 0) + 1,
            push_error: errors.length ? errors.join(' | ').slice(0, 2000) : null
          })
          .eq('id', notification.id)
      }
    }

    return Response.json({ ok: true, processed, push_sent: pushSent, push_errors: pushErrors })
  } catch (error) {
    console.error(error)
    return Response.json({
      error: error instanceof Error ? error.message : String(error)
    }, { status: 500 })
  }
})
