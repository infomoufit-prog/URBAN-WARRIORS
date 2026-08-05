(function () {
  'use strict';

  const STORAGE_KEY = 'uw_phase1_data_v2';
  const SESSION_KEY = 'uw_phase1_session_v2';
  const COLLECTIONS = [
    'accounts','disciplinas','grados','grupos','horarios','socios','preinscripciones','tarifas','cuotas','pagos',
    'sesiones','asistencias','registros_acceso','comunicaciones','seguimiento','consentimientos','material',
    'material_variantes','pedidos_material','notificaciones','historial_avisos_cuota'
  ];

  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function uuid(prefix) { return `${prefix || 'id'}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`; }

  function normalizeDemo(data) {
    const seed = clone(window.UW_DEMO_SEED);
    const result = Object.assign(seed, data || {});
    result.club = Object.assign(seed.club, data?.club || {});
    result.users = Object.assign(seed.users, data?.users || {});
    result.settings = Object.assign(seed.settings, data?.settings || {});
    for (const key of COLLECTIONS) result[key] = Array.isArray(data?.[key]) ? data[key] : seed[key] || [];
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

  class SupabaseLite {
    constructor(config) {
      this.url = (config.url || '').replace(/\/$/, '');
      this.anonKey = config.anonKey || '';
      this.session = JSON.parse(localStorage.getItem('uw_supabase_session') || 'null');
    }
    enabled() { return Boolean(this.url && this.anonKey); }
    headers(extra) {
      return Object.assign({
        apikey: this.anonKey,
        Authorization: `Bearer ${(this.session && this.session.access_token) || this.anonKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation'
      }, extra || {});
    }
    async request(path, options) {
      const response = await fetch(`${this.url}${path}`, Object.assign({}, options, { headers: this.headers(options && options.headers) }));
      const text = await response.text();
      let body = null;
      if (text) { try { body = JSON.parse(text); } catch (_) { body = text; } }
      if (!response.ok) {
        const message = body && (body.message || body.error_description || body.hint) || `Error HTTP ${response.status}`;
        throw new Error(message);
      }
      return body;
    }
    async signIn(email, password) {
      const body = await this.request('/auth/v1/token?grant_type=password', { method: 'POST', body: JSON.stringify({ email, password }) });
      this.session = body;
      localStorage.setItem('uw_supabase_session', JSON.stringify(body));
      return body;
    }
    async signUp(email, password, metadata) {
      const body = await this.request('/auth/v1/signup', { method: 'POST', body: JSON.stringify({ email, password, data: metadata || {} }) });
      if (body && body.access_token) {
        this.session = body;
        localStorage.setItem('uw_supabase_session', JSON.stringify(body));
      }
      return body;
    }
    async signOut() {
      if (this.session) { try { await this.request('/auth/v1/logout', { method: 'POST' }); } catch (_) {} }
      this.session = null;
      localStorage.removeItem('uw_supabase_session');
    }
    async select(table, query) { return this.request(`/rest/v1/${table}?${query || 'select=*'}`, { method: 'GET' }); }
    async insert(table, payload) { return this.request(`/rest/v1/${table}`, { method: 'POST', body: JSON.stringify(payload) }); }
    async update(table, id, payload) { return this.request(`/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify(payload) }); }
    async updateWhere(table, column, value, payload) { return this.request(`/rest/v1/${table}?${encodeURIComponent(column)}=eq.${encodeURIComponent(value)}`, { method: 'PATCH', body: JSON.stringify(payload) }); }
    async remove(table, id) { return this.request(`/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, { method: 'DELETE' }); }
    async rpc(name, payload) { return this.request(`/rest/v1/rpc/${name}`, { method: 'POST', body: JSON.stringify(payload || {}) }); }
    async storageUpload(bucket, path, file) {
      const response = await fetch(`${this.url}/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`, {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          Authorization: `Bearer ${(this.session && this.session.access_token) || this.anonKey}`,
          'Content-Type': file.type || 'application/octet-stream',
          'x-upsert': 'false'
        },
        body: file
      });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(body.message || body.error || `Error al subir archivo (${response.status})`);
      return body;
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
    registros_acceso: 'registros_acceso_clase'
  };

  const store = {
    mode: config.demoMode || !config.supabase.enabled ? 'demo' : 'supabase',
    session: JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'),
    data: null,

    async init() {
      if (this.mode === 'demo') { this.data = readDemo(); return this.data; }
      if (!supabase.enabled()) throw new Error('Supabase no está configurado. Activa demoMode o añade URL y anonKey.');
      if (supabase.session && this.session) await this.loadRemote();
      else await this.loadPublicCatalog();
      return this.data;
    },

    getSession() { return this.session; },

    async loginDemo(role) {
      const user = this.data.users[role];
      if (!user) throw new Error('Rol de demostración no válido.');
      this.session = Object.assign({ mode: 'demo', club_id: this.data.club.id }, clone(user));
      localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      return this.session;
    },

    async login(email, password) {
      if (this.mode === 'demo') {
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
        await supabase.rpc('registrar_cuenta_club', {
          p_club_slug: config.clubSlug, p_tipo_cuenta: pending.tipo_cuenta,
          p_adulto_nombre: pending.adulto_nombre, p_adulto_apellidos: pending.adulto_apellidos,
          p_telefono: pending.telefono, p_fecha_nacimiento_adulto: pending.adulto_fecha_nacimiento || null,
          p_menor_nombre: pending.menor_nombre || null, p_menor_apellidos: pending.menor_apellidos || null,
          p_fecha_nacimiento_menor: pending.menor_fecha_nacimiento || null,
          p_disciplina_id: pending.disciplina_id || null, p_grupo_id: pending.grupo_id || null,
          p_tarifa_id: pending.tarifa_id || null
        });
        localStorage.removeItem('uw_pending_registration');
      }
      const memberships = await supabase.select('miembros_club', `select=club_id,rol,clubes(id,nombre,slug,logo_url,color_primario,color_secundario)&perfil_id=eq.${userId}&activo=eq.true&limit=1`);
      if (!memberships || !memberships.length) throw new Error('El usuario no pertenece a ningún club activo.');
      const membership = memberships[0];
      this.session = {
        mode: 'supabase', id: userId, email: auth.user.email,
        nombre: auth.user.user_metadata?.nombre || auth.user.email,
        apellidos: auth.user.user_metadata?.apellidos || '', rol: membership.rol, club_id: membership.club_id, socio_ids: []
      };
      localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      await this.loadRemote();
      return this.session;
    },

    async registerAccount(payload) {
      const type = payload.tipo_cuenta;
      if (!['adulto', 'tutor'].includes(type)) throw new Error('Tipo de registro no válido.');
      if (this.mode === 'demo') {
        if (this.data.accounts.some((item) => item.email.toLowerCase() === payload.email.toLowerCase())) throw new Error('Ya existe una cuenta con este correo.');
        const userId = uuid('usr');
        const userKey = uuid('account');
        const role = type === 'adulto' ? 'alumno' : 'familia';
        const socioId = uuid('so');
        const user = {
          id: userId, nombre: payload.adulto_nombre, apellidos: payload.adulto_apellidos,
          rol: role, email: payload.email, telefono: payload.telefono, socio_ids: [socioId]
        };
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
        this.data.notificaciones.unshift({
          id: uuid('no'), perfil_id: userId, tipo: 'inscripcion', titulo: 'Solicitud enviada',
          cuerpo: 'Urban Warriors revisará la inscripción y te avisará desde la aplicación.', ruta: 'home', leida: false,
          creado_en: new Date().toISOString()
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
      const result = await supabase.rpc('registrar_cuenta_club', {
        p_club_slug: config.clubSlug, p_tipo_cuenta: type,
        p_adulto_nombre: payload.adulto_nombre, p_adulto_apellidos: payload.adulto_apellidos,
        p_telefono: payload.telefono, p_fecha_nacimiento_adulto: payload.adulto_fecha_nacimiento || null,
        p_menor_nombre: payload.menor_nombre || null, p_menor_apellidos: payload.menor_apellidos || null,
        p_fecha_nacimiento_menor: payload.menor_fecha_nacimiento || null,
        p_disciplina_id: payload.disciplina_id || null, p_grupo_id: payload.grupo_id || null,
        p_tarifa_id: payload.tarifa_id || null
      });
      await this.login(payload.email, payload.password);
      return { session: this.session, result, confirmationRequired: false };
    },

    async logout() {
      if (this.mode === 'supabase') await supabase.signOut();
      this.session = null;
      localStorage.removeItem(SESSION_KEY);
    },

    async loadPublicCatalog() {
      const clubs = await supabase.select('clubes', `select=*&slug=eq.${encodeURIComponent(config.clubSlug)}&activo=eq.true&limit=1`);
      const club = clubs?.[0];
      if (!club) throw new Error('El club no está disponible.');
      const clubId = club.id;
      const [disciplinas, grupos, horarios, tarifas] = await Promise.all([
        supabase.select('disciplinas', `select=*&club_id=eq.${clubId}&activa=eq.true&order=orden`),
        supabase.select('grupos', `select=*&club_id=eq.${clubId}&activo=eq.true`),
        supabase.select('horarios_grupo', `select=*&club_id=eq.${clubId}`),
        supabase.select('tarifas', `select=*&club_id=eq.${clubId}&activa=eq.true`)
      ]);
      this.data = {
        club, users: {}, accounts: [], disciplinas, grados: [], grupos, horarios, socios: [],
        preinscripciones: [], tarifas, cuotas: [], pagos: [], sesiones: [], asistencias: [],
        registros_acceso: [], comunicaciones: [], seguimiento: [], consentimientos: [], material: [],
        material_variantes: [], pedidos_material: [], notificaciones: [], historial_avisos_cuota: [], settings: { dias_aviso: [1,4,8,11,14], dias_avisos_cobro: [1,4,8,11,14] }
      };
      return this.data;
    },

    async loadRemote() {
      if (!this.session) return;
      const clubId = this.session.club_id;
      const [club, disciplinas, grados, grupos, horarios, socios, preinscripciones, tarifas, cuotas, pagos, sesiones, asistencias, accesos, comunicaciones, seguimiento, consentimientos, material, variantes, pedidos, notificaciones, configAvisos, historialAvisos] = await Promise.all([
        supabase.select('clubes', `select=*&id=eq.${clubId}&limit=1`),
        supabase.select('disciplinas', `select=*&club_id=eq.${clubId}&order=orden`),
        supabase.select('grados', `select=*&club_id=eq.${clubId}&order=orden`),
        supabase.select('grupos', `select=*&club_id=eq.${clubId}&activo=eq.true`),
        supabase.select('horarios_grupo', `select=*&club_id=eq.${clubId}`),
        supabase.select('socios', `select=*&club_id=eq.${clubId}&order=apellidos,nombre`),
        supabase.select('preinscripciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`),
        supabase.select('tarifas', `select=*&club_id=eq.${clubId}&activa=eq.true`),
        supabase.select('cuotas', `select=*&club_id=eq.${clubId}&order=vencimiento.desc`),
        supabase.select('pagos', `select=*&club_id=eq.${clubId}&order=fecha.desc`),
        supabase.select('sesiones_entrenamiento', `select=*&club_id=eq.${clubId}&order=fecha.desc`),
        supabase.select('asistencias', `select=*&club_id=eq.${clubId}`),
        supabase.select('registros_acceso_clase', `select=*&club_id=eq.${clubId}&order=registrado_en.desc`),
        supabase.select('comunicaciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`),
        supabase.select('seguimiento', `select=*&club_id=eq.${clubId}&order=fecha.desc`),
        supabase.select('consentimientos', `select=*&club_id=eq.${clubId}`),
        supabase.select('material_catalogo', `select=*&club_id=eq.${clubId}&activo=eq.true`),
        supabase.select('material_variantes', `select=*&club_id=eq.${clubId}&activa=eq.true`),
        supabase.select('material_pedidos', `select=*&club_id=eq.${clubId}&order=creado_en.desc`),
        supabase.select('notificaciones', `select=*&club_id=eq.${clubId}&order=creado_en.desc`),
        supabase.select('configuracion_avisos_cuota', `select=*&club_id=eq.${clubId}&limit=1`),
        supabase.select('historial_avisos_cuota', `select=*&club_id=eq.${clubId}&order=fecha_programada.desc&limit=250`)
      ]);
      this.data = {
        club: club[0], users: {}, accounts: [], disciplinas, grados, grupos, horarios, socios,
        preinscripciones, tarifas, cuotas, pagos, sesiones, asistencias, registros_acceso: accesos,
        comunicaciones, seguimiento, consentimientos, material, material_variantes: variantes,
        pedidos_material: pedidos, notificaciones, historial_avisos_cuota: historialAvisos, settings: Object.assign({ dias_aviso: [1,4,8,11,14], dias_avisos_cobro: [1,4,8,11,14] }, configAvisos?.[0] || {})
      };
      if (['familia', 'alumno'].includes(this.session.rol)) {
        this.session.socio_ids = socios.map((item) => item.id);
        localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
      }
    },

    getData() { return this.data; },
    async persist() { if (this.mode === 'demo') saveDemo(this.data); },

    async add(collection, payload) {
      if (!this.data[collection]) throw new Error(`Colección desconocida: ${collection}`);
      if (this.mode === 'demo') {
        const item = Object.assign({ id: uuid(collection.slice(0, 2)), club_id: this.data.club.id }, payload);
        this.data[collection].unshift(item);
        await this.persist();
        return item;
      }
      const table = tableMap[collection] || collection;
      const rows = await supabase.insert(table, Object.assign({ club_id: this.session.club_id }, payload));
      const item = rows[0];
      this.data[collection].unshift(item);
      return item;
    },

    async update(collection, id, changes) {
      const item = this.data[collection].find((entry) => entry.id === id);
      if (!item) throw new Error('Registro no encontrado.');
      if (this.mode === 'demo') {
        Object.assign(item, changes, { actualizado_en: new Date().toISOString() });
        await this.persist();
        return item;
      }
      const table = tableMap[collection] || collection;
      const rows = await supabase.update(table, id, changes);
      Object.assign(item, rows[0] || changes);
      return item;
    },

    async remove(collection, id) {
      if (this.mode === 'demo') {
        this.data[collection] = this.data[collection].filter((entry) => entry.id !== id);
        await this.persist();
        return;
      }
      const table = tableMap[collection] || collection;
      await supabase.remove(table, id);
      this.data[collection] = this.data[collection].filter((entry) => entry.id !== id);
    },

    async rpc(name, payload) {
      if (this.mode === 'demo') throw new Error('Esta operación RPC solo se ejecuta con Supabase.');
      return supabase.rpc(name, payload || {});
    },

    async uploadPaymentProof(socioId, file) {
      if (!file || !file.size) return '';
      if (file.size > 5 * 1024 * 1024) throw new Error('El justificante supera 5 MB.');
      if (this.mode === 'demo') {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = () => reject(new Error('No se pudo leer el justificante.'));
          reader.readAsDataURL(file);
        });
      }
      const extension = (file.name.split('.').pop() || 'bin').replace(/[^a-z0-9]/gi, '').toLowerCase();
      const path = `${this.session.club_id}/${socioId}/${Date.now()}-${uuid('proof')}.${extension}`;
      await supabase.storageUpload('justificantes-pago', path, file);
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
      const payment = await supabase.rpc('comunicar_pago_cuota', {
        p_cuota_id: payload.cuota_id,
        p_importe: payload.importe,
        p_fecha: payload.fecha,
        p_metodo: payload.metodo,
        p_referencia: payload.referencia || null,
        p_justificante_path: payload.justificante_url || null,
        p_observaciones: payload.observaciones || null
      });
      await this.loadRemote();
      return Array.isArray(payment) ? payment[0] : payment;
    },

    async registerAdminPayment(payload) {
      if (this.mode === 'demo') {
        const payment = await this.add('pagos', Object.assign({}, payload, {
          estado_validacion: 'validado', validado_por: this.session.id,
          validado_en: new Date().toISOString(), comunicado_por: this.session.id,
          comunicado_en: new Date().toISOString(), creado_en: new Date().toISOString()
        }));
        const fee = this.data.cuotas.find((item) => item.id === payload.cuota_id);
        if (fee) {
          const paid = this.data.pagos.filter((item) => item.cuota_id === fee.id && item.estado_validacion === 'validado')
            .reduce((sum, item) => sum + Number(item.importe), 0);
          await this.update('cuotas', fee.id, {
            estado: paid >= Number(fee.importe) ? 'pagada' : 'parcialmente_pagada',
            avisos_pausados: true, motivo_pausa_avisos: 'Cobro registrado'
          });
        }
        return payment;
      }
      const payment = await supabase.rpc('registrar_cobro_cuota', {
        p_cuota_id: payload.cuota_id,
        p_importe: payload.importe,
        p_fecha: payload.fecha,
        p_metodo: payload.metodo,
        p_referencia: payload.referencia || null,
        p_observaciones: payload.observaciones || null
      });
      await this.loadRemote();
      return Array.isArray(payment) ? payment[0] : payment;
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
      const payment = await supabase.rpc('validar_pago_cuota', {
        p_pago_id: paymentId, p_decision: decision, p_motivo: reason || null
      });
      await this.loadRemote();
      return Array.isArray(payment) ? payment[0] : payment;
    },

    async pauseFeeAlerts(feeId, reason, until) {
      if (this.mode === 'demo') return this.update('cuotas', feeId, {
        avisos_pausados: true, avisos_pausados_hasta: until || null,
        motivo_pausa_avisos: reason, avisos_pausados_por: this.session.id,
        avisos_pausados_en: new Date().toISOString()
      });
      const result = await supabase.rpc('pausar_avisos_cuota', {
        p_cuota_id: feeId, p_motivo: reason, p_hasta: until || null
      });
      await this.loadRemote();
      return Array.isArray(result) ? result[0] : result;
    },

    async resumeFeeAlerts(feeId) {
      if (this.mode === 'demo') return this.update('cuotas', feeId, {
        avisos_pausados: false, avisos_pausados_hasta: null,
        motivo_pausa_avisos: null, avisos_pausados_por: null, avisos_pausados_en: null
      });
      const result = await supabase.rpc('reactivar_avisos_cuota', { p_cuota_id: feeId });
      await this.loadRemote();
      return Array.isArray(result) ? result[0] : result;
    },

    async saveReminderSettings(settings) {
      if (this.mode === 'demo') {
        Object.assign(this.data.settings, settings, { actualizado_en: new Date().toISOString() });
        await this.persist();
        return this.data.settings;
      }
      const existing = await supabase.select('configuracion_avisos_cuota', `select=club_id&club_id=eq.${this.session.club_id}&limit=1`);
      const payload = Object.assign({ club_id: this.session.club_id, actualizado_por: this.session.id, actualizado_en: new Date().toISOString() }, settings);
      if (existing?.length) await supabase.updateWhere('configuracion_avisos_cuota', 'club_id', this.session.club_id, payload);
      else await supabase.insert('configuracion_avisos_cuota', payload);
      await this.loadRemote();
      return this.data.settings;
    },

    async registerPushToken(token, platform) {
      if (!token || !this.session) return;
      if (this.mode === 'demo') {
        const tokens = JSON.parse(localStorage.getItem('uw_demo_push_tokens') || '[]');
        if (!tokens.includes(token)) tokens.push(token);
        localStorage.setItem('uw_demo_push_tokens', JSON.stringify(tokens));
        return;
      }
      const query = `select=id&club_id=eq.${this.session.club_id}&perfil_id=eq.${this.session.id}&token=eq.${encodeURIComponent(token)}&limit=1`;
      const existing = await supabase.select('dispositivos_push', query);
      if (existing?.length) await supabase.update('dispositivos_push', existing[0].id, { activo: true, ultimo_uso: new Date().toISOString() });
      else await supabase.insert('dispositivos_push', {
        club_id: this.session.club_id, perfil_id: this.session.id,
        plataforma: platform || 'web', token, activo: true
      });
    },

    async processPaymentReminders(date) {
      if (this.mode !== 'demo') {
        const result = await supabase.rpc('procesar_avisos_cobro_club', {
          p_club_id: this.session.club_id, p_fecha: date || new Date().toISOString().slice(0, 10)
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
          return sameMonth && ['pendiente','parcialmente_pagada','vencida'].includes(item.estado)
            && !item.avisos_pausados;
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
              : `${entry.names[0]}: mensualidad pendiente por ${entry.total.toFixed(2)} €.`,
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
})();
