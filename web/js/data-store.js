(function () {
  'use strict';

  const STORAGE_KEY = 'uw_phase1_data_v2';
  const SESSION_KEY = 'uw_phase1_session_v2';
  const SUPABASE_SESSION_KEY = 'uw_supabase_session';
  const RUNTIME_VERSION = '1.6.0';
  const MUTATION_ENDPOINT = 'app_mutate_v160';
  const CONTRACT_ENDPOINT = 'app_runtime_contract_v160';
  const PROBE_ENDPOINT = 'app_write_channel_probe_v160';
  const COLLECTIONS = [
    'accounts','disciplinas','grados','grupos','horarios','socios','preinscripciones','tarifas','cuotas','pagos','recibos',
    'sesiones','asistencias','registros_acceso','comunicaciones','seguimiento','consentimientos','material',
    'material_variantes','pedidos_material','notificaciones','historial_avisos_cuota','documentos','miembros','invitaciones','graduaciones','socio_disciplinas','tutores','progreso','notificaciones_lecturas'
  ];

  function clone(value) { return value == null ? value : JSON.parse(JSON.stringify(value)); }
  function uuid(prefix) { return `${prefix || 'id'}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`; }
  function requestUuid() {
    if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
    const bytes = new Uint8Array(16);
    if (globalThis.crypto?.getRandomValues) globalThis.crypto.getRandomValues(bytes);
    else for (let i = 0; i < bytes.length; i += 1) bytes[i] = Math.floor(Math.random() * 256);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
  }
  function isUuid(value) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || '')); }

  function createEmptyData(club) {
    const baseClub = club || {
      id: window.UW_CONFIG?.primaryClubId || null,
      nombre: window.UW_CONFIG?.appName || 'Urban Warriors',
      slug: window.UW_CONFIG?.clubSlug || 'urban-warriors',
      lema: window.UW_CONFIG?.brand?.slogan || '',
      logo_url: window.UW_CONFIG?.brand?.logo || ''
    };
    const result = {
      club: baseClub,
      users: {},
      settings: { dias_aviso: [1, 4, 8, 11, 14], dias_avisos_cobro: [1, 4, 8, 11, 14], marcar_vencida_dia: 15 }
    };
    for (const key of COLLECTIONS) result[key] = [];
    return result;
  }

  function normalizeDemo(data) {
    const seed = clone(window.UW_DEMO_SEED || createEmptyData());
    const result = Object.assign(seed, data || {});
    result.club = Object.assign({}, seed.club || {}, data?.club || {});
    result.users = Object.assign({}, seed.users || {}, data?.users || {});
    result.settings = Object.assign({}, seed.settings || {}, data?.settings || {});
    for (const key of COLLECTIONS) result[key] = Array.isArray(data?.[key]) ? data[key] : (seed[key] || []);
    return result;
  }

  function readDemo() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      const seed = normalizeDemo(window.UW_DEMO_SEED);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(seed));
      return seed;
    }
    try { return normalizeDemo(JSON.parse(raw)); }
    catch (error) {
      console.warn('Datos demo dañados; se restablece la semilla.', error);
      const seed = normalizeDemo(window.UW_DEMO_SEED);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(seed));
      return seed;
    }
  }

  function saveDemo(data) { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); }

  class AuthExpiredError extends Error {
    constructor(message) {
      super(message || 'Tu sesión ha caducado. Vuelve a iniciar sesión.');
      this.name = 'AuthExpiredError';
      this.code = 'AUTH_EXPIRED';
    }
  }

  class SupabaseLite {
    constructor(config) {
      this.url = (config.url || '').replace(/\/$/, '');
      this.anonKey = config.anonKey || '';
      this.session = this.readSession();
      this.refreshPromise = null;
    }

    readSession() {
      try { return JSON.parse(localStorage.getItem(SUPABASE_SESSION_KEY) || 'null'); }
      catch (_) { return null; }
    }

    saveSession(session) {
      if (!session) {
        this.session = null;
        localStorage.removeItem(SUPABASE_SESSION_KEY);
        return null;
      }
      const copy = Object.assign({}, session);
      if (!copy.expires_at && copy.expires_in) copy.expires_at = Math.floor(Date.now() / 1000) + Number(copy.expires_in);
      this.session = copy;
      localStorage.setItem(SUPABASE_SESSION_KEY, JSON.stringify(copy));
      return copy;
    }

    enabled() { return Boolean(this.url && this.anonKey); }

    clearSession() { this.saveSession(null); }

    isExpiringSoon() {
      if (!this.session?.access_token) return false;
      if (!this.session.expires_at) return false;
      return Number(this.session.expires_at) <= Math.floor(Date.now() / 1000) + 75;
    }

    async refreshSession() {
      if (!this.session?.refresh_token) throw new AuthExpiredError();
      if (this.refreshPromise) return this.refreshPromise;
      this.refreshPromise = (async () => {
        const response = await fetch(`${this.url}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: { apikey: this.anonKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: this.session.refresh_token })
        });
        const body = await response.json().catch(() => ({}));
        if (!response.ok || !body?.access_token) {
          this.clearSession();
          throw new AuthExpiredError(body?.msg || body?.error_description || body?.message);
        }
        return this.saveSession(body);
      })().finally(() => { this.refreshPromise = null; });
      return this.refreshPromise;
    }

    async ensureFreshSession() {
      if (this.session?.access_token && this.isExpiringSoon()) await this.refreshSession();
      return this.session;
    }

    headers(extra, useAuth) {
      const headers = {
        apikey: this.anonKey,
        'Content-Type': 'application/json',
        Prefer: 'return=representation'
      };
      // Las claves sb_publishable_* NO son JWT. Solo se envían en `apikey`.
      // Authorization se reserva exclusivamente al access_token real del usuario.
      if (useAuth !== false && this.session?.access_token) {
        headers.Authorization = `Bearer ${this.session.access_token}`;
      }
      return Object.assign(headers, extra || {});
    }

    async request(path, options, retry) {
      const opts = Object.assign({}, options || {});
      const useAuth = opts.useAuth !== false;
      delete opts.useAuth;
      const canRefresh = !path.startsWith('/auth/v1/token') && !path.startsWith('/auth/v1/signup');
      if (useAuth && canRefresh) await this.ensureFreshSession();
      const controller = new AbortController();
      const timeoutMs = Number(opts.timeoutMs || 25000);
      delete opts.timeoutMs;
      if (!opts.signal) opts.signal = controller.signal;
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      let response;
      try {
        response = await fetch(`${this.url}${path}`, Object.assign({}, opts, { headers: this.headers(opts.headers, useAuth) }));
      } catch (error) {
        if (error?.name === 'AbortError') throw new Error('La operación tardó demasiado. Comprueba la conexión y vuelve a intentarlo; no se ha confirmado ningún guardado.');
        throw error;
      } finally {
        clearTimeout(timeout);
      }
      const text = await response.text();
      let body = null;
      if (text) { try { body = JSON.parse(text); } catch (_) { body = text; } }
      if (!response.ok) {
        const detail = body && [body.message, body.details, body.hint].filter(Boolean).join(' · ');
        const message = detail || body && (body.msg || body.error_description || body.error) || `Error HTTP ${response.status}`;
        const tokenExpired = response.status === 401 || /jwt.*expired|token.*expired|invalid.*jwt/i.test(String(message));
        if (tokenExpired && retry !== false && this.session?.refresh_token && canRefresh) {
          await this.refreshSession();
          return this.request(path, options, false);
        }
        if (tokenExpired) {
          this.clearSession();
          throw new AuthExpiredError();
        }
        const err = new Error(message);
        err.status = response.status;
        err.code = body?.code || null;
        throw err;
      }
      return body;
    }

    async signIn(email, password) {
      const body = await this.request('/auth/v1/token?grant_type=password', {
        method: 'POST', useAuth: false, body: JSON.stringify({ email, password })
      }, false);
      return this.saveSession(body);
    }

    async signUp(email, password, metadata) {
      const body = await this.request('/auth/v1/signup', {
        method: 'POST', useAuth: false, body: JSON.stringify({ email, password, data: metadata || {} })
      }, false);
      if (body?.access_token) this.saveSession(body);
      return body;
    }

    async signOut() {
      if (this.session) {
        try { await this.request('/auth/v1/logout', { method: 'POST' }, false); } catch (_) {}
      }
      this.clearSession();
    }

    async select(table, query, useAuth) {
      return this.request(`/rest/v1/${table}?${query || 'select=*'}`, { method: 'GET', useAuth: useAuth !== false });
    }
    async insert() { throw new Error('DML directo deshabilitado: usa la puerta de mutación versionada.'); }
    async upsert() { throw new Error('DML directo deshabilitado: usa la puerta de mutación versionada.'); }
    async update() { throw new Error('DML directo deshabilitado: usa la puerta de mutación versionada.'); }
    async updateWhere() { throw new Error('DML directo deshabilitado: usa la puerta de mutación versionada.'); }
    async remove() { throw new Error('DML directo deshabilitado: usa la puerta de mutación versionada.'); }
    async rpc(name, payload) { return this.request(`/rest/v1/rpc/${name}`, { method: 'POST', body: JSON.stringify(payload || {}) }); }
    async invokeFunction(name, payload) {
      return this.request(`/functions/v1/${encodeURIComponent(name)}`, { method: 'POST', body: JSON.stringify(payload || {}) });
    }

    async storageUpload(bucket, path, file, upsert, retry) {
      await this.ensureFreshSession();
      if (!this.session?.access_token) throw new AuthExpiredError();
      const response = await fetch(`${this.url}/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`, {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          Authorization: `Bearer ${this.session?.access_token || ''}`,
          'Content-Type': file.type || 'application/octet-stream',
          'x-upsert': upsert ? 'true' : 'false'
        },
        body: file
      });
      const body = await response.json().catch(() => ({}));
      if (response.status === 401 && retry !== false && this.session?.refresh_token) {
        await this.refreshSession();
        return this.storageUpload(bucket, path, file, upsert, false);
      }
      if (response.status === 401) {
        this.clearSession();
        throw new AuthExpiredError();
      }
      if (!response.ok) throw new Error(body.message || body.error || `Error al subir archivo (${response.status})`);
      return body;
    }

    async storageRemove(bucket, paths) {
      const list = (Array.isArray(paths) ? paths : [paths]).filter(Boolean);
      if (!list.length) return null;
      return this.request(`/storage/v1/object/${encodeURIComponent(bucket)}`, {
        method: 'DELETE',
        body: JSON.stringify({ prefixes: list }),
        timeoutMs: 30000
      });
    }

    publicStorageUrl(bucket, path) {
      return `${this.url}/storage/v1/object/public/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`;
    }

    async storageSignedUrl(bucket, path, expiresIn) {
      const body = await this.request(`/storage/v1/object/sign/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`, {
        method: 'POST', body: JSON.stringify({ expiresIn: expiresIn || 600 })
      });
      const signed = body.signedURL || body.signedUrl || body.url;
      return signed && signed.startsWith('http') ? signed : `${this.url}/storage/v1${signed}`;
    }
  }

  const config = window.UW_CONFIG;
  const supabase = new SupabaseLite(config.supabase || {});
  const tableMap = {
    sesiones: 'sesiones_entrenamiento',
    material: 'material_catalogo',
    pedidos_material: 'material_pedidos',
    registros_acceso: 'registros_acceso_clase',
    documentos: 'documentos_socios'
  };

  function safeArray(value) { return Array.isArray(value) ? value : []; }

  const store = {
    mode: config.demoMode || !config.supabase.enabled ? 'demo' : 'supabase',
    session: (() => { try { return JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'); } catch (_) { return null; } })(),
    data: createEmptyData(),
    loading: false,
    backendContract: null,
    writeBlockedReason: null,

    async init() {
      if (this.mode === 'demo') {
        this.data = readDemo();
        return this.data;
      }
      if (!supabase.enabled()) throw new Error('Supabase no está configurado. Añade la URL y la clave pública.');
      if (this.session && !supabase.session) {
        this.session = null;
        localStorage.removeItem(SESSION_KEY);
      }
      if (this.session && supabase.session) {
        try {
          await supabase.ensureFreshSession();
          await this.ensureBackendContract(true);
          await this.loadRemote();
          return this.data;
        } catch (error) {
          if (error?.code !== 'AUTH_EXPIRED') throw error;
          await this.clearExpiredSession();
        }
      }
      await this.loadPublicCatalog();
      return this.data;
    },

    getSession() { return this.session; },
    getData() { return this.data || createEmptyData(); },
    getBackendContract() { return this.backendContract; },

    async ensureBackendContract(force) {
      if (this.mode === 'demo') return { ok: true, backend_version: RUNTIME_VERSION, write_ready: true, demo: true };
      if (!this.session?.club_id) throw new AuthExpiredError();
      if (!force && this.backendContract?.backend_version === RUNTIME_VERSION && this.backendContract?.club_id === this.session.club_id && this.backendContract?.write_ready) {
        return this.backendContract;
      }
      let contract;
      try {
        contract = await supabase.rpc(CONTRACT_ENDPOINT, { p_club_id: this.session.club_id });
      } catch (error) {
        this.backendContract = null;
        this.writeBlockedReason = error?.message || 'No se pudo verificar el backend de escritura.';
        const wrapped = new Error(`Backend de guardado no preparado: ${this.writeBlockedReason}`);
        wrapped.code = 'BACKEND_CONTRACT';
        throw wrapped;
      }
      const expected = config.release?.backendVersion || RUNTIME_VERSION;
      if (!contract?.ok || !contract?.write_ready || contract?.backend_version !== expected || contract?.mutation_endpoint !== MUTATION_ENDPOINT) {
        this.backendContract = null;
        this.writeBlockedReason = `Contrato incompatible. Web ${expected}; backend ${contract?.backend_version || 'desconocido'}.`;
        const error = new Error(this.writeBlockedReason);
        error.code = 'BACKEND_CONTRACT';
        throw error;
      }
      this.backendContract = contract;
      this.writeBlockedReason = null;
      return contract;
    },

    async mutate(operation, payload, options) {
      if (this.mode === 'demo') throw new Error('La puerta de mutación solo se usa con Supabase.');
      const opts = options || {};
      if (!opts.skipContract) await this.ensureBackendContract(false);
      const requestId = opts.requestId || requestUuid();
      const body = Object.assign({}, payload || {});
      if (this.session?.club_id && body.club_id == null) body.club_id = this.session.club_id;
      let response;
      try {
        response = await supabase.rpc(MUTATION_ENDPOINT, {
          p_operation: operation,
          p_payload: body,
          p_request_id: requestId
        });
      } catch (error) {
        const wrapped = new Error(`No se guardó (${operation}): ${error?.message || 'error de conexión con Supabase'}`);
        wrapped.code = error?.code || 'MUTATION_FAILED';
        wrapped.status = error?.status;
        wrapped.cause = error;
        throw wrapped;
      }
      if (!response?.ok || response?.backend_version !== RUNTIME_VERSION || response?.operation !== operation || response?.request_id !== requestId) {
        const error = new Error(`Respuesta de guardado inválida para ${operation}. No se confirma ningún cambio.`);
        error.code = 'MUTATION_RESPONSE_INVALID';
        throw error;
      }
      return response.data;
    },

    assertData(collection) {
      if (!this.data) this.data = createEmptyData();
      if (collection && !Array.isArray(this.data[collection])) this.data[collection] = [];
      return this.data;
    },

    async clearExpiredSession() {
      supabase.clearSession();
      this.session = null;
      this.backendContract = null;
      this.writeBlockedReason = null;
      localStorage.removeItem(SESSION_KEY);
      this.data = createEmptyData();
    },

    async loginDemo(role) {
      this.assertData();
      const user = this.data.users[role];
      if (!user) throw new Error('Rol de demostración no válido.');
      this.session = Object.assign({ mode: 'demo', club_id: this.data.club.id }, clone(user));
      localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      return this.session;
    },

    async login(email, password) {
      if (this.mode === 'demo') {
        this.assertData('accounts');
        const normalized = String(email || '').toLowerCase();
        const account = this.data.accounts.find((item) => item.email.toLowerCase() === normalized && item.password === password);
        if (account) {
          const user = this.data.users[account.user_key];
          if (!user) throw new Error('La cuenta demo no tiene un perfil asociado.');
          this.session = Object.assign({ mode: 'demo', club_id: this.data.club.id }, clone(user));
          localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
          return this.session;
        }
        const role = normalized.includes('monitor') ? 'monitor' : normalized.includes('familia') ? 'family' : normalized.includes('admin') ? 'admin' : null;
        if (role && password) return this.loginDemo(role);
        throw new Error('Correo o contraseña incorrectos. En la demo usa demo1234.');
      }

      const auth = await supabase.signIn(email, password);
      const userId = auth.user.id;
      const pendingRaw = localStorage.getItem('uw_pending_registration');
      if (pendingRaw) {
        const pending = JSON.parse(pendingRaw);
        await this.mutate('cuenta.registrar', {
          club_slug: config.clubSlug, tipo_cuenta: pending.tipo_cuenta,
          adulto_nombre: pending.adulto_nombre, adulto_apellidos: pending.adulto_apellidos,
          telefono: pending.telefono, fecha_nacimiento_adulto: pending.adulto_fecha_nacimiento || null,
          menor_nombre: pending.menor_nombre || null, menor_apellidos: pending.menor_apellidos || null,
          fecha_nacimiento_menor: pending.menor_fecha_nacimiento || null,
          disciplina_id: pending.disciplina_id || null, grupo_id: pending.grupo_id || null,
          tarifa_id: pending.tarifa_id || null
        }, { skipContract: true });
        localStorage.removeItem('uw_pending_registration');
      }
      const pendingInvitationRaw = localStorage.getItem('uw_pending_invitation');
      if (pendingInvitationRaw) {
        const pendingInvitation = JSON.parse(pendingInvitationRaw);
        if (!pendingInvitation.email || String(pendingInvitation.email).toLowerCase() === String(auth.user.email || '').toLowerCase()) {
          await this.mutate('invitacion.aceptar', { token: pendingInvitation.token }, { skipContract: true });
          localStorage.removeItem('uw_pending_invitation');
        }
      }
      const memberships = await supabase.select('miembros_club', `select=club_id,rol,clubes(id,nombre,slug,logo_url,color_primario,color_secundario)&perfil_id=eq.${userId}&activo=eq.true`);
      if (!memberships?.length) {
        await supabase.signOut();
        throw new Error('El usuario no pertenece a ningún club activo.');
      }
      const rolePriority = ['direccion','secretaria','economia','comunicacion','monitor','familia','alumno'];
      memberships.sort((a,b) => rolePriority.indexOf(a.rol) - rolePriority.indexOf(b.rol));
      const membership = memberships.find((m) => m.clubes?.slug === config.clubSlug) || memberships[0];
      const profileRows = await supabase.select('perfiles', `select=*&id=eq.${userId}&limit=1`).catch(() => []);
      const profile = profileRows?.[0] || {};
      this.session = {
        mode: 'supabase', id: userId, email: auth.user.email,
        nombre: profile.nombre || auth.user.user_metadata?.nombre || auth.user.email,
        apellidos: profile.apellidos || auth.user.user_metadata?.apellidos || '',
        telefono: profile.telefono || auth.user.user_metadata?.telefono || '',
        rol: membership.rol, roles: memberships.filter((m) => m.club_id === membership.club_id).map((m) => m.rol),
        club_id: membership.club_id, socio_ids: []
      };
      localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      await this.ensureBackendContract(true);
      await this.loadRemote();
      return this.session;
    },

    async registerAccount(payload) {
      const type = payload.tipo_cuenta;
      if (!['adulto', 'tutor'].includes(type)) throw new Error('Tipo de registro no válido.');
      if (this.mode === 'demo') {
        this.assertData('accounts');
        if (this.data.accounts.some((item) => item.email.toLowerCase() === payload.email.toLowerCase())) throw new Error('Ya existe una cuenta con este correo.');
        const userId = uuid('usr');
        const userKey = uuid('account');
        const role = type === 'adulto' ? 'alumno' : 'familia';
        const socioId = uuid('so');
        const user = { id: userId, nombre: payload.adulto_nombre, apellidos: payload.adulto_apellidos, rol: role, email: payload.email, telefono: payload.telefono, socio_ids: [socioId] };
        this.data.users[userKey] = user;
        this.data.accounts.push({ email: payload.email, password: payload.password, user_key: userKey });
        const student = type === 'adulto' ? {
          id: socioId, nombre: payload.adulto_nombre, apellidos: payload.adulto_apellidos,
          fecha_nacimiento: payload.adulto_fecha_nacimiento, telefono: payload.telefono, email: payload.email,
          estado: 'prealta', grupo_id: payload.grupo_id, disciplina_id: payload.disciplina_id,
          grado: 'Sin asignar', tutor: '', perfil_id: userId, cuota_estado: 'pendiente'
        } : {
          id: socioId, nombre: payload.menor_nombre, apellidos: payload.menor_apellidos,
          fecha_nacimiento: payload.menor_fecha_nacimiento, telefono: '', email: '',
          estado: 'prealta', grupo_id: payload.grupo_id, disciplina_id: payload.disciplina_id,
          grado: 'Sin asignar', tutor: `${payload.adulto_nombre} ${payload.adulto_apellidos}`,
          tutor_perfil_id: userId, cuota_estado: 'pendiente'
        };
        this.data.socios.unshift(Object.assign({ club_id: this.data.club.id }, student));
        this.data.preinscripciones.unshift({
          id: uuid('pr'), club_id: this.data.club.id, solicitante_perfil_id: userId,
          tipo_solicitud: type === 'adulto' ? 'adulto' : 'menor', nombre: student.nombre, apellidos: student.apellidos,
          fecha_nacimiento: student.fecha_nacimiento, edad: null,
          tutor: type === 'tutor' ? student.tutor : '', tutor_email: payload.email,
          telefono: payload.telefono, disciplina_id: payload.disciplina_id, grupo_id: payload.grupo_id,
          tarifa_id: payload.tarifa_id || null, estado: 'enviada', fecha: new Date().toISOString().slice(0, 10)
        });
        await this.persist();
        this.session = Object.assign({ mode: 'demo', club_id: this.data.club.id }, clone(user));
        localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
        return { session: this.session, confirmationRequired: false };
      }

      const auth = await supabase.signUp(payload.email, payload.password, {
        nombre: payload.adulto_nombre, apellidos: payload.adulto_apellidos, telefono: payload.telefono,
        tipo_cuenta: type, club_slug: config.clubSlug
      });
      if (!auth?.access_token) {
        localStorage.setItem('uw_pending_registration', JSON.stringify(payload));
        return { confirmationRequired: true };
      }
      const result = await this.mutate('cuenta.registrar', {
        club_slug: config.clubSlug, tipo_cuenta: type,
        adulto_nombre: payload.adulto_nombre, adulto_apellidos: payload.adulto_apellidos,
        telefono: payload.telefono, fecha_nacimiento_adulto: payload.adulto_fecha_nacimiento || null,
        menor_nombre: payload.menor_nombre || null, menor_apellidos: payload.menor_apellidos || null,
        fecha_nacimiento_menor: payload.menor_fecha_nacimiento || null,
        disciplina_id: payload.disciplina_id || null, grupo_id: payload.grupo_id || null,
        tarifa_id: payload.tarifa_id || null
      }, { skipContract: true });
      await this.login(payload.email, payload.password);
      return { session: this.session, result, confirmationRequired: false };
    },

    async registerInvitedAccount(payload) {
      if (!payload?.token) throw new Error('Falta el código de invitación.');
      const auth = await supabase.signUp(payload.email, payload.password, {
        nombre: payload.nombre, apellidos: payload.apellidos, telefono: payload.telefono || '', invitation_token: payload.token
      });
      if (!auth?.access_token) {
        localStorage.setItem('uw_pending_invitation', JSON.stringify({ token: payload.token, email: payload.email }));
        return { confirmationRequired: true };
      }
      await this.mutate('invitacion.aceptar', { token: payload.token }, { skipContract: true });
      await this.login(payload.email, payload.password);
      return { confirmationRequired: false, session: this.session };
    },

    async logout() {
      if (this.mode === 'supabase') await supabase.signOut();
      this.session = null;
      this.backendContract = null;
      this.writeBlockedReason = null;
      localStorage.removeItem(SESSION_KEY);
      this.data = this.mode === 'demo' ? readDemo() : createEmptyData();
      if (this.mode === 'supabase') await this.loadPublicCatalog().catch(() => {});
    },

    async loadPublicCatalog() {
      const clubs = await supabase.select('clubes', `select=*&slug=eq.${encodeURIComponent(config.clubSlug)}&activo=eq.true&limit=1`, false);
      const club = clubs?.[0];
      if (!club) throw new Error('El club no está disponible.');
      const clubId = club.id;
      const results = await Promise.all([
        supabase.select('disciplinas', `select=*&club_id=eq.${clubId}&activa=eq.true&order=orden`, false),
        supabase.select('grupos', `select=*&club_id=eq.${clubId}&activo=eq.true`, false),
        supabase.select('horarios_grupo', `select=*&club_id=eq.${clubId}`, false),
        supabase.select('tarifas', `select=*&club_id=eq.${clubId}&activa=eq.true`, false)
      ]);
      this.data = createEmptyData(club);
      this.data.disciplinas = safeArray(results[0]);
      this.data.grupos = safeArray(results[1]).map((g) => Object.assign({}, g, { monitor: g.monitor_nombre || '' }));
      this.data.horarios = safeArray(results[2]);
      this.data.tarifas = safeArray(results[3]);
      return this.data;
    },

    async safeSelect(table, query, fallback) {
      try { return safeArray(await supabase.select(table, query)); }
      catch (error) {
        if (error?.code === 'AUTH_EXPIRED') throw error;
        console.warn(`No se pudo cargar ${table}:`, error.message);
        return fallback || [];
      }
    },

    async loadRemote() {
      if (!this.session) {
        this.data = createEmptyData();
        return this.data;
      }
      this.loading = true;
      try {
        await supabase.ensureFreshSession();
        const clubId = this.session.club_id;
        const catalogManager = (this.session.roles || [this.session.rol]).some((role) => ['direccion','secretaria','economia','comunicacion'].includes(role));
        const activeSuffix = catalogManager ? '' : '&activo=eq.true';
        const activeTariffSuffix = catalogManager ? '' : '&activa=eq.true';
        const queries = [
          ['clubes', `select=*&id=eq.${clubId}&limit=1`],
          ['disciplinas', `select=*&club_id=eq.${clubId}&order=orden`],
          ['grados', `select=*&club_id=eq.${clubId}&order=orden`],
          ['grupos', `select=*&club_id=eq.${clubId}${activeSuffix}`],
          ['horarios_grupo', `select=*&club_id=eq.${clubId}`],
          ['socios', `select=*&club_id=eq.${clubId}&order=apellidos,nombre`],
          ['tutores_socios', `select=*&club_id=eq.${clubId}`],
          ['socio_disciplinas', `select=*&club_id=eq.${clubId}&activa=eq.true`],
          ['graduaciones', `select=*&club_id=eq.${clubId}&order=fecha.desc`],
          ['preinscripciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['tarifas', `select=*&club_id=eq.${clubId}${activeTariffSuffix}`],
          ['cuotas', `select=*&club_id=eq.${clubId}&order=vencimiento.desc`],
          ['pagos', `select=*&club_id=eq.${clubId}&order=fecha.desc`],
          ['recibos_cuota', `select=*&club_id=eq.${clubId}&order=periodo.desc,numero.desc`],
          ['sesiones_entrenamiento', `select=*&club_id=eq.${clubId}&order=fecha.desc`],
          ['asistencias', `select=*&club_id=eq.${clubId}`],
          ['registros_acceso_clase', `select=*&club_id=eq.${clubId}&order=registrado_en.desc`],
          ['comunicaciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['seguimiento', `select=*&club_id=eq.${clubId}&order=fecha.desc`],
          ['consentimientos', `select=*&club_id=eq.${clubId}`],
          ['material_catalogo', `select=*&club_id=eq.${clubId}${activeSuffix}`],
          ['material_variantes', `select=*&club_id=eq.${clubId}${activeTariffSuffix}`],
          ['material_pedidos', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['notificaciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['notificaciones_lecturas', `select=*&perfil_id=eq.${this.session.id}`],
          ['config_club', `select=*&club_id=eq.${clubId}`],
          ['configuracion_avisos_cuota', `select=*&club_id=eq.${clubId}&limit=1`],
          ['historial_avisos_cuota', `select=*&club_id=eq.${clubId}&order=fecha_programada.desc&limit=250`],
          ['documentos_socios', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['miembros_club', `select=*,perfiles(id,nombre,apellidos,telefono)&club_id=eq.${clubId}&order=creado_en`],
          ['invitaciones_club', `select=*&club_id=eq.${clubId}&order=creado_en.desc`],
          ['v_progreso_socio', `select=*&club_id=eq.${clubId}`]
        ];
        const loaded = await Promise.all(queries.map(([table, query]) => this.safeSelect(table, query, [])));
        const [clubRows, disciplinas, grados, gruposRaw, horarios, sociosRaw, tutores, socioDisciplinas, graduaciones, preinscripcionesRaw, tarifas, cuotas, pagos, recibos, sesionesRaw, asistencias, accesos, comunicaciones, seguimiento, consentimientos, materialRaw, variantes, pedidos, notificacionesRaw, notificacionesLecturas, configClubRows, configAvisos, historialAvisos, documentos, miembrosRaw, invitaciones, progreso] = loaded;
        const club = clubRows[0];
        if (!club) throw new Error('No se pudo cargar la información del club.');

        const enrollmentsBySocio = new Map();
        for (const link of socioDisciplinas) {
          if (!enrollmentsBySocio.has(link.socio_id)) enrollmentsBySocio.set(link.socio_id, []);
          enrollmentsBySocio.get(link.socio_id).push(link);
        }
        for (const links of enrollmentsBySocio.values()) {
          links.sort((a, b) => String(b.fecha_inicio || '').localeCompare(String(a.fecha_inicio || '')) || String(a.id).localeCompare(String(b.id)));
        }
        const tutorBySocio = new Map();
        for (const link of tutores) if (!tutorBySocio.has(link.socio_id) || link.contacto_principal) tutorBySocio.set(link.socio_id, link);
        const latestGradBySocio = new Map();
        for (const grad of graduaciones) if (!latestGradBySocio.has(grad.socio_id)) latestGradBySocio.set(grad.socio_id, grad);
        const latestFeeBySocio = new Map();
        for (const fee of cuotas) if (!latestFeeBySocio.has(fee.socio_id)) latestFeeBySocio.set(fee.socio_id, fee);

        const socios = sociosRaw.map((socio) => {
          const links = enrollmentsBySocio.get(socio.id) || [];
          const primary = links[0] || null;
          const tutor = tutorBySocio.get(socio.id);
          const graduation = latestGradBySocio.get(socio.id);
          const gradeId = primary?.grado_id || graduation?.grado_id || null;
          const grade = grados.find((g) => g.id === gradeId);
          const matriculas = links.map((link) => {
            const discipline = disciplinas.find((item) => item.id === link.disciplina_id);
            const group = gruposRaw.find((item) => item.id === link.grupo_id);
            const currentGrade = grados.find((item) => item.id === link.grado_id);
            return Object.assign({}, link, {
              disciplina_nombre: discipline?.nombre || '',
              grupo_nombre: group?.nombre || '',
              grado_nombre: currentGrade?.nombre || ''
            });
          });
          return Object.assign({}, socio, {
            // Campos primarios conservados solo por compatibilidad visual; la lógica usa matriculas/grupo_ids/disciplina_ids.
            disciplina_id: primary?.disciplina_id || null,
            grupo_id: primary?.grupo_id || null,
            grado_id: gradeId,
            grado: grade?.nombre || socio.grado_texto || 'Sin asignar',
            matriculas,
            grupo_ids: [...new Set(links.map((item) => item.grupo_id).filter(Boolean))],
            disciplina_ids: [...new Set(links.map((item) => item.disciplina_id).filter(Boolean))],
            tutor_perfil_id: tutor?.tutor_perfil_id || null,
            tutor: socio.tutor_nombre || (tutor ? 'Tutor/a vinculado/a' : ''),
            cuota_estado: latestFeeBySocio.get(socio.id)?.estado || 'sin_cuota'
          });
        });
        const counts = new Map();
        for (const link of socioDisciplinas) if (link.grupo_id) counts.set(link.grupo_id, (counts.get(link.grupo_id) || 0) + 1);
        const grupos = gruposRaw.map((g) => Object.assign({}, g, { monitor: g.monitor_nombre || '', activos: counts.get(g.id) || 0 }));
        const material = materialRaw.map((m) => Object.assign({}, m, {
          stock: m.stock == null ? variantes.filter((v) => v.material_id === m.id).reduce((sum, v) => sum + Number(v.stock || 0), 0) : Number(m.stock)
        }));
        const preinscripciones = preinscripcionesRaw.map((p) => Object.assign({}, p, { tutor: p.tutor_nombre || '', fecha: p.creado_en }));
        const sesiones = sesionesRaw.map((s) => Object.assign({}, s, { monitor: s.monitor_nombre || '' }));
        const readIds = new Set(notificacionesLecturas.map((item) => item.notificacion_id));
        const notificaciones = notificacionesRaw.map((item) => Object.assign({}, item, { leida: Boolean(item.leida || readIds.has(item.id)) }));

        this.data = createEmptyData(club);
        Object.assign(this.data, {
          club, disciplinas, grados, grupos, horarios, socios, preinscripciones, tarifas, cuotas, pagos, recibos,
          sesiones, asistencias, registros_acceso: accesos, comunicaciones, seguimiento, consentimientos,
          material, material_variantes: variantes, pedidos_material: pedidos, notificaciones,
          historial_avisos_cuota: historialAvisos, documentos, invitaciones, graduaciones, socio_disciplinas: socioDisciplinas, tutores, progreso, notificaciones_lecturas: notificacionesLecturas,
          miembros: miembrosRaw.map((m) => Object.assign({}, m, { nombre: m.perfiles?.nombre || '', apellidos: m.perfiles?.apellidos || '', telefono: m.perfiles?.telefono || '' })),
          settings: Object.assign(
            { dias_aviso: [1,4,8,11,14], dias_avisos_cobro: [1,4,8,11,14], marcar_vencida_dia: 15 },
            Object.fromEntries(configClubRows.map((row) => [row.clave, row.valor])),
            configAvisos[0] || {}
          )
        });
        if (['familia', 'alumno'].includes(this.session.rol)) {
          this.session.socio_ids = socios.map((item) => item.id);
          localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
        }
        return this.data;
      } catch (error) {
        if (error?.code === 'AUTH_EXPIRED') {
          await this.clearExpiredSession();
          throw error;
        }
        this.data = this.data || createEmptyData();
        throw error;
      } finally {
        this.loading = false;
      }
    },

    async persist() {
      if (this.mode === 'demo') {
        saveDemo(this.data);
        return this.data;
      }
      if (!this.session || !this.data?.club) return this.data;
      const allowed = ['nombre','lema','telefono','email','direccion','web','logo_url','portada_url','color_primario','color_secundario'];
      const payload = {};
      for (const key of allowed) if (Object.prototype.hasOwnProperty.call(this.data.club, key)) payload[key] = this.data.club[key] ?? null;
      if (Object.prototype.hasOwnProperty.call(this.data.settings || {}, 'dia_vencimiento')) payload.dia_vencimiento = Number(this.data.settings.dia_vencimiento);
      if (Object.prototype.hasOwnProperty.call(this.data.settings || {}, 'avisos_clase_horas')) payload.avisos_clase_horas = Number(this.data.settings.avisos_clase_horas);
      const club = await this.mutate('club.configurar', payload);
      if (club?.id) this.data.club = Object.assign({}, this.data.club, club);
      return this.data;
    },

    normalizePayload(collection, payload, isUpdate) {
      const p = Object.assign({}, payload);
      const remove = (...keys) => keys.forEach((key) => delete p[key]);
      if (collection === 'grupos') {
        p.monitor_nombre = p.monitor_nombre || p.monitor || null;
        remove('monitor', 'activos');
      } else if (collection === 'preinscripciones') {
        p.tutor_nombre = p.tutor_nombre || p.tutor || null;
        remove('tutor', 'fecha');
      } else if (collection === 'sesiones') {
        p.monitor_nombre = p.monitor_nombre || p.monitor || null;
        remove('monitor');
      } else if (collection === 'comunicaciones') {
        remove('fecha');
        if (p.estado === 'publicada' && !p.publicada_en) p.publicada_en = new Date().toISOString();
        if (p.estado === 'programada' && !p.programada_para && p.evento_fecha) p.programada_para = p.evento_fecha;
        if (!isUpdate) p.creada_por = p.creada_por || this.session?.id || null;
      } else if (collection === 'material') {
        remove('stock');
      } else if (collection === 'pedidos_material') {
        if (!isUpdate) p.creado_por = p.creado_por || this.session?.id || null;
      } else if (collection === 'seguimiento') {
        if (!isUpdate) p.registrado_por = p.registrado_por || this.session?.id || null;
      } else if (collection === 'asistencias') {
        p.registrado_por = p.registrado_por || this.session?.id || null;
      } else if (collection === 'registros_acceso') {
        if (!isUpdate) p.registrado_por = p.registrado_por || this.session?.id || null;
      } else if (collection === 'notificaciones') {
        if (!isUpdate) p.creada_por = p.creada_por || this.session?.id || null;
      } else if (collection === 'documentos') {
        if (!isUpdate) p.subido_por = p.subido_por || this.session?.id || null;
      }
      for (const [key, val] of Object.entries(p)) {
        if (key.endsWith('_id') && val === '') p[key] = null;
        if ((key === 'fecha_nacimiento' || key === 'fecha_inicio' || key === 'fecha_fin' || key === 'evento_fecha' || key === 'programada_para') && val === '') p[key] = null;
      }
      return p;
    },

    async saveGroup(payload, schedules) {
      if (this.mode === 'demo') {
        const id = payload.id || uuid('gr');
        const clean = Object.assign({}, payload, { id, club_id: this.data.club.id, monitor: payload.monitor_nombre || payload.monitor || '', activo: payload.activo !== false });
        delete clean.monitor_nombre;
        const existing = this.data.grupos.find((g) => g.id === id);
        if (existing) Object.assign(existing, clean); else this.data.grupos.unshift(clean);
        this.data.horarios = this.data.horarios.filter((h) => h.grupo_id !== id);
        for (const item of schedules || []) this.data.horarios.push(Object.assign({ id: uuid('ho'), club_id: this.data.club.id, grupo_id: id }, item));
        await this.persist();
        return clean;
      }
      const result = await this.mutate('grupo.guardar', {
        id: payload.id || null,
        disciplina_id: payload.disciplina_id,
        nombre: payload.nombre,
        monitor_nombre: payload.monitor_nombre || payload.monitor || '',
        sala: payload.sala || '',
        edad_min: payload.edad_min == null || payload.edad_min === '' ? null : Number(payload.edad_min),
        edad_max: payload.edad_max == null || payload.edad_max === '' ? null : Number(payload.edad_max),
        plazas: payload.plazas == null || payload.plazas === '' ? null : Number(payload.plazas),
        activo: payload.activo !== false,
        horarios: schedules || []
      });
      await this.loadRemote();
      return this.data.grupos.find((g) => g.id === result?.id) || this.data.grupos.find((g) => g.nombre === payload.nombre);
    },

    async createMember(payload) {
      if (this.mode === 'demo') {
        const member = Object.assign({ id: uuid('so'), club_id: this.data.club.id }, payload);
        this.data.socios.unshift(member); await this.persist(); return member;
      }
      const result = await this.mutate('alumno.guardar', {
        id: null,
        nombre: payload.nombre,
        apellidos: payload.apellidos,
        fecha_nacimiento: payload.fecha_nacimiento || null,
        telefono: payload.telefono || '',
        email: payload.email || '',
        tutor_nombre: payload.tutor || payload.tutor_nombre || '',
        disciplina_id: payload.disciplina_id || null,
        grupo_id: payload.grupo_id || null,
        grado_id: payload.grado_id || null,
        grado_texto: payload.grado || payload.grado_texto || '',
        tarifa_id: payload.tarifa_id || null,
        estado: payload.estado || 'activo',
        contacto_emergencia: payload.contacto_emergencia || '',
        telefono_emergencia: payload.telefono_emergencia || '',
        notas_internas: payload.notas_internas || ''
      });
      await this.loadRemote();
      return this.data.socios.find((item) => item.id === result?.id);
    },

    async updateMember(id, changes) {
      if (this.mode === 'demo') {
        const member = this.data.socios.find((item) => item.id === id); Object.assign(member, changes); await this.persist(); return member;
      }
      const current = this.data.socios.find((item) => item.id === id) || {};
      const payload = Object.assign({}, current, changes);
      const result = await this.mutate('alumno.guardar', {
        id,
        nombre: payload.nombre,
        apellidos: payload.apellidos,
        fecha_nacimiento: payload.fecha_nacimiento || null,
        telefono: payload.telefono || '',
        email: payload.email || '',
        tutor_nombre: payload.tutor || payload.tutor_nombre || '',
        disciplina_id: payload.disciplina_id || null,
        grupo_id: payload.grupo_id || null,
        grado_id: payload.grado_id || null,
        grado_texto: payload.grado || payload.grado_texto || '',
        tarifa_id: payload.tarifa_id || null,
        estado: payload.estado || 'activo',
        contacto_emergencia: payload.contacto_emergencia || '',
        telefono_emergencia: payload.telefono_emergencia || '',
        notas_internas: payload.notas_internas || ''
      });
      await this.loadRemote();
      return this.data.socios.find((item) => item.id === result?.id || item.id === id);
    },

    async approveEnrollment(id) {
      if (this.mode === 'demo') return null;
      const result = await this.mutate('preinscripcion.aprobar', { preinscripcion_id: id });
      await this.loadRemote();
      return result?.id || null;
    },

    async createInvitation(email, role) {
      if (this.mode === 'demo') {
        const item = { id: uuid('inv'), club_id: this.data.club.id, email, rol: role, token: uuid('token'), estado: 'pendiente', creado_en: new Date().toISOString() };
        this.data.invitaciones.unshift(item); await this.persist(); return item;
      }
      const result = await this.mutate('invitacion.crear', { email, rol: role });
      await this.loadRemote();
      return result;
    },

    async acceptInvitation(token) {
      if (this.mode === 'demo') return { estado: 'aceptada' };
      return this.mutate('invitacion.aceptar', { token }, { skipContract: true });
    },

    async saveOwnProfile(changes) {
      if (!this.session) throw new AuthExpiredError();
      if (this.mode === 'demo') { Object.assign(this.session, changes); localStorage.setItem(SESSION_KEY, JSON.stringify(this.session)); return this.session; }
      await this.mutate('perfil.guardar', {
        nombre: changes.nombre || '', apellidos: changes.apellidos || '', telefono: changes.telefono || ''
      });
      Object.assign(this.session, changes); localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      await this.loadRemote(); return this.session;
    },

    async saveDiscipline(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('disciplinas', payload.id, payload) : this.add('disciplinas', payload);
      const result = await this.mutate('disciplina.guardar', {
        id: payload.id || null,
        nombre: payload.nombre,
        descripcion: payload.descripcion || '',
        color: payload.color || '#ffffff',
        activa: payload.activa !== false,
        orden: Number(payload.orden || 0)
      });
      await this.loadRemote();
      return this.data.disciplinas.find((item) => item.id === result?.id);
    },

    async saveGrade(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('grados', payload.id, payload) : this.add('grados', payload);
      const result = await this.mutate('grado.guardar', {
        id: payload.id || null,
        disciplina_id: payload.disciplina_id,
        nombre: payload.nombre,
        orden: Number(payload.orden || 1),
        color: payload.color || null,
        meses_minimos: payload.meses_minimos === '' || payload.meses_minimos == null ? null : Number(payload.meses_minimos),
        activo: payload.activo !== false
      });
      await this.loadRemote();
      return this.data.grados.find((item) => item.id === result?.id);
    },

    async registerGraduation(payload) {
      if (this.mode === 'demo') {
        const record = await this.add('graduaciones', Object.assign({}, payload, { registrado_por: this.session?.id || null }));
        const member = this.data.socios.find((item) => item.id === payload.socio_id);
        const grade = this.data.grados.find((item) => item.id === payload.grado_id);
        if (member && grade) { member.grado_id = grade.id; member.grado = grade.nombre; await this.persist(); }
        return record;
      }
      const result = await this.mutate('graduacion.registrar', {
        socio_id: payload.socio_id,
        disciplina_id: payload.disciplina_id,
        grado_id: payload.grado_id,
        fecha: payload.fecha || new Date().toISOString().slice(0,10),
        examinador: payload.examinador || '',
        nota: payload.nota || ''
      });
      await this.loadRemote();
      return this.data.graduaciones.find((item) => item.id === result?.id);
    },

    async saveTariff(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('tarifas', payload.id, payload) : this.add('tarifas', payload);
      const result = await this.mutate('tarifa.guardar', {
        id: payload.id || null,
        nombre: payload.nombre,
        descripcion: payload.descripcion || '',
        importe: Number(payload.importe || 0),
        matricula: Number(payload.matricula || 0),
        periodicidad: payload.periodicidad || 'mensual',
        activa: payload.activa !== false
      });
      await this.loadRemote();
      return this.data.tarifas.find((item) => item.id === result?.id);
    },

    async saveMaterial(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('material', payload.id, payload) : this.add('material', payload);
      const result = await this.mutate('material.guardar', {
        id: payload.id || null,
        disciplina_id: payload.disciplina_id || null,
        nombre: payload.nombre,
        categoria: payload.categoria || '',
        descripcion: payload.descripcion || '',
        imagen_url: payload.imagen_url || '',
        precio: Number(payload.precio || 0),
        stock: Number(payload.stock || 0),
        obligatorio: payload.obligatorio === true,
        referencia: payload.referencia || '',
        activo: payload.activo !== false
      });
      await this.loadRemote();
      return this.data.material.find((item) => item.id === result?.id);
    },

    async saveCommunication(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('comunicaciones', payload.id, payload) : this.add('comunicaciones', payload);
      const result = await this.mutate('publicacion.guardar', {
        id: payload.id || null,
        tipo: payload.tipo || 'noticia',
        titulo: payload.titulo,
        cuerpo: payload.cuerpo,
        audiencia: payload.audiencia || 'todos',
        estado: payload.estado || 'borrador',
        evento_fecha: payload.evento_fecha || null,
        ubicacion: payload.ubicacion || '',
        imagen_url: payload.imagen_url || ''
      });
      await this.loadRemote();
      return this.data.comunicaciones.find((item) => item.id === result?.id);
    },

    async saveSession(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('sesiones', payload.id, payload) : this.add('sesiones', payload);
      const result = await this.mutate('sesion.guardar', {
        id: payload.id || null,
        grupo_id: payload.grupo_id,
        fecha: payload.fecha,
        hora_inicio: payload.hora_inicio,
        hora_fin: payload.hora_fin || null,
        monitor_nombre: payload.monitor_nombre || payload.monitor || '',
        estado: payload.estado || 'programada',
        observacion_general: payload.observacion_general || '',
        codigo_acceso: payload.codigo_acceso || ''
      });
      await this.loadRemote();
      return this.data.sesiones.find((item) => item.id === result?.id);
    },

    async requestMaterial(payload) {
      if (this.mode === 'demo') return this.add('pedidos_material', payload);
      const result = await this.mutate('material.solicitar', {
        socio_id: payload.socio_id,
        material_id: payload.material_id,
        variante_id: payload.variante_id || null,
        cantidad: Number(payload.cantidad || 1),
        observaciones: payload.observaciones || ''
      });
      await this.loadRemote();
      return this.data.pedidos_material.find((item) => item.id === result?.id);
    },

    async updateMaterialOrder(id, status) {
      if (this.mode === 'demo') return this.update('pedidos_material', id, { estado: status });
      const result = await this.mutate('material.pedido.estado', { pedido_id: id, estado: status });
      await this.loadRemote();
      return this.data.pedidos_material.find((item) => item.id === result?.id || item.id === id);
    },

    async saveMaterialVariant(payload) {
      if (this.mode === 'demo') return payload.id ? this.update('material_variantes', payload.id, payload) : this.add('material_variantes', payload);
      const result = await this.mutate('material.variante.guardar', {
        id: payload.id || null,
        material_id: payload.material_id,
        talla: payload.talla || '',
        color: payload.color || '',
        referencia: payload.referencia || '',
        stock: Number(payload.stock || 0),
        activa: payload.activa !== false
      });
      await this.loadRemote();
      return this.data.material_variantes.find((item) => item.id === result?.id);
    },

    async saveAttendance(sessionId, memberId, status, observation) {
      if (this.mode === 'demo') {
        const existing = this.data.asistencias.find((item) => item.sesion_id === sessionId && item.socio_id === memberId);
        return existing ? this.update('asistencias', existing.id, { estado: status, observacion: observation || null }) : this.add('asistencias', { sesion_id: sessionId, socio_id: memberId, estado: status, observacion: observation || null });
      }
      const result = await this.mutate('asistencia.guardar', {
        sesion_id: sessionId, socio_id: memberId, estado: status, observacion: observation || null
      });
      return result?.id || null;
    },

    async registerCheckin(sessionId, memberId, code, method) {
      if (this.mode === 'demo') {
        const existing = this.data.registros_acceso.find((item) => item.sesion_id === sessionId && item.socio_id === memberId);
        if (existing) return existing;
        const access = await this.add('registros_acceso', { sesion_id: sessionId, socio_id: memberId, registrado_en: new Date().toISOString(), metodo: method || 'codigo', resultado: 'permitido' });
        const attendance = this.data.asistencias.find((item) => item.sesion_id === sessionId && item.socio_id === memberId);
        if (attendance) await this.update('asistencias', attendance.id, { estado: 'presente' });
        else await this.add('asistencias', { sesion_id: sessionId, socio_id: memberId, estado: 'presente' });
        return access;
      }
      const result = await this.mutate('checkin.registrar', {
        sesion_id: sessionId, socio_id: memberId, codigo: code || '', metodo: method || 'codigo'
      });
      await this.loadRemote();
      return result?.id || null;
    },

    async saveTracking(payload) {
      if (this.mode === 'demo') return this.add('seguimiento', payload);
      const result = await this.mutate('seguimiento.guardar', {
        socio_id: payload.socio_id,
        tipo: payload.tipo,
        nota: payload.nota,
        visibilidad: payload.visibilidad || 'equipo',
        fecha: payload.fecha || new Date().toISOString().slice(0, 10)
      });
      await this.loadRemote();
      return this.data.seguimiento.find((item) => item.id === result?.id);
    },

    async registerDocumentRecord(payload) {
      if (this.mode === 'demo') return this.add('documentos', payload);
      const result = await this.mutate('documento.registrar', {
        socio_id: payload.socio_id,
        nombre: payload.nombre,
        tipo: payload.tipo || 'otro',
        storage_path: payload.storage_path,
        mime_type: payload.mime_type || null,
        tamano_bytes: payload.tamano_bytes == null ? null : Number(payload.tamano_bytes),
        visible_familia: payload.visible_familia !== false
      });
      await this.loadRemote();
      return this.data.documentos.find((item) => item.id === result?.id);
    },

    async saveEnrollment(payload) {
      if (this.mode === 'demo') return this.add('preinscripciones', payload);
      const result = await this.mutate('preinscripcion.crear', {
        tipo_solicitud: payload.tipo_solicitud || 'adulto',
        nombre: payload.nombre,
        apellidos: payload.apellidos,
        fecha_nacimiento: payload.fecha_nacimiento || null,
        tutor_nombre: payload.tutor || payload.tutor_nombre || '',
        tutor_email: payload.tutor_email || '',
        telefono: payload.telefono || '',
        disciplina_id: payload.disciplina_id || null,
        grupo_id: payload.grupo_id || null,
        tarifa_id: payload.tarifa_id || null,
        parentesco: payload.parentesco || '',
        observaciones: payload.observaciones || ''
      });
      await this.loadRemote();
      return this.data.preinscripciones.find((item) => item.id === result?.id);
    },

    async markNotificationRead(id) {
      if (this.mode === 'demo') return this.update('notificaciones', id, { leida: true, leida_en: new Date().toISOString() });
      await this.mutate('notificacion.leer', { notificacion_id: id });
      await this.loadRemote();
      return this.data.notificaciones.find((item) => item.id === id);
    },

    async waitlistEnrollment(id, reason) {
      if (this.mode === 'demo') return this.update('preinscripciones', id, { estado: 'lista_espera', observaciones: reason || '' });
      await this.mutate('preinscripcion.espera', { preinscripcion_id: id, motivo: reason || '' });
      await this.loadRemote();
      return this.data.preinscripciones.find((item) => item.id === id);
    },

    async rejectEnrollment(id, reason) {
      if (this.mode === 'demo') return this.update('preinscripciones', id, { estado: 'rechazada', observaciones: reason || '' });
      await this.mutate('preinscripcion.rechazar', { preinscripcion_id: id, motivo: reason || '' });
      await this.loadRemote();
      return this.data.preinscripciones.find((item) => item.id === id);
    },

    async add(collection, payload) {
      this.assertData(collection);
      if (this.mode === 'demo') {
        const item = Object.assign({ id: uuid(collection.slice(0, 2)), club_id: this.data.club.id }, payload);
        this.data[collection].unshift(item);
        await this.persist();
        return item;
      }
      if (!this.session) throw new AuthExpiredError();
      if (collection === 'socios') return this.createMember(payload);
      if (collection === 'preinscripciones') return this.saveEnrollment(payload);
      if (collection === 'grupos') return this.saveGroup(payload, payload.horarios || []);
      if (collection === 'disciplinas') return this.saveDiscipline(payload);
      if (collection === 'grados') return this.saveGrade(payload);
      if (collection === 'graduaciones') return this.registerGraduation(payload);
      if (collection === 'tarifas') return this.saveTariff(payload);
      if (collection === 'material') return this.saveMaterial(payload);
      if (collection === 'material_variantes') return this.saveMaterialVariant(payload);
      if (collection === 'comunicaciones') return this.saveCommunication(payload);
      if (collection === 'sesiones') return this.saveSession(payload);
      if (collection === 'seguimiento') return this.saveTracking(payload);
      if (collection === 'pedidos_material') return this.requestMaterial(payload);
      throw new Error(`Escritura no gobernada bloqueada: ${collection}. Actualiza el registro de mutaciones antes de guardar.`);
    },

    async update(collection, id, changes) {
      this.assertData(collection);
      const item = this.data[collection].find((entry) => entry.id === id);
      if (!item) throw new Error('Registro no encontrado.');
      if (this.mode === 'demo') {
        Object.assign(item, changes, { actualizado_en: new Date().toISOString() });
        await this.persist();
        return item;
      }
      if (collection === 'socios') return this.updateMember(id, changes);
      if (collection === 'grupos') return this.saveGroup(Object.assign({}, item, changes, { id }), changes.horarios || this.data.horarios.filter((h) => h.grupo_id === id));
      if (collection === 'disciplinas') return this.saveDiscipline(Object.assign({}, item, changes, { id }));
      if (collection === 'grados') return this.saveGrade(Object.assign({}, item, changes, { id }));
      if (collection === 'tarifas') return this.saveTariff(Object.assign({}, item, changes, { id }));
      if (collection === 'material') return this.saveMaterial(Object.assign({}, item, changes, { id }));
      if (collection === 'material_variantes') return this.saveMaterialVariant(Object.assign({}, item, changes, { id }));
      if (collection === 'comunicaciones') return this.saveCommunication(Object.assign({}, item, changes, { id }));
      if (collection === 'sesiones') return this.saveSession(Object.assign({}, item, changes, { id }));
      if (collection === 'pedidos_material' && changes.estado) return this.updateMaterialOrder(id, changes.estado);
      throw new Error(`Actualización no gobernada bloqueada: ${collection}. No se permite escribir directamente en tablas.`);
    },

    async remove(collection, id) {
      this.assertData(collection);
      if (this.mode === 'demo') {
        this.data[collection] = this.data[collection].filter((entry) => entry.id !== id);
        await this.persist();
        return;
      }
      throw new Error(`Borrado no gobernado bloqueado: ${collection}. Debe existir una operación explícita de servidor.`);
    },

    async runFinalDiagnostic() {
      if (this.mode === 'demo') return { demo: true, backend_version: RUNTIME_VERSION };
      if (!this.session) throw new AuthExpiredError();
      const contract = await this.ensureBackendContract(true);
      const probe = await supabase.rpc(PROBE_ENDPOINT, { p_club_id: this.session.club_id });
      return { ok: Boolean(contract?.ok && probe?.ok), contract, probe };
    },

    async fileToDataUrl(file, maxMb) {
      if (!file || !file.size) return '';
      if (file.size > Number(maxMb || 5) * 1024 * 1024) throw new Error(`El archivo supera ${maxMb || 5} MB.`);
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(new Error('No se pudo leer el archivo.'));
        reader.readAsDataURL(file);
      });
    },

    async uploadPublicMedia(file, category) {
      if (!file || !file.size) return '';
      if (file.size > 5 * 1024 * 1024) throw new Error('La imagen supera 5 MB.');
      if (!/^image\/(jpeg|png|webp|gif)$/i.test(file.type || '')) throw new Error('Formato no admitido. Utiliza JPG, PNG, WebP o GIF.');
      if (this.mode === 'demo') return this.fileToDataUrl(file, 5);
      const extension = (file.name.split('.').pop() || 'jpg').replace(/[^a-z0-9]/gi, '').toLowerCase();
      const path = `${this.session.club_id}/${category || 'general'}/${Date.now()}-${uuid('media')}.${extension}`;
      await supabase.storageUpload('club-public-media', path, file, false);
      return supabase.publicStorageUrl('club-public-media', path);
    },

    async removePublicMedia(url) {
      if (!url || this.mode === 'demo') return;
      const marker = '/storage/v1/object/public/club-public-media/';
      const raw = String(url);
      const index = raw.indexOf(marker);
      if (index < 0) return;
      const path = decodeURIComponent(raw.slice(index + marker.length).split('?')[0]);
      if (path) await supabase.storageRemove('club-public-media', path);
    },

    async removePaymentProof(path) {
      if (!path || this.mode === 'demo' || String(path).startsWith('data:') || String(path).startsWith('http')) return;
      await supabase.storageRemove('justificantes-pago', path);
    },

    async uploadMemberDocument(socioId, file, metadata) {
      if (!file || !file.size) throw new Error('Selecciona un documento.');
      if (file.size > 10 * 1024 * 1024) throw new Error('El documento supera 10 MB.');
      if (!/^(image\/(jpeg|png|webp)|application\/pdf)$/i.test(file.type || '')) throw new Error('Solo se admiten imágenes o PDF.');
      if (this.mode === 'demo') {
        const path = await this.fileToDataUrl(file, 10);
        return this.add('documentos', { socio_id: socioId, nombre: metadata?.nombre || file.name, tipo: metadata?.tipo || 'otro', storage_path: path, mime_type: file.type, tamano_bytes: file.size, visible_familia: metadata?.visible_familia !== false });
      }
      const extension = (file.name.split('.').pop() || 'bin').replace(/[^a-z0-9]/gi, '').toLowerCase();
      const path = `${this.session.club_id}/${socioId}/${Date.now()}-${uuid('doc')}.${extension}`;
      await supabase.storageUpload('member-documents', path, file, false);
      try {
        return await this.registerDocumentRecord({ socio_id: socioId, nombre: metadata?.nombre || file.name, tipo: metadata?.tipo || 'otro', storage_path: path, mime_type: file.type, tamano_bytes: file.size, visible_familia: metadata?.visible_familia !== false });
      } catch (error) {
        await supabase.storageRemove('member-documents', path).catch(() => {});
        throw error;
      }
    },

    async getMemberDocumentUrl(path) {
      if (!path) return '';
      if (String(path).startsWith('data:') || String(path).startsWith('http')) return path;
      if (this.mode === 'demo') return path;
      return supabase.storageSignedUrl('member-documents', path, 600);
    },

    async uploadPaymentProof(socioId, file) {
      if (!file || !file.size) return '';
      if (file.size > 5 * 1024 * 1024) throw new Error('El justificante supera 5 MB.');
      if (this.mode === 'demo') return this.fileToDataUrl(file, 5);
      const extension = (file.name.split('.').pop() || 'bin').replace(/[^a-z0-9]/gi, '').toLowerCase();
      const path = `${this.session.club_id}/${socioId}/${Date.now()}-${uuid('proof')}.${extension}`;
      await supabase.storageUpload('justificantes-pago', path, file, false);
      return path;
    },

    async getPaymentProofUrl(path) {
      if (!path) return '';
      if (String(path).startsWith('data:') || String(path).startsWith('http')) return path;
      if (this.mode === 'demo') return path;
      return supabase.storageSignedUrl('justificantes-pago', path, 600);
    },

    async submitPayment(payload) {
      if (this.mode === 'demo') {
        const payment = await this.add('pagos', Object.assign({}, payload, {
          estado_validacion: 'pendiente', comunicado_por: this.session.id,
          comunicado_en: new Date().toISOString(), creado_en: new Date().toISOString()
        }));
        if (payload.cuota_id) await this.update('cuotas', payload.cuota_id, {
          estado: 'pendiente_validacion', pago_comunicado_en: new Date().toISOString(),
          avisos_pausados: true, motivo_pausa_avisos: 'Pago comunicado por el usuario'
        });
        return payment;
      }
      const payment = await this.mutate('pago.comunicar', {
        cuota_id: payload.cuota_id,
        importe: payload.importe,
        fecha: payload.fecha,
        metodo: payload.metodo,
        referencia: payload.referencia || null,
        justificante_path: payload.justificante_url || null,
        observaciones: payload.observaciones || null
      });
      await this.loadRemote();
      return payment;
    },

    async registerAdminPayment(payload) {
      if (this.mode === 'demo') {
        const payment = await this.add('pagos', Object.assign({}, payload, {
          estado_validacion: 'validado', validado_por: this.session.id,
          validado_en: new Date().toISOString(), comunicado_por: this.session.id,
          comunicado_en: new Date().toISOString(), creado_en: new Date().toISOString()
        }));
        return payment;
      }
      const payment = await this.mutate('pago.registrar_admin', {
        cuota_id: payload.cuota_id,
        importe: payload.importe,
        fecha: payload.fecha,
        metodo: payload.metodo,
        referencia: payload.referencia || null,
        observaciones: payload.observaciones || null
      });
      await this.loadRemote();
      return payment;
    },

    async validatePayment(paymentId, decision, reason) {
      if (this.mode === 'demo') {
        const payment = this.data.pagos.find((item) => item.id === paymentId);
        if (!payment) throw new Error('Pago no encontrado.');
        await this.update('pagos', paymentId, {
          estado_validacion: decision,
          validado_en: decision === 'validado' ? new Date().toISOString() : null,
          motivo_rechazo: decision === 'rechazado' ? reason : null,
          rechazado_en: decision === 'rechazado' ? new Date().toISOString() : null
        });
        const fee = this.data.cuotas.find((item) => item.id === payment.cuota_id);
        if (fee) {
          const paid = this.data.pagos.filter((item) => item.cuota_id === fee.id && item.estado_validacion === 'validado')
            .reduce((sum, item) => sum + Number(item.importe), 0);
          await this.update('cuotas', fee.id, {
            estado: paid >= Number(fee.importe) ? 'pagada' : paid > 0 ? 'parcialmente_pagada' : 'pendiente',
            avisos_pausados: decision === 'validado',
            motivo_pausa_avisos: decision === 'validado' ? 'Pago validado' : null
          });
        }
        return payment;
      }
      const payment = await this.mutate('pago.validar', { pago_id: paymentId, decision, motivo: reason || null });
      await this.loadRemote();
      return payment;
    },

    async pauseFeeAlerts(feeId, reason, until) {
      if (this.mode === 'demo') return this.update('cuotas', feeId, { avisos_pausados: true, avisos_pausados_hasta: until || null, motivo_pausa_avisos: reason });
      const result = await this.mutate('cuota.pausar_avisos', { cuota_id: feeId, motivo: reason, hasta: until || null });
      await this.loadRemote();
      return result;
    },

    async resumeFeeAlerts(feeId) {
      if (this.mode === 'demo') return this.update('cuotas', feeId, { avisos_pausados: false, avisos_pausados_hasta: null, motivo_pausa_avisos: null });
      const result = await this.mutate('cuota.reactivar_avisos', { cuota_id: feeId });
      await this.loadRemote();
      return result;
    },

    async saveReminderSettings(settings) {
      if (this.mode === 'demo') {
        Object.assign(this.data.settings, settings, { actualizado_en: new Date().toISOString() });
        await this.persist();
        return this.data.settings;
      }
      await this.mutate('avisos.configurar', {
        dias_aviso: settings.dias_aviso,
        hora_envio: settings.hora_envio || '10:00',
        canal_app: settings.canal_app !== false,
        canal_push: settings.canal_push !== false,
        canal_email: settings.canal_email === true,
        agrupar_por_familia: settings.agrupar_por_familia !== false,
        marcar_vencida_dia: Number(settings.marcar_vencida_dia || 15),
        zona_horaria: settings.zona_horaria || 'Europe/Madrid',
        activo: settings.activo !== false
      });
      await this.loadRemote();
      return this.data.settings;
    },

    async requestAdditionalEnrollment(memberId, disciplineId, groupId, tariffId) {
      if (!memberId || !disciplineId || !groupId) throw new Error('Selecciona alumno, disciplina y grupo.');
      if (this.mode === 'demo') {
        const member = this.data.socios.find((item) => item.id === memberId);
        const enrollment = {
          id: uuid('pre'), club_id: this.data.club.id, solicitante_perfil_id: this.session?.id,
          tipo_solicitud: member?.perfil_id === this.session?.id ? 'adulto' : 'menor',
          nombre: member?.nombre || '', apellidos: member?.apellidos || '', fecha_nacimiento: member?.fecha_nacimiento || null,
          telefono: member?.telefono || '', disciplina_id: disciplineId, grupo_id: groupId,
          tarifa_id: tariffId || null, estado: 'enviada', creado_en: new Date().toISOString()
        };
        this.data.preinscripciones.unshift(enrollment); await this.persist(); return enrollment.id;
      }
      const result = await this.mutate('matricula.solicitar', {
        socio_id: memberId, disciplina_id: disciplineId, grupo_id: groupId, tarifa_id: tariffId || null
      });
      await this.loadRemote();
      return result;
    },

    async deactivateEnrollment(enrollmentId) {
      if (!enrollmentId) throw new Error('Matrícula no válida.');
      if (this.mode === 'demo') {
        const item = this.data.socio_disciplinas.find((entry) => entry.id === enrollmentId);
        if (item) { item.activa = false; item.fecha_fin = new Date().toISOString().slice(0,10); await this.persist(); }
        return item;
      }
      const result = await this.mutate('matricula.desactivar', { matricula_id: enrollmentId });
      await this.loadRemote();
      return result;
    },

    async registerPushToken(token, platform) {
      if (!token || !this.session) return;
      if (this.mode === 'demo') return;
      await this.mutate('push.registrar', { token, plataforma: platform || 'web' });
    },

    async generateFees(period) {
      if (!this.session) throw new AuthExpiredError();
      if (this.mode === 'demo') return { creadas: 0 };
      const result = await this.mutate('cuotas.generar', {
        periodo: period || `${new Date().toISOString().slice(0,7)}-01`
      });
      await this.loadRemote();
      return result;
    },

    async processPaymentReminders(date) {
      if (this.mode !== 'demo') {
        const result = await this.mutate('avisos.procesar', {
          fecha: date || new Date().toISOString().slice(0, 10)
        });
        await this.loadRemote();
        return result;
      }
      const processDate = new Date(`${date || new Date().toISOString().slice(0,10)}T12:00:00`);
      const day = processDate.getDate();
      const days = (this.data.settings.dias_aviso || this.data.settings.dias_avisos_cobro || [1,4,8,11,14]).map(Number);
      const reminderNumber = days.indexOf(day) + 1;
      let generated = 0;
      for (const fee of this.data.cuotas.filter((item) => item.avisos_pausados && item.avisos_pausados_hasta && item.avisos_pausados_hasta < (date || new Date().toISOString().slice(0,10)))) {
        await this.update('cuotas', fee.id, { avisos_pausados: false, avisos_pausados_hasta: null, motivo_pausa_avisos: null, avisos_pausados_por: null, avisos_pausados_en: null });
      }
      if (reminderNumber > 0) {
        const groups = new Map();
        for (const fee of this.data.cuotas.filter((item) => {
          const sameMonth = String(item.periodo).slice(0,7) === processDate.toISOString().slice(0,7);
          return sameMonth && ['pendiente','parcialmente_pagada','vencida'].includes(item.estado) && !item.avisos_pausados;
        })) {
          const member = this.data.socios.find((item) => item.id === fee.socio_id);
          const profileId = member?.tutor_perfil_id || member?.perfil_id;
          if (!profileId) continue;
          const validated = this.data.pagos.filter((item) => item.cuota_id === fee.id && item.estado_validacion === 'validado')
            .reduce((sum,item) => sum + Number(item.importe), 0);
          const saldo = Math.max(Number(fee.importe) - validated, 0);
          if (!saldo) continue;
          const groupKey = this.data.settings.agrupar_por_familia === false ? `${profileId}:${fee.id}` : profileId;
          const entry = groups.get(groupKey) || { profileId, groupKey, fees: [], names: [], total: 0 };
          entry.fees.push(fee); entry.names.push(member.nombre); entry.total += saldo;
          groups.set(groupKey, entry);
        }
        for (const entry of groups.values()) {
          const key = `cobro-${processDate.toISOString().slice(0,7)}-aviso-${reminderNumber}-${entry.groupKey}`;
          if (this.data.notificaciones.some((item) => item.clave === key)) continue;
          const titles = ['Mensualidad disponible','Recordatorio de mensualidad','Mensualidad pendiente','Regulariza antes del día 15','Último recordatorio antes del día 15'];
          const notification = await this.add('notificaciones', {
            perfil_id: entry.profileId, clave: key, tipo: 'cuota', titulo: titles[reminderNumber-1],
            cuerpo: entry.fees.length > 1
              ? `Tienes ${entry.fees.length} mensualidades pendientes (${entry.names.join(', ')}) por un total de ${entry.total.toFixed(2)} €.`
              : `${entry.names[0]}: mensualidad pendiente por ${entry.total.toFixed(2)} €.` ,
            ruta: 'fees', datos: { aviso_numero: reminderNumber, cuotas: entry.fees.map((item) => item.id), total: entry.total },
            leida: false, creado_en: new Date().toISOString()
          });
          for (const fee of entry.fees) {
            await this.add('historial_avisos_cuota', {
              cuota_id: fee.id, perfil_id: entry.profileId, aviso_numero: reminderNumber,
              fecha_programada: date || new Date().toISOString().slice(0,10), canal: 'app',
              estado: 'enviado', notificacion_id: notification.id, enviado_en: new Date().toISOString()
            });
            generated += 1;
          }
        }
      }
      const overdueDay = Number(this.data.settings.marcar_vencida_dia || 15);
      if (day >= overdueDay) {
        for (const fee of this.data.cuotas.filter((item) => String(item.periodo).slice(0,7) === processDate.toISOString().slice(0,7) && ['pendiente','parcialmente_pagada'].includes(item.estado) && !item.avisos_pausados)) {
          await this.update('cuotas', fee.id, { estado: 'vencida' });
        }
      }
      return { fecha: date, avisos_generados: generated };
    },

    async resetDemo() {
      localStorage.removeItem(STORAGE_KEY);
      localStorage.removeItem(SESSION_KEY);
      this.session = null;
      this.data = readDemo();
      return this.data;
    }
  };

  window.UW_STORE = store;
  window.UW_AUTH_EXPIRED_ERROR = AuthExpiredError;
})();

