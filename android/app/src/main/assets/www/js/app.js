(function () {
  'use strict';

  const app = document.getElementById('app');
  const store = window.UW_STORE;
  const config = window.UW_CONFIG;
  const state = { route: 'home', query: '', selectedSession: null, selectedMemberId: null, registrationType: null };
  const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  const escapeHtml = (value) => String(value ?? '')
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  const money = (value) => new Intl.NumberFormat(config.locale || 'es-ES', { style: 'currency', currency: config.currency || 'EUR' }).format(Number(value || 0));
  const dateText = (value) => {
    if (!value) return '—';
    const date = new Date(`${String(value).slice(0, 10)}T12:00:00`);
    return new Intl.DateTimeFormat(config.locale || 'es-ES', { day: '2-digit', month: 'short', year: 'numeric' }).format(date);
  };
  const dateTimeText = (value) => value ? new Intl.DateTimeFormat(config.locale || 'es-ES', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) : '—';
  const initials = (name) => String(name || 'UW').split(/\s+/).filter(Boolean).map((part) => part[0]).join('').slice(0, 2).toUpperCase();
  const byId = (items, id) => (items || []).find((item) => item.id === id);
  const value = (form, name) => new FormData(form).get(name)?.toString().trim() || '';
  const todayIso = () => new Date().toISOString().slice(0, 10);
  const ageFromDate = (date) => date ? Math.floor((Date.now() - new Date(date).getTime()) / 31557600000) : null;

  function toast(message, type) {
    const region = document.getElementById('toast-region');
    const el = document.createElement('div');
    el.className = `toast ${type || ''}`;
    el.textContent = message;
    region.appendChild(el);
    setTimeout(() => el.remove(), 3600);
  }


  function setFormBusy(form, busy) {
    if (!form) return;
    form.setAttribute('aria-busy', busy ? 'true' : 'false');
    form.querySelectorAll('button').forEach((control) => {
      if (busy) {
        control.dataset.wasDisabled = control.disabled ? '1' : '0';
        control.disabled = true;
      } else if (control.dataset.wasDisabled !== '1') {
        control.disabled = false;
        delete control.dataset.wasDisabled;
      }
    });
  }

  async function handleOperationError(error, form) {
    console.error(error);
    if (error?.code === 'AUTH_EXPIRED' || /sesión ha caducado|jwt expired/i.test(String(error?.message || ''))) {
      await store.logout().catch(() => {});
      toast('Tu sesión ha caducado. Inicia sesión de nuevo.', 'error');
      go('home');
      render();
      return;
    }
    const message = error?.message || 'No se pudo completar la operación';
    const errorBox = form?.querySelector?.('[data-form-error]');
    if (errorBox) {
      errorBox.hidden = false;
      errorBox.textContent = `No se ha guardado: ${message}`;
      errorBox.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
    toast(message, 'error');
  }

  function statusBadge(status) {
    const labels = {
      activo: 'Activo', inactivo: 'Inactivo', prealta: 'Pendiente de aprobación', baja: 'Baja', suspendido: 'Suspendido',
      pagada: 'Pagada', pendiente: 'Pendiente', pendiente_validacion: 'Pago comunicado', aplazada: 'Aplazada', vencida: 'Vencida', parcialmente_pagada: 'Pago parcial', anulada: 'Anulada', exenta: 'Exenta',
      publicada: 'Publicada', programada: 'Programada', borrador: 'Borrador', archivada: 'Archivada', en_revision: 'En revisión', enviada: 'Enviada',
      pendiente_documentacion: 'Falta documentación', aprobada: 'Aprobada', rechazada: 'Rechazada', lista_espera: 'Lista de espera',
      presente: 'Presente', ausente: 'Ausente', ausencia_justificada: 'Justificada', retraso: 'Retraso',
      direccion: 'Dirección', secretaria: 'Secretaría', economia: 'Economía', comunicacion: 'Comunicación', monitor: 'Monitor', familia: 'Familia', alumno: 'Alumno',
      validado: 'Validado', reservado: 'Reservado', preparado: 'Preparado', entregado: 'Entregado', cancelado: 'Cancelado', permitido: 'Acceso registrado'
    };
    const cls = ['pagada', 'activo', 'aprobada', 'publicada', 'presente', 'validado', 'entregado', 'permitido'].includes(status) ? 'success'
      : ['vencida', 'rechazada', 'ausente', 'cancelado'].includes(status) ? 'danger'
      : ['pendiente', 'pendiente_validacion', 'aplazada', 'prealta', 'pendiente_documentacion', 'programada', 'ausencia_justificada', 'reservado', 'preparado', 'parcialmente_pagada'].includes(status) ? 'warning' : 'info';
    return `<span class="badge ${cls}">${escapeHtml(labels[status] || status || '—')}</span>`;
  }

  function getRoute() { return location.hash.replace(/^#\/?/, '').split('?')[0] || 'home'; }
  function go(route) { location.hash = `#/${route}`; }
  function currentUser() { return store.getSession(); }
  function data() { return store.getData(); }
  function isAdmin() { return ['direccion', 'secretaria', 'economia', 'comunicacion'].includes(currentUser()?.rol); }
  function canManageFinance() { return ['direccion', 'secretaria', 'economia'].includes(currentUser()?.rol); }
  // CORRECCIÓN 1.6.1: isAdmin() incluye economia y comunicacion, pero las RPC de
  // catálogo (app_guardar_disciplina / _grado / _grupo / _socio) solo aceptan
  // direccion y secretaria. Sin esta distinción, esos dos roles veían los botones
  // de "Nueva disciplina" o "Crear grupo" y recibían siempre
  // "No tienes permiso para gestionar disciplinas" al guardar.
  // ---------------------------------------------------------------------------
  // PUNTO ÚNICO DE DECISIÓN DEL CATÁLOGO (build 14)
  // Disciplinas, grados y grupos solo los modifican Dirección y Secretaría, que
  // es exactamente lo que aceptan app_guardar_disciplina, app_guardar_grado y
  // app_guardar_grupo. Ninguna pantalla vuelve a comprobar roles por su cuenta:
  // todas envuelven sus controles en catalogControl() y el despachador de clics
  // bloquea las mismas acciones aunque un control llegase a renderizarse.
  // ---------------------------------------------------------------------------
  function canManageCatalog() { return ['direccion', 'secretaria'].includes(currentUser()?.rol); }
  const CATALOG_ACTIONS = ['open-discipline-form', 'open-grade-form', 'open-group-form'];
  const CATALOG_DATASET_KEYS = ['editDiscipline', 'toggleDiscipline', 'addGrade', 'editGrade', 'editGroup'];
  function catalogControl(html) { return canManageCatalog() ? html : ''; }
  function isCatalogTarget(target) {
    if (!target) return false;
    if (target.dataset.action && CATALOG_ACTIONS.includes(target.dataset.action)) return true;
    return CATALOG_DATASET_KEYS.some((key) => target.dataset[key]);
  }
  function isMonitor() { return currentUser()?.rol === 'monitor'; }
  function isMemberPortal() { return ['familia', 'alumno'].includes(currentUser()?.rol); }

  function familyMembers() {
    if (!isMemberPortal()) return [];
    const ids = currentUser()?.socio_ids || [];
    const linked = data().socios.filter((item) => ids.includes(item.id));
    if (linked.length) return linked;
    if (currentUser()?.rol === 'alumno') return data().socios.filter((item) => item.perfil_id === currentUser().id);
    return data().socios.filter((item) => item.tutor_perfil_id === currentUser().id);
  }

  function memberEnrollments(member) {
    if (!member) return [];
    if (Array.isArray(member.matriculas)) return member.matriculas.filter((item) => item.activa !== false);
    return (data().socio_disciplinas || []).filter((item) => item.socio_id === member.id && item.activa !== false);
  }

  function memberGroupIds(member) {
    return [...new Set(memberEnrollments(member).map((item) => item.grupo_id).filter(Boolean))];
  }

  function memberDisciplineIds(member) {
    return [...new Set(memberEnrollments(member).map((item) => item.disciplina_id).filter(Boolean))];
  }

  function memberInGroup(member, groupId) {
    return Boolean(groupId && memberGroupIds(member).includes(groupId));
  }

  function memberSportsText(member) {
    const enrollments = memberEnrollments(member);
    if (!enrollments.length) return 'Sin matrícula deportiva';
    return enrollments.map((item) => {
      const discipline = byId(data().disciplinas, item.disciplina_id);
      const group = byId(data().grupos, item.grupo_id);
      return [discipline?.nombre, group?.nombre].filter(Boolean).join(' · ');
    }).filter(Boolean).join(' / ');
  }

  function selectedMember() {
    const members = familyMembers();
    if (!members.length) return null;
    if (!state.selectedMemberId || !members.some((item) => item.id === state.selectedMemberId)) state.selectedMemberId = members[0].id;
    return byId(members, state.selectedMemberId);
  }

  function visibleNotifications() {
    const user = currentUser();
    if (!user) return [];
    return (data().notificaciones || []).filter((item) => {
      if (item.perfil_id) return item.perfil_id === user.id;
      if (item.rol_destino) return (user.roles || [user.rol]).includes(item.rol_destino) || (item.rol_destino === 'familia' && isMemberPortal());
      return item.audiencia === 'todos';
    });
  }

  function topbar(title, subtitle) {
    const user = currentUser();
    const club = data().club;
    const unread = visibleNotifications().filter((item) => !item.leida).length;
    return `<header class="topbar">
      <div class="topbar-brand"><img class="topbar-logo" src="${escapeHtml(club.logo_url || config.brand.logo)}" alt="Logo ${escapeHtml(club.nombre)}" /><div class="topbar-title"><h1>${escapeHtml(title || club.nombre)}</h1><p>${escapeHtml(subtitle || `${user.nombre} · ${user.rol}`)}</p></div></div>
      <div class="topbar-actions"><button class="icon-btn notification-button" type="button" data-route="notifications" aria-label="Notificaciones">♢${unread ? `<span class="notification-count">${unread}</span>` : ''}</button><button class="avatar" type="button" data-action="profile" aria-label="Abrir perfil">${escapeHtml(initials(user.nombre))}</button></div>
    </header>`;
  }

  function navItems() {
    if (isMemberPortal()) return [['home', '⌂', 'Inicio'], ['schedule', '◷', 'Horarios'], ['fees', '€', 'Cuotas'], ['communications', '✦', 'Avisos'], ['profile', '○', 'Perfil']];
    if (isMonitor()) return [['home', '⌂', 'Hoy'], ['groups', '◉', 'Grupos'], ['attendance', '✓', 'Asistencia'], ['progress', '↗', 'Seguimiento'], ['profile', '○', 'Perfil']];
    return [['home', '⌂', 'Inicio'], ['members', '◎', 'Socios'], ['schedule', '◷', 'Clases'], ['fees', '€', 'Finanzas'], ['more', '•••', 'Más']];
  }

  function bottomNav() {
    return `<nav class="bottom-nav" aria-label="Navegación principal">${navItems().map(([route, icon, label]) => `<button class="nav-btn ${state.route === route ? 'active' : ''}" type="button" data-route="${route}"><span class="nav-icon">${icon}</span><span>${label}</span></button>`).join('')}</nav>`;
  }
  // CORRECCIÓN 1.6.1: store.writeBlockedReason, store.loadErrors y
  // store.runFinalDiagnostic() existían desde 1.6.0 pero ninguna pantalla los
  // mostraba. El único canal de error era un toast de 3,6 segundos, así que un
  // backend sin la puerta de escritura instalada resultaba indistinguible de un
  // "no se guarda" sin causa. Este aviso es persistente y literal.
  function systemBanner() {
    const blocked = store.writeBlockedReason;
    const failures = (store.loadErrors || []).map((item) => item.table);
    if (!blocked && !failures.length) return '';
    if (blocked) {
      return `<div class="form-error" role="alert" style="margin:12px 0">
        <strong>El guardado está bloqueado por el servidor.</strong>
        <div style="margin-top:6px">${escapeHtml(blocked)}</div>
        <div style="margin-top:6px" class="list-subtitle">Ejecuta las migraciones 015, 016 y 017 en Supabase y vuelve a intentarlo.</div>
        <button class="btn btn-small btn-secondary" style="margin-top:10px" data-action="run-diagnostic">Reintentar diagnóstico</button>
      </div>`;
    }
    return `<div class="form-error" role="alert" style="margin:12px 0">
      <strong>Datos incompletos.</strong>
      <div style="margin-top:6px">No se han podido leer: ${escapeHtml([...new Set(failures)].join(', '))}. Lo que ves en pantalla puede no estar completo.</div>
    </div>`;
  }

  function renderShell(content) { app.innerHTML = `<div class="app-shell authenticated"><main class="page">${systemBanner()}${content}</main>${bottomNav()}</div>`; }

  function renderLogin(staffOnly) {
    const title = staffOnly ? 'Acceso del equipo' : 'Accede a Urban Warriors';
    app.innerHTML = `<main class="login-page"><section class="login-card">
      <div class="brand-lockup"><img class="brand-logo" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><h1 class="brand-title">${escapeHtml(config.brand.name)}</h1><p class="brand-slogan">${escapeHtml(config.brand.slogan)}</p></div>
      <div class="panel login-panel"><h2>${title}</h2><p>${staffOnly ? 'El personal accede mediante una cuenta creada o invitada por el gimnasio.' : 'Horarios, asistencia, mensualidades, material y avisos desde el móvil.'}</p>
        <form id="login-form"><div class="field"><label for="email">Correo electrónico</label><input class="input" id="email" name="email" type="email" autocomplete="email" placeholder="nombre@correo.com" required /></div><div class="field"><label for="password">Contraseña</label><input class="input" id="password" name="password" type="password" autocomplete="current-password" placeholder="••••••••" required /></div><button class="btn btn-primary btn-block" type="submit">Entrar</button></form>
        ${!staffOnly ? `<div class="auth-actions"><button class="btn btn-secondary btn-block" data-route="register">Crear una cuenta o inscribirme</button><button class="btn btn-ghost btn-block" data-route="staff">Acceso del personal</button></div>` : `<button class="btn btn-ghost btn-block" style="margin-top:12px" data-route="home">Volver al acceso general</button>`}
        ${store.mode === 'demo' ? `<div class="demo-divider">Probar la aplicación</div><div class="demo-grid"><button class="demo-role" data-demo-role="admin"><strong>⌂</strong><span>Dirección</span></button><button class="demo-role" data-demo-role="monitor"><strong>✓</strong><span>Monitor</span></button><button class="demo-role" data-demo-role="family"><strong>◎</strong><span>Familia</span></button></div><div class="mode-note">Contraseña demo: demo1234. Los cambios se guardan en este dispositivo.</div>` : ''}
        <button class="btn btn-ghost btn-block" style="margin-top:12px" data-route="download">Descarga e instalación</button>
      </div></section></main>`;
  }

  function renderRegisterChoice() {
    app.innerHTML = `<main class="login-page"><section class="login-card panel registration-panel"><button class="back-link" data-route="home">‹ Volver</button><img class="registration-logo" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><h1>Crear cuenta</h1><p>Selecciona cómo vas a utilizar la aplicación.</p><div class="choice-grid">
      <button class="choice-card" data-register-type="adulto"><span>◎</span><strong>Soy una persona adulta</strong><small>Crearé mi cuenta y solicitaré mi propia inscripción.</small></button>
      <button class="choice-card" data-register-type="tutor"><span>◉</span><strong>Soy padre, madre o tutor</strong><small>Crearé mi cuenta y añadiré a un menor.</small></button>
      <button class="choice-card" data-route="staff"><span>✓</span><strong>Formo parte del gimnasio</strong><small>Acceso del personal ya registrado.</small></button><button class="choice-card" data-route="accept-invite"><span>✉</span><strong>Tengo una invitación</strong><small>Crea tu cuenta de monitor, secretaría o administración.</small></button>
    </div><p class="legal-note">Los menores no crean una cuenta independiente. La cuenta y los consentimientos corresponden a una persona adulta responsable.</p></section></main>`;
  }

  function catalogOptions(items, label) { return (items || []).map((item) => `<option value="${item.id}">${escapeHtml(item.nombre)}</option>`).join('') || `<option value="">${escapeHtml(label)}</option>`; }

  function renderRegistration(type) {
    state.registrationType = type;
    const d = data();
    const isTutor = type === 'tutor';
    app.innerHTML = `<main class="login-page registration-page"><section class="login-card panel registration-panel wide"><button class="back-link" data-route="register">‹ Cambiar tipo de cuenta</button><div class="registration-head"><img class="registration-logo small" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><div><h1>${isTutor ? 'Cuenta familiar' : 'Inscripción de adulto'}</h1><p>${isTutor ? 'Primero se registra el adulto responsable y después el menor.' : 'La cuenta de acceso y la ficha del alumno serán de la misma persona.'}</p></div></div>
      <form id="registration-form"><input type="hidden" name="tipo_cuenta" value="${type}" />
        <h2 class="form-section-title">1. Cuenta del adulto</h2><div class="form-grid two">
          <div class="field"><label>Nombre</label><input class="input" name="adulto_nombre" required /></div><div class="field"><label>Apellidos</label><input class="input" name="adulto_apellidos" required /></div>
          <div class="field"><label>Correo electrónico</label><input class="input" name="email" type="email" autocomplete="email" required /></div><div class="field"><label>Teléfono</label><input class="input" name="telefono" type="tel" required /></div>
          <div class="field"><label>Contraseña</label><input class="input" name="password" type="password" minlength="8" required /></div><div class="field"><label>Repetir contraseña</label><input class="input" name="password_repeat" type="password" minlength="8" required /></div>
          ${!isTutor ? `<div class="field"><label>Fecha de nacimiento</label><input class="input" name="adulto_fecha_nacimiento" type="date" required /></div>` : ''}
        </div>
        ${isTutor ? `<h2 class="form-section-title">2. Alumno menor</h2><div class="form-grid two"><div class="field"><label>Nombre del menor</label><input class="input" name="menor_nombre" required /></div><div class="field"><label>Apellidos del menor</label><input class="input" name="menor_apellidos" required /></div><div class="field"><label>Fecha de nacimiento</label><input class="input" name="menor_fecha_nacimiento" type="date" required /></div><div class="field"><label>Parentesco</label><select class="select" name="parentesco"><option>Madre</option><option>Padre</option><option>Tutor/a legal</option><option>Otro responsable autorizado</option></select></div></div>` : ''}
        <h2 class="form-section-title">${isTutor ? '3' : '2'}. Solicitud deportiva</h2><div class="form-grid two"><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" required><option value="">Selecciona disciplina</option>${catalogOptions(d.disciplinas, 'Sin disciplinas configuradas')}</select></div><div class="field"><label>Grupo preferido</label><select class="select" name="grupo_id"><option value="">Lo asignará el gimnasio</option>${catalogOptions(d.grupos, '')}</select></div><div class="field"><label>Tarifa orientativa</label><select class="select" name="tarifa_id"><option value="">La asignará el gimnasio</option>${catalogOptions(d.tarifas, '')}</select></div></div>
        <h2 class="form-section-title">${isTutor ? '4' : '3'}. Consentimientos</h2><label class="check-row"><input type="checkbox" name="privacidad" required /><span>Acepto la política de privacidad y el tratamiento de los datos necesarios para gestionar la solicitud.</span></label><label class="check-row"><input type="checkbox" name="condiciones" required /><span>Acepto las condiciones de preinscripción. La plaza no queda confirmada hasta la aprobación del gimnasio.</span></label>
        <button class="btn btn-primary btn-block" type="submit">Crear cuenta y enviar solicitud</button>
      </form></section></main>`;
  }

  function queryParam(name) {
    const raw = location.hash.split('?')[1] || '';
    return new URLSearchParams(raw).get(name) || '';
  }

  function renderInviteRegistration() {
    const token = queryParam('token');
    app.innerHTML = `<main class="login-page registration-page"><section class="login-card panel registration-panel wide"><button class="back-link" data-route="register">‹ Volver</button><div class="registration-head"><img class="registration-logo small" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><div><h1>Aceptar invitación</h1><p>Crea tu cuenta de acceso para formar parte del equipo del gimnasio.</p></div></div><form id="invited-registration-form"><div class="form-grid two"><div class="field"><label>Código de invitación</label><input class="input" name="token" value="${escapeHtml(token)}" required /></div><div class="field"><label>Correo invitado</label><input class="input" name="email" type="email" required /></div><div class="field"><label>Nombre</label><input class="input" name="nombre" required /></div><div class="field"><label>Apellidos</label><input class="input" name="apellidos" required /></div><div class="field"><label>Teléfono</label><input class="input" name="telefono" /></div><div class="field"><label>Contraseña</label><input class="input" name="password" type="password" minlength="8" required /></div><div class="field"><label>Repetir contraseña</label><input class="input" name="password_repeat" type="password" minlength="8" required /></div></div><button class="btn btn-primary btn-block" type="submit">Crear cuenta y aceptar invitación</button></form></section></main>`;
  }

  function renderPublicDownload() {
    const release = config.release; const webUrl = release.webUrl || location.href.split('#')[0];
    app.innerHTML = `<main class="login-page"><section class="login-card panel download-card"><img class="download-logo" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><h1 class="brand-title" style="font-size:30px">Urban Warriors</h1><p class="brand-slogan">Aplicación oficial</p><div class="qr-wrap"><img src="./assets/install-qr.png" alt="Código QR de instalación" /></div><div class="btn-row" style="justify-content:center">${release.apkUrl ? `<a class="btn btn-primary" href="${escapeHtml(release.apkUrl)}">Descargar Android</a>` : `<button class="btn btn-primary" disabled>APK pendiente de publicar</button>`}<a class="btn btn-secondary" href="${escapeHtml(webUrl)}">Abrir versión web</a><a class="btn btn-ghost" href="./assets/docs/Manual_Urban_Warriors.pdf" target="_blank" rel="noopener">Manual del club</a></div><p class="release-meta">Versión ${escapeHtml(release.version)} · compilación ${escapeHtml(release.build)}<br />Publicada: ${dateText(release.publishedAt)}</p><button class="btn btn-ghost btn-block" data-route="home">Volver al acceso</button></section></main>`;
  }

  function stat(label, valueText, foot) { return `<article class="stat-card"><div class="stat-label">${escapeHtml(label)}</div><div class="stat-value">${escapeHtml(valueText)}</div><div class="stat-foot">${escapeHtml(foot || '')}</div></article>`; }
  function row(icon, title, subtitle, meta) { return `<div class="card-row"><div class="card-icon">${icon}</div><div class="card-main"><h3>${escapeHtml(title)}</h3><p>${subtitle}</p></div><div class="card-meta">${meta || ''}</div></div>`; }
  function empty(message) { return `<div class="empty"><strong>Sin resultados</strong>${escapeHtml(message)}</div>`; }

  function renderHome() {
    if (isMemberPortal()) return renderMemberHome();
    if (isMonitor()) return renderMonitorHome();
    const d = data();
    const active = d.socios.filter((s) => s.estado === 'activo').length;
    const pending = d.preinscripciones.filter((p) => !['aprobada', 'rechazada', 'cancelada'].includes(p.estado)).length;
    const overdue = d.cuotas.filter((c) => c.estado === 'vencida').reduce((sum, c) => sum + Number(c.importe), 0);
    const accessToday = (d.registros_acceso || []).filter((item) => String(item.registrado_en).slice(0, 10) === todayIso()).length;
    renderShell(`${topbar('Panel del gimnasio', 'Resumen operativo de hoy')}<section class="hero"><span class="hero-kicker">● Urban Warriors activo</span><h2>Todo el gimnasio, en una sola app.</h2><p>Inscripciones, accesos, asistencia, mensualidades, publicaciones, material y alertas.</p><div class="hero-actions"><button class="btn btn-primary" data-action="open-member-form">Añadir alumno</button><button class="btn btn-secondary" data-route="attendance">Pasar asistencia</button></div></section>
      <section class="stats-grid">${stat('Socios activos', active, '+ prealtas por revisar')}${stat('Preinscripciones', pending, 'Pendientes de revisar')}${stat('Accesos hoy', accessToday, 'Registros en clases')}${stat('Cuotas vencidas', money(overdue), 'Requieren seguimiento')}</section>
      <section class="section"><div class="section-head"><div><h2>Acciones pendientes</h2><p>Lo que necesita atención</p></div><button class="btn btn-small btn-ghost" data-route="more">Ver módulos</button></div><div class="card-grid two"><article class="card">${d.preinscripciones.slice(0, 3).map((p) => row('✦', `${p.nombre} ${p.apellidos}`, `${statusBadge(p.estado)}`, `<button class="btn btn-small btn-secondary" data-route="enrollments">Revisar</button>`)).join('') || empty('No hay preinscripciones')}</article><article class="card">${d.cuotas.filter((c) => c.estado === 'vencida').slice(0, 3).map((c) => { const s = byId(d.socios, c.socio_id); return row('€', `${s?.nombre || ''} ${s?.apellidos || ''}`, `${money(c.importe)} · ${dateText(c.vencimiento)}`, statusBadge(c.estado)); }).join('') || empty('No hay cuotas vencidas')}</article></div></section>
      <section class="section"><div class="section-head"><div><h2>Últimas publicaciones</h2><p>Noticias, carteles y eventos</p></div><button class="btn btn-small btn-ghost" data-route="communications">Gestionar</button></div><div class="card-grid two">${d.comunicaciones.slice(0, 2).map(communicationCard).join('')}</div></section>`);
  }

  function memberSelector() {
    const members = familyMembers();
    if (members.length <= 1) return '';
    return `<div class="profile-selector"><label>Perfil</label><select class="select" id="profile-switch">${members.map((item) => `<option value="${item.id}" ${item.id === state.selectedMemberId ? 'selected' : ''}>${escapeHtml(item.nombre)} ${escapeHtml(item.apellidos)}</option>`).join('')}</select></div>`;
  }

  function renderMemberHome() {
    const d = data(); const member = selectedMember();
    if (!member) {
      const requests = d.preinscripciones.filter((item) => item.solicitante_perfil_id === currentUser().id);
      const requestCards = requests.map((item) => {
        const discipline = byId(d.disciplinas, item.disciplina_id); const group = byId(d.grupos, item.grupo_id);
        return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(item.nombre)} ${escapeHtml(item.apellidos)}</h3><p class="list-subtitle">${escapeHtml(discipline?.nombre || 'Disciplina pendiente')} · ${escapeHtml(group?.nombre || 'Grupo por asignar')}</p></div>${statusBadge(item.estado)}</div><p class="list-subtitle">La solicitud seguirá aquí hasta que el gimnasio la apruebe, la pase a lista de espera o la rechace.</p></article>`;
      }).join('');
      const addChild = currentUser().rol === 'familia' ? '<button class="btn btn-primary" data-action="open-add-child-form">Añadir otro menor</button>' : '';
      return renderShell(`${topbar('Mi cuenta', 'Área privada')}<section class="panel"><h2>${requests.length ? 'Solicitudes en curso' : 'Aún no hay una matrícula aprobada'}</h2><p>${requests.length ? 'Puedes consultar el estado de tus solicitudes mientras el gimnasio las revisa.' : 'Cuando el gimnasio apruebe tu inscripción, aquí aparecerán tu perfil, horarios, cuotas y progreso.'}</p>${addChild}</section><section class="section"><div class="list">${requestCards || empty('No hay solicitudes asociadas a esta cuenta')}</div></section>`);
    }
    const enrollments = memberEnrollments(member);
    const primaryEnrollment = enrollments[0] || null;
    const group = byId(d.grupos, primaryEnrollment?.grupo_id); const discipline = byId(d.disciplinas, primaryEnrollment?.disciplina_id);
    const fees = d.cuotas.filter((c) => c.socio_id === member.id);
    const attendance = d.asistencias.filter((a) => a.socio_id === member.id && a.estado !== 'pendiente');
    const present = attendance.filter((a) => a.estado === 'presente').length;
    const rate = attendance.length ? Math.round(present / attendance.length * 100) : 0;
    const pendingApp = d.preinscripciones.find((p) => p.solicitante_perfil_id === currentUser().id && p.nombre === member.nombre && !['aprobada', 'rechazada'].includes(p.estado));
    renderShell(`${topbar(`Hola, ${currentUser().nombre}`, currentUser().rol === 'alumno' ? 'Área de alumno' : 'Área de familia')}${memberSelector()}
      ${member.estado === 'prealta' ? `<section class="notice-panel"><strong>Solicitud pendiente</strong><p>La ficha de ${escapeHtml(member.nombre)} está creada, pero el gimnasio debe aprobar la inscripción. ${pendingApp ? `Estado: ${statusBadge(pendingApp.estado)}` : ''}</p></section>` : ''}
      <section class="hero"><span class="hero-kicker">Perfil seleccionado</span><h2>${escapeHtml(member.nombre)} ${escapeHtml(member.apellidos)}</h2><p>${escapeHtml(memberSportsText(member))}${member.grado ? ` · ${escapeHtml(member.grado)}` : ''}</p><div class="hero-actions"><button class="btn btn-primary" data-route="schedule">Ver horarios y acceso</button><button class="btn btn-secondary" data-route="fees">Consultar mensualidades</button></div></section>
      <section class="stats-grid">${stat('Asistencia', `${rate}%`, `${attendance.length} registros`)}${stat('Matrículas', String(enrollments.length), memberDisciplineIds(member).length + ' disciplina(s)')}${stat('Próxima clase', nextClassText(member), group?.nombre || '')}${stat('Estado de cuota', fees.some((f) => ['pendiente', 'vencida', 'parcialmente_pagada', 'pendiente_validacion', 'aplazada'].includes(f.estado)) ? (fees.some((f) => f.estado === 'pendiente_validacion') ? 'En revisión' : 'Pendiente') : 'Al día', 'Periodo actual')}</section>
      <section class="section"><div class="section-head"><div><h2>Acciones rápidas</h2><p>Gestiones habituales</p></div></div><div class="quick-grid"><button class="quick-action" data-route="schedule"><span>✓</span><strong>Registrar acceso</strong></button><button class="quick-action" data-route="fees"><span>€</span><strong>Informar un pago</strong></button><button class="quick-action" data-route="materials"><span>□</span><strong>Solicitar material</strong></button><button class="quick-action" data-route="notifications"><span>♢</span><strong>Ver alertas</strong></button></div></section>
      <section class="section"><div class="section-head"><div><h2>Avisos y eventos</h2><p>Publicaciones del gimnasio</p></div><button class="btn btn-small btn-ghost" data-route="communications">Ver todos</button></div><div class="card-grid">${d.comunicaciones.slice(0, 2).map(communicationCard).join('')}</div></section>`);
  }

  function nextClassText(member) {
    const groupIds = memberGroupIds(member);
    const hours = data().horarios.filter((h) => groupIds.includes(h.grupo_id));
    if (!hours.length) return 'Pendiente';
    const nowDay = new Date().getDay() || 7;
    const sorted = hours.slice().sort((a, b) => {
      const dayA = (a.dia_semana - nowDay + 7) % 7;
      const dayB = (b.dia_semana - nowDay + 7) % 7;
      return dayA - dayB || String(a.hora_inicio || '').localeCompare(String(b.hora_inicio || ''));
    });
    const group = byId(data().grupos, sorted[0].grupo_id);
    return `${days[sorted[0].dia_semana]} ${String(sorted[0].hora_inicio || '').slice(0,5)}${group ? ` · ${group.nombre}` : ''}`;
  }

  function renderMonitorHome() {
    const d = data(); const sessions = d.sesiones.filter((s) => s.monitor === currentUser().nombre || currentUser().nombre === 'Álex');
    renderShell(`${topbar(`Hola, ${currentUser().nombre}`, 'Panel de monitor')}<section class="hero"><span class="hero-kicker">Clases de hoy</span><h2>${sessions.length} sesiones programadas.</h2><p>Pasa lista, valida accesos y registra el seguimiento al terminar.</p><div class="hero-actions"><button class="btn btn-primary" data-route="attendance">Pasar asistencia</button><button class="btn btn-secondary" data-route="groups">Mis grupos</button></div></section><section class="stats-grid">${stat('Alumnos', String(d.socios.filter((s) => d.grupos.some((g) => g.monitor === currentUser().nombre && memberInGroup(s, g.id))).length), 'En tus grupos')}${stat('Accesos hoy', String(d.registros_acceso.filter((a) => String(a.registrado_en).slice(0, 10) === todayIso()).length), 'Check-in móvil')}${stat('Sesiones', String(sessions.length), 'Programadas')}${stat('Seguimientos', String(d.seguimiento.length), 'Registrados')}</section><section class="section"><div class="section-head"><div><h2>Agenda de hoy</h2><p>Sesiones asignadas</p></div></div><div class="card-grid">${sessions.map(sessionCard).join('') || empty('No tienes clases hoy')}</div></section>`);
  }

  function sessionCard(session) {
    const group = byId(data().grupos, session.grupo_id); const students = data().socios.filter((s) => memberInGroup(s, session.grupo_id) && s.estado === 'activo');
    return `<article class="card"><div class="list-top"><div><h3 class="list-title">${escapeHtml(group?.nombre || 'Sesión')}</h3><p class="list-subtitle">${dateText(session.fecha)} · ${escapeHtml(session.hora_inicio)} · ${students.length} alumnos</p></div>${statusBadge(session.estado)}</div><div class="list-actions"><button class="btn btn-small btn-primary" data-session="${session.id}">Pasar lista</button><span class="badge">Código: ${escapeHtml(session.codigo_acceso || '—')}</span></div></article>`;
  }

  function renderMembers() {
    const d = data(); const q = state.query.toLowerCase(); const members = d.socios.filter((s) => `${s.nombre} ${s.apellidos} ${s.tutor || ''}`.toLowerCase().includes(q));
    renderShell(`${topbar('Socios y alumnos', `${d.socios.length} registros`)}<div class="toolbar"><div class="search"><input class="input" id="member-search" value="${escapeHtml(state.query)}" placeholder="Buscar alumno o tutor" /></div><button class="btn btn-primary" data-action="open-member-form">Añadir alumno</button></div><div class="list">${members.map(memberCard).join('') || empty('No hay alumnos que coincidan con la búsqueda')}</div>`);
  }

  function memberCard(member) {
    const d = data();
    return `<article class="list-item"><div class="list-top"><div class="card-row" style="padding:0;border:0;margin:0"><div class="person-dot">${escapeHtml(initials(`${member.nombre} ${member.apellidos}`))}</div><div class="card-main"><h3>${escapeHtml(member.nombre)} ${escapeHtml(member.apellidos)}</h3><p>${escapeHtml(memberSportsText(member))}</p></div></div>${statusBadge(member.estado)}</div><div class="info-grid"><div class="info-cell"><span>Edad</span><strong>${ageFromDate(member.fecha_nacimiento) ?? '—'}</strong></div><div class="info-cell"><span>Grado</span><strong>${escapeHtml(member.grado || 'Sin asignar')}</strong></div><div class="info-cell"><span>Tutor</span><strong>${escapeHtml(member.tutor || 'No aplica')}</strong></div><div class="info-cell"><span>Cuota</span><strong>${escapeHtml(member.cuota_estado || '—')}</strong></div></div><div class="list-actions"><button class="btn btn-small btn-secondary" data-edit-member="${member.id}">Editar</button><button class="btn btn-small btn-ghost" data-member-progress="${member.id}">Seguimiento</button><button class="btn btn-small btn-ghost" data-member-graduation="${member.id}">Graduación</button></div>${memberEnrollments(member).length ? `<div class="enrollment-strip">${memberEnrollments(member).map((enrollment) => `<span class="badge">${escapeHtml(enrollment.disciplina_nombre || byId(d.disciplinas,enrollment.disciplina_id)?.nombre || '')} · ${escapeHtml(enrollment.grupo_nombre || byId(d.grupos,enrollment.grupo_id)?.nombre || '')}<button type="button" class="inline-x" title="Dar de baja esta matrícula" data-disable-enrollment="${enrollment.id}">×</button></span>`).join('')}</div>` : ''}</article>`;
  }

  function renderEnrollments() {
    const d = data();
    renderShell(`${topbar('Preinscripciones', 'Solicitudes de alta')}<div class="toolbar"><button class="btn btn-primary" data-action="open-enrollment-form">Nueva preinscripción</button></div><div class="list">${d.preinscripciones.map((p) => { const discipline = byId(d.disciplinas, p.disciplina_id); const group = byId(d.grupos, p.grupo_id); return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(p.nombre)} ${escapeHtml(p.apellidos)}</h3><p class="list-subtitle">${escapeHtml(p.tipo_solicitud === 'menor' ? 'Menor' : 'Adulto')} · ${escapeHtml(discipline?.nombre || 'Sin disciplina')} · ${escapeHtml(group?.nombre || 'Sin grupo')}</p></div>${statusBadge(p.estado)}</div><div class="info-grid"><div class="info-cell"><span>Tutor</span><strong>${escapeHtml(p.tutor || p.tutor_nombre || 'No aplica')}</strong></div><div class="info-cell"><span>Teléfono</span><strong>${escapeHtml(p.telefono || '—')}</strong></div><div class="info-cell"><span>Solicitud</span><strong>${dateText(p.fecha || p.creado_en)}</strong></div></div><div class="list-actions">${!['aprobada', 'rechazada', 'cancelada'].includes(p.estado) ? `<button class="btn btn-small btn-primary" data-approve-enrollment="${p.id}">Aprobar</button><button class="btn btn-small btn-secondary" data-waitlist-enrollment="${p.id}">Lista de espera</button><button class="btn btn-small btn-danger" data-reject-enrollment="${p.id}">Rechazar</button>` : ''}</div></article>`; }).join('') || empty('No hay solicitudes')}</div>`);
  }

  function renderSchedule() {
    const d = data(); const member = isMemberPortal() ? selectedMember() : null;
    const memberGroups = member ? memberGroupIds(member) : [];
    const groups = member ? d.grupos.filter((g) => memberGroups.includes(g.id)) : d.grupos;
    const todaySessions = member ? d.sesiones.filter((s) => memberGroups.includes(s.grupo_id) && s.fecha === todayIso()) : [];
    const upcomingSessions = d.sesiones.filter((s) => !member || memberGroups.includes(s.grupo_id)).slice().sort((a,b)=>`${a.fecha}${a.hora_inicio}`.localeCompare(`${b.fecha}${b.hora_inicio}`)).slice(0,20);
    renderShell(`${topbar(isMemberPortal() ? 'Horarios y acceso' : 'Clases y horarios', 'Programación semanal')}${isAdmin() ? `<div class="toolbar">${catalogControl(`<button class="btn btn-primary" data-action="open-group-form">Crear grupo</button>`)}<button class="btn btn-secondary" data-action="open-session-form">Nueva sesión</button>${catalogControl(`<button class="btn btn-secondary" data-action="open-discipline-form">Nueva disciplina</button>`)}</div>` : ''}
      ${isMemberPortal() && todaySessions.length ? `<section class="notice-panel"><strong>Clase disponible hoy</strong><p>Registra la llegada de ${escapeHtml(member.nombre)} introduciendo el código mostrado por el monitor.</p>${todaySessions.map((s) => `<button class="btn btn-primary" data-checkin-session="${s.id}">Registrar acceso · ${escapeHtml(s.hora_inicio)}</button>`).join('')}</section>` : ''}
      <div class="card-grid two">${groups.map((group) => { const discipline = byId(d.disciplinas, group.disciplina_id); const hours = d.horarios.filter((h) => h.grupo_id === group.id); return `<article class="card"><div class="list-top"><div><h3 class="list-title">${escapeHtml(group.nombre)}</h3><p class="list-subtitle">${escapeHtml(discipline?.nombre || '')} · Monitor: ${escapeHtml(group.monitor || 'Sin asignar')}</p></div>${statusBadge(group.activo ? 'activo' : 'inactivo')}</div><div class="card schedule-hours">${hours.map((h) => row('◷', days[h.dia_semana], `${h.hora_inicio} – ${h.hora_fin}`, '')).join('') || empty('Sin horarios configurados')}</div>${isAdmin() ? `<div class="list-actions">${catalogControl(`<button class="btn btn-small btn-secondary" data-edit-group="${group.id}">Editar grupo y horarios</button>`)}<button class="btn btn-small btn-ghost" data-create-session="${group.id}">Crear sesión</button></div>` : ''}</article>`; }).join('') || empty('No hay grupos configurados')}</div>
      <section class="section"><div class="section-head"><div><h2>Sesiones</h2><p>Clases reales para asistencia y check-in</p></div></div><div class="list">${upcomingSessions.map((session)=>{const group=byId(d.grupos,session.grupo_id);return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(group?.nombre || 'Sesión')}</h3><p class="list-subtitle">${dateText(session.fecha)} · ${escapeHtml(String(session.hora_inicio||'').slice(0,5))} · ${escapeHtml(session.monitor || '')}</p></div>${statusBadge(session.estado)}</div>${isAdmin()||isMonitor()?`<div class="list-actions"><button class="btn btn-small btn-secondary" data-edit-session="${session.id}">Editar</button><button class="btn btn-small btn-primary" data-session="${session.id}">Asistencia</button></div>`:''}</article>`}).join('') || empty('No hay sesiones creadas')}</div></section>`);
  }

  function renderGroups() {
    const d = data(); const groups = isMonitor() ? d.grupos.filter((g) => g.monitor === currentUser().nombre || currentUser().nombre === 'Álex') : d.grupos;
    renderShell(`${topbar(isAdmin() ? 'Grupos' : 'Mis grupos', `${groups.length} grupos asignados`)}${isAdmin()?`<div class="toolbar">${catalogControl(`<button class="btn btn-primary" data-action="open-group-form">Crear grupo</button>`)}<button class="btn btn-secondary" data-action="open-session-form">Nueva sesión</button></div>`:''}<div class="card-grid two">${groups.map((g) => { const students = d.socios.filter((s) => memberInGroup(s, g.id)); return `<article class="card"><div class="list-top"><div><h3>${escapeHtml(g.nombre)}</h3><p class="list-subtitle">${students.length} alumnos · ${escapeHtml(g.monitor || '')}</p></div>${statusBadge(g.activo ? 'activo' : 'inactivo')}</div><div class="list-actions"><button class="btn btn-small btn-primary" data-group-attendance="${g.id}">Pasar lista</button>${catalogControl(`<button class="btn btn-small btn-secondary" data-edit-group="${g.id}">Editar grupo y horarios</button>`)}${isAdmin()?`<button class="btn btn-small btn-ghost" data-create-session="${g.id}">Nueva sesión</button>`:''}</div><div style="margin-top:14px">${students.map((s) => row('◎', `${s.nombre} ${s.apellidos}`, `Grado ${s.grado || 'sin asignar'}`, '')).join('') || '<p class="list-subtitle">Sin alumnos asignados</p>'}</div></article>`; }).join('') || empty('No tienes grupos asignados')}</div>`);
  }

  function renderAttendance() {
    const d = data(); const sessions = isMonitor() ? d.sesiones.filter((s) => s.monitor === currentUser().nombre || currentUser().nombre === 'Álex') : d.sesiones;
    const selected = byId(sessions, state.selectedSession) || sessions[0];
    if (!selected) { renderShell(`${topbar('Asistencia', 'Registro de sesiones')}${empty('No hay sesiones programadas')}`); return; }
    state.selectedSession = selected.id; const group = byId(d.grupos, selected.grupo_id); const students = d.socios.filter((s) => memberInGroup(s, selected.grupo_id) && s.estado === 'activo');
    renderShell(`${topbar('Pasar asistencia', `${group?.nombre || ''} · ${dateText(selected.fecha)} ${selected.hora_inicio}`)}<div class="toolbar"><select class="select" id="session-select">${sessions.map((s) => { const g = byId(d.grupos, s.grupo_id); return `<option value="${s.id}" ${s.id === selected.id ? 'selected' : ''}>${escapeHtml(g?.nombre || 'Sesión')} · ${dateText(s.fecha)} ${s.hora_inicio}</option>`; }).join('')}</select><button class="btn btn-primary" data-action="save-attendance">Guardar lista</button></div><div class="access-summary">Código de acceso: <strong>${escapeHtml(selected.codigo_acceso || 'No configurado')}</strong> · Registros: ${d.registros_acceso.filter((a) => a.sesion_id === selected.id).length}</div><div class="attendance-list">${students.map((student) => attendanceRow(selected, student)).join('') || empty('No hay alumnos asignados')}</div>`);
  }

  function attendanceRow(session, student) {
    const record = data().asistencias.find((a) => a.sesion_id === session.id && a.socio_id === student.id); const current = record?.estado || 'pendiente';
    return `<article class="attendance-person" data-student="${student.id}"><div class="person-dot">${escapeHtml(initials(`${student.nombre} ${student.apellidos}`))}</div><div class="card-main"><h3>${escapeHtml(student.nombre)} ${escapeHtml(student.apellidos)}</h3><p>${escapeHtml(student.grado || '')}</p></div><div class="attendance-controls"><button class="attendance-option present ${current === 'presente' ? 'selected' : ''}" data-attendance-state="presente" title="Presente">✓</button><button class="attendance-option absent ${current === 'ausente' ? 'selected' : ''}" data-attendance-state="ausente" title="Ausente">×</button><button class="attendance-option justified ${current === 'ausencia_justificada' ? 'selected' : ''}" data-attendance-state="ausencia_justificada" title="Justificada">!</button></div></article>`;
  }

  function renderFees() {
    const d = data();
    const member = isMemberPortal() ? selectedMember() : null;
    const visible = member ? d.cuotas.filter((c) => c.socio_id === member.id) : d.cuotas;
    const activeStates = ['pendiente', 'vencida', 'parcialmente_pagada', 'pendiente_validacion', 'aplazada'];
    const outstanding = (fee) => {
      const paid = d.pagos.filter((p) => p.cuota_id === fee.id && p.estado_validacion === 'validado')
        .reduce((sum, p) => sum + Number(p.importe), 0);
      return Math.max(Number(fee.importe) - paid, 0);
    };
    const pendingTotal = visible.filter((c) => activeStates.includes(c.estado)).reduce((sum, c) => sum + outstanding(c), 0);
    const payments = member ? d.pagos.filter((p) => p.socio_id === member.id) : d.pagos;
    const pendingValidation = payments.filter((p) => p.estado_validacion === 'pendiente').length;
    const pausedCount = visible.filter((c) => c.avisos_pausados && !['pagada','anulada','exenta'].includes(c.estado)).length;

    renderShell(`${topbar(isMemberPortal() ? 'Mensualidades y pagos' : 'Finanzas', isMemberPortal() ? 'Recibos, justificantes y estado' : 'Cobros, justificantes y cinco avisos automáticos')}
      <section class="stats-grid">
        ${stat('Saldo pendiente', money(pendingTotal), `${visible.filter((c) => activeStates.includes(c.estado)).length} cuotas`)}
        ${stat('Pagado', money(payments.filter((p) => p.estado_validacion === 'validado').reduce((sum, p) => sum + Number(p.importe), 0)), 'Cobros validados')}
        ${!isMemberPortal() ? stat('Por validar', String(pendingValidation), 'Justificantes comunicados') : ''}
        ${!isMemberPortal() ? stat('Avisos pausados', String(pausedCount), 'Por secretaría o tesorería') : ''}
      </section>
      ${canManageFinance() ? `<div class="toolbar finance-toolbar"><button class="btn btn-primary" data-action="generate-fees">Generar mensualidades</button><button class="btn btn-secondary" data-action="open-payment-form">Registrar cobro</button><button class="btn btn-secondary" data-route="payment-alerts">Configurar avisos</button><button class="btn btn-secondary" data-action="open-tariff-form">Nueva tarifa</button></div>` : ''}
      ${isMemberPortal() && pendingValidation ? `<section class="notice-panel"><strong>Pago pendiente de revisión</strong><p>Los avisos de cobro quedan detenidos mientras secretaría o tesorería valida el justificante.</p></section>` : ''}
      <section class="section"><div class="section-head"><div><h2>Mensualidades</h2><p>Ciclo de cobro, saldo y alertas</p></div></div><div class="list">
        ${visible.map((fee) => {
          const student = byId(d.socios, fee.socio_id);
          const paid = d.pagos.filter((p) => p.cuota_id === fee.id && p.estado_validacion === 'validado').reduce((sum, p) => sum + Number(p.importe), 0);
          const balance = Math.max(Number(fee.importe) - paid, 0);
          const reminderCount = (d.historial_avisos_cuota || []).filter((h) => h.cuota_id === fee.id && h.estado !== 'cancelado').length;
          const pauseText = fee.avisos_pausados ? `Avisos pausados${fee.avisos_pausados_hasta ? ` hasta ${dateText(fee.avisos_pausados_hasta)}` : ''}${fee.motivo_pausa_avisos ? ` · ${fee.motivo_pausa_avisos}` : ''}` : '';
          return `<article class="list-item fee-card ${fee.avisos_pausados ? 'fee-paused' : ''}">
            <div class="list-top"><div><h3 class="list-title">${escapeHtml(fee.concepto)}</h3><p class="list-subtitle">${isMemberPortal() ? '' : `${escapeHtml(student?.nombre || '')} ${escapeHtml(student?.apellidos || '')} · `}${dateText(fee.periodo)} · vence ${dateText(fee.vencimiento)}</p></div><strong>${money(fee.importe)}</strong></div>
            <div class="fee-progress"><span>Cobrado: ${money(paid)}</span><span>Saldo: ${money(balance)}</span><span>Avisos: ${Math.min(reminderCount,5)}/5</span></div>
            ${pauseText ? `<p class="fee-pause-note">⏸ ${escapeHtml(pauseText)}</p>` : ''}
            <div class="list-actions">${statusBadge(fee.estado)}
              ${(d.recibos || []).find((r) => r.cuota_id === fee.id && !r.anulado_en) ? `<button class="btn btn-small btn-secondary" data-receipt="${(d.recibos || []).find((r) => r.cuota_id === fee.id && !r.anulado_en).id}">Ver recibo</button>` : ''}
              ${canManageFinance() && !['pagada','anulada','exenta'].includes(fee.estado) ? `<button class="btn btn-small btn-primary" data-payment-fee="${fee.id}">Registrar cobro</button>${fee.avisos_pausados ? `<button class="btn btn-small btn-secondary" data-resume-fee="${fee.id}">Reactivar avisos</button>` : `<button class="btn btn-small btn-ghost" data-pause-fee="${fee.id}">Pausar avisos</button>`}` : ''}
              ${isMemberPortal() && !['pagada','anulada','exenta','pendiente_validacion'].includes(fee.estado) ? `<button class="btn btn-small btn-primary" data-payment-fee="${fee.id}">Ya he pagado / Adjuntar justificante</button>` : ''}
            </div>
          </article>`;
        }).join('') || empty('No hay cuotas')}
      </div></section>
      <section class="section"><div class="section-head"><div><h2>Registro de pagos</h2><p>Transferencias, Bizum, efectivo y tarjeta</p></div></div><div class="list">${payments.map((p) => paymentCard(p)).join('') || empty('No hay pagos registrados')}</div></section>${canManageFinance() ? `<section class="section"><div class="section-head"><div><h2>Tarifas</h2><p>Planes y precios configurables</p></div></div><div class="list">${d.tarifas.map((t) => `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(t.nombre)}</h3><p class="list-subtitle">${escapeHtml(t.descripcion || 'Sin descripción')}</p></div><strong>${money(t.importe)}</strong></div><div class="list-actions">${statusBadge(t.activa ? 'activo':'inactivo')}<button class="btn btn-small btn-secondary" data-edit-tariff="${t.id}">Editar</button><button class="btn btn-small btn-ghost" data-toggle-tariff="${t.id}">${t.activa?'Desactivar':'Activar'}</button></div></article>`).join('') || empty('No hay tarifas')}</div></section>` : ''}`);
  }

  function paymentCard(payment) {
    const member = byId(data().socios, payment.socio_id);
    return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(payment.metodo || 'Pago')}</h3><p class="list-subtitle">${escapeHtml(member?.nombre || '')} ${escapeHtml(member?.apellidos || '')} · ${dateText(payment.fecha)} · ${escapeHtml(payment.referencia || 'Sin referencia')}</p></div><strong>${money(payment.importe)}</strong></div>
      ${payment.motivo_rechazo ? `<p class="payment-rejection">Motivo: ${escapeHtml(payment.motivo_rechazo)}</p>` : ''}
      <div class="list-actions">${statusBadge(payment.estado_validacion)}
        ${payment.justificante_url ? `<button class="btn btn-small btn-ghost" data-view-proof="${payment.id}">Ver justificante</button>` : ''}
        ${(data().recibos || []).find((r) => r.pago_id === payment.id && !r.anulado_en) ? `<button class="btn btn-small btn-secondary" data-receipt="${(data().recibos || []).find((r) => r.pago_id === payment.id && !r.anulado_en).id}">Recibo</button>` : ''}
        ${canManageFinance() && payment.estado_validacion === 'pendiente' ? `<button class="btn btn-small btn-primary" data-validate-payment="${payment.id}">Validar</button><button class="btn btn-small btn-danger" data-reject-payment="${payment.id}">Rechazar</button>` : ''}
      </div></article>`;
  }


  function receiptMonth(period) {
    if (!period) return '—';
    try {
      const d = new Date(`${String(period).slice(0,10)}T12:00:00`);
      return d.toLocaleDateString(config.locale || 'es-ES', { month: 'long', year: 'numeric' }).replace(/^./, (c) => c.toUpperCase());
    } catch (_) { return dateText(period); }
  }

  function receiptPreview(receipt) {
    if (!receipt) return;
    document.getElementById('modal-backdrop')?.remove();
    const modal = document.createElement('div');
    modal.className = 'modal-backdrop'; modal.id = 'modal-backdrop';
    modal.innerHTML = `<section class="modal receipt-modal" role="dialog" aria-modal="true" aria-labelledby="receipt-title">
      <div class="modal-head"><h2 id="receipt-title">Recibo ${escapeHtml(receipt.numero)}</h2><button class="icon-btn" data-action="close-modal">×</button></div>
      <div class="modal-body">
        <article class="receipt-card">
          <img class="receipt-logo" src="${escapeHtml(data().club.logo_url || config.brand.logo)}" alt="Urban Warriors" />
          <div class="receipt-kicker">RECIBO DE CUOTA</div>
          <div class="receipt-paid">PAGADO</div>
          <div class="receipt-grid">
            <span>Socio</span><strong>${escapeHtml(receipt.socio_nombre)}</strong>
            <span>Actividad</span><strong>${escapeHtml(receipt.actividad)}</strong>
            <span>Mes</span><strong>${escapeHtml(receiptMonth(receipt.periodo))}</strong>
            <span>Importe</span><strong>${money(receipt.importe)}</strong>
            <span>Pagado por</span><strong>${escapeHtml(receipt.pagado_por)}</strong>
            <span>Fecha</span><strong>${dateText(receipt.fecha_pago)}</strong>
          </div>
          <div class="receipt-number">${escapeHtml(receipt.numero)}</div>
          <div class="receipt-thanks">Gracias por formar parte de Urban Warriors</div>
        </article>
        <div class="modal-actions"><button class="btn btn-ghost" type="button" data-action="close-modal">Cerrar</button><button class="btn btn-primary" type="button" data-download-receipt="${escapeHtml(receipt.id)}">Descargar PDF</button></div>
      </div>
    </section>`;
    document.body.appendChild(modal);
  }

  async function loadReceiptLogo() {
    const src = config.brand.logo || './assets/urban-warriors-logo.png';
    return await new Promise((resolve) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => resolve(null);
      img.src = src;
    });
  }

  function canvasJpegToPdf(jpegBytes, widthPx, heightPx) {
    const encoder = new TextEncoder();
    const chunks = [];
    let offset = 0;
    const offsets = [0];
    const pushText = (text) => { const b = encoder.encode(text); chunks.push(b); offset += b.length; };
    const pushBytes = (b) => { chunks.push(b); offset += b.length; };
    pushText('%PDF-1.4\n%UW\n');
    const obj = (n, body) => { offsets[n] = offset; pushText(`${n} 0 obj\n${body}\nendobj\n`); };
    obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    obj(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>');
    offsets[4] = offset;
    pushText(`4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${widthPx} /Height ${heightPx} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpegBytes.length} >>\nstream\n`);
    pushBytes(jpegBytes); pushText('\nendstream\nendobj\n');
    const content = 'q 595 0 0 842 0 0 cm /Im0 Do Q';
    obj(5, `<< /Length ${content.length} >>\nstream\n${content}\nendstream`);
    const xref = offset;
    pushText('xref\n0 6\n0000000000 65535 f \n');
    for (let i=1;i<=5;i+=1) pushText(`${String(offsets[i]).padStart(10,'0')} 00000 n \n`);
    pushText(`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`);
    const out = new Uint8Array(offset);
    let cursor = 0;
    for (const c of chunks) { out.set(c, cursor); cursor += c.length; }
    return out;
  }

  async function downloadReceiptPdf(receiptId) {
    const receipt = byId(data().recibos || [], receiptId);
    if (!receipt) throw new Error('Recibo no encontrado.');
    const canvas = document.createElement('canvas');
    canvas.width = 1240; canvas.height = 1754;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#050608'; ctx.fillRect(0,0,canvas.width,canvas.height);
    ctx.strokeStyle = '#30343a'; ctx.lineWidth = 3; ctx.strokeRect(70,70,1100,1614);
    const logo = await loadReceiptLogo();
    if (logo) {
      const maxW=360, maxH=250, scale=Math.min(maxW/logo.width,maxH/logo.height,1);
      const w=logo.width*scale, h=logo.height*scale;
      ctx.drawImage(logo,(canvas.width-w)/2,125,w,h);
    }
    ctx.textAlign='center'; ctx.fillStyle='#aeb4bd'; ctx.font='700 30px Arial'; ctx.fillText('RECIBO DE CUOTA',620,430);
    ctx.fillStyle='#ffffff'; ctx.font='900 78px Arial'; ctx.fillText('PAGADO',620,535);
    ctx.strokeStyle='#4b5057'; ctx.beginPath(); ctx.moveTo(190,590); ctx.lineTo(1050,590); ctx.stroke();
    const rows=[['SOCIO',receipt.socio_nombre],['ACTIVIDAD',receipt.actividad],['MES',receiptMonth(receipt.periodo)],['IMPORTE',money(receipt.importe)],['PAGADO POR',receipt.pagado_por],['FECHA',dateText(receipt.fecha_pago)]];
    let y=700;
    for (const [label,value] of rows) {
      ctx.textAlign='left'; ctx.fillStyle='#8d949d'; ctx.font='700 22px Arial'; ctx.fillText(label,210,y);
      ctx.textAlign='right'; ctx.fillStyle='#ffffff'; ctx.font='700 31px Arial';
      let text=String(value || '—'); while(ctx.measureText(text).width>570 && text.length>8) text=text.slice(0,-2)+'…';
      ctx.fillText(text,1030,y); y+=125;
    }
    ctx.textAlign='center'; ctx.fillStyle='#9ca3af'; ctx.font='700 25px Arial'; ctx.fillText(receipt.numero,620,1490);
    ctx.fillStyle='#ffffff'; ctx.font='600 24px Arial'; ctx.fillText('Gracias por formar parte de Urban Warriors',620,1570);
    const blob = await new Promise((resolve) => canvas.toBlob(resolve,'image/jpeg',0.92));
    if (!blob) throw new Error('No se pudo generar el recibo.');
    const jpeg = new Uint8Array(await blob.arrayBuffer());
    const pdf = canvasJpegToPdf(jpeg, canvas.width, canvas.height);
    const url = URL.createObjectURL(new Blob([pdf],{type:'application/pdf'}));
    const link=document.createElement('a'); link.href=url; link.download=`${receipt.numero}.pdf`; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(()=>URL.revokeObjectURL(url),1500);
    toast(`Recibo ${receipt.numero} descargado`);
  }

  function renderCommunications() {
    const d = data();
    renderShell(`${topbar('Avisos, carteles y eventos', 'Publicaciones del gimnasio')}${isAdmin() ? `<div class="toolbar"><button class="btn btn-primary" data-action="open-communication-form">Nueva publicación</button></div>` : ''}<div class="feed-grid">${d.comunicaciones.map(communicationCard).join('') || empty('No hay publicaciones')}</div>`);
  }

  function communicationCard(item) {
    const date = item.tipo === 'evento' ? item.evento_fecha : item.fecha || item.publicada_en || item.creado_en;
    return `<article class="card communication-card">${item.imagen_url ? `<img class="communication-image" src="${escapeHtml(item.imagen_url)}" alt="${escapeHtml(item.titulo)}" />` : `<div class="communication-placeholder">UW</div>`}<div class="communication-content"><div class="list-top"><div><span class="post-type">${escapeHtml(item.tipo || 'noticia')}</span><h3 class="list-title">${escapeHtml(item.titulo)}</h3></div>${statusBadge(item.estado)}</div><p class="communication-body">${escapeHtml(item.cuerpo)}</p><div class="list-actions"><span class="badge">${escapeHtml(item.audiencia || 'todos')}</span><span class="badge">${dateText(date)}</span>${item.ubicacion ? `<span class="badge">⌖ ${escapeHtml(item.ubicacion)}</span>` : ''}${isAdmin() ? `<button class="btn btn-small btn-secondary" data-edit-communication="${item.id}">Editar</button><button class="btn btn-small btn-ghost" data-archive-communication="${item.id}">${item.estado==='archivada'?'Publicar':'Archivar'}</button>` : ''}</div></div></article>`;
  }

  function renderMaterials() {
    const d=data();
    renderShell(`${topbar('Material y equipación', isMemberPortal() ? 'Catálogo y solicitudes' : 'Catálogo, stock y pedidos')}${isAdmin() ? `<div class="toolbar"><button class="btn btn-primary" data-action="open-material-form">Añadir material</button></div>` : ''}<div class="card-grid two">${d.material.map((m) => { const disc=byId(d.disciplinas,m.disciplina_id); const variants=d.material_variantes.filter((v)=>v.material_id===m.id); return `<article class="card material-card">${m.imagen_url?`<img class="material-image" src="${escapeHtml(m.imagen_url)}" alt="${escapeHtml(m.nombre)}" />`:''}<div class="list-top"><div><h3 class="list-title">${escapeHtml(m.nombre)}</h3><p class="list-subtitle">${escapeHtml(m.categoria || 'General')} · ${escapeHtml(disc?.nombre || 'Todas las disciplinas')}</p></div><strong>${money(m.precio)}</strong></div><div class="info-grid"><div class="info-cell"><span>Stock base</span><strong>${m.stock ?? 0}</strong></div><div class="info-cell"><span>Variantes</span><strong>${variants.length}</strong></div><div class="info-cell"><span>Obligatorio</span><strong>${m.obligatorio?'Sí':'No'}</strong></div></div>${variants.length?`<div class="variant-chips">${variants.map((v)=>`<button class="badge" data-edit-variant="${v.id}" data-material-id="${m.id}">${escapeHtml([v.talla,v.color].filter(Boolean).join(' · ') || 'Variante')} · ${v.stock}</button>`).join('')}</div>`:''}${isMemberPortal()?`<div class="list-actions"><button class="btn btn-small btn-primary" data-buy-material="${m.id}">Solicitar compra</button></div>`:isAdmin()?`<div class="list-actions"><button class="btn btn-small btn-secondary" data-edit-material="${m.id}">Editar</button><button class="btn btn-small btn-ghost" data-add-variant="${m.id}">Añadir variante</button><button class="btn btn-small btn-ghost" data-toggle-material="${m.id}">${m.activo===false?'Activar':'Desactivar'}</button></div>`:''}</article>`; }).join('') || empty('No hay material configurado')}</div>${!isMemberPortal()?`<section class="section"><div class="section-head"><div><h2>Pedidos</h2><p>Reservas y entregas</p></div></div><div class="list">${d.pedidos_material.map((o)=>{const member=byId(d.socios,o.socio_id);const m=byId(d.material,o.material_id);return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(m?.nombre || 'Material')} · ${escapeHtml(member?.nombre || '')}</h3><p class="list-subtitle">${o.cantidad} unidad(es) · ${money(o.importe_total)}</p></div>${statusBadge(o.estado)}</div>${!['entregado','cancelado'].includes(o.estado)?`<div class="list-actions"><button class="btn btn-small btn-primary" data-advance-order="${o.id}">${o.estado==='reservado'?'Marcar preparado':'Marcar entregado'}</button></div>`:''}</article>`}).join('')||empty('No hay pedidos')}</div></section>`:''}`);
  }

  function renderProgress() {
    const d = data();
    renderShell(`${topbar('Seguimiento', 'Evolución deportiva')}<div class="toolbar"><button class="btn btn-primary" data-action="open-progress-form">Añadir observación</button></div><div class="list">${d.seguimiento.map((item) => { const member = byId(d.socios, item.socio_id); return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(member?.nombre || '')} ${escapeHtml(member?.apellidos || '')}</h3><p class="list-subtitle">${escapeHtml(item.nota)}</p></div><span class="badge">${escapeHtml(item.tipo)}</span></div><div class="list-actions"><span class="badge">${dateText(item.fecha)}</span><span class="badge">Visible: ${escapeHtml(item.visibilidad)}</span></div></article>`; }).join('') || empty('No hay seguimientos registrados')}</div>`);
  }

  function renderNotifications() {
    const notifications = visibleNotifications();
    renderShell(`${topbar('Notificaciones y alertas', `${notifications.filter((n) => !n.leida).length} sin leer`)}<div class="toolbar"><button class="btn btn-primary" data-action="enable-notifications">Activar alertas del dispositivo</button><button class="btn btn-secondary" data-action="mark-all-read">Marcar todo como leído</button></div><div class="list">${notifications.map((item) => {
      const number = item.datos?.aviso_numero;
      return `<button class="notification-item ${item.leida ? '' : 'unread'}" data-notification="${item.id}" data-notification-route="${escapeHtml(item.ruta || 'home')}"><div class="notification-icon">${item.tipo === 'cuota' ? (number || '€') : item.tipo === 'clase' ? '✓' : item.tipo === 'evento' ? '✦' : '♢'}</div><div class="card-main"><h3>${escapeHtml(item.titulo)}</h3><p>${escapeHtml(item.cuerpo)}</p><small>${number ? `Aviso ${number} de 5 · ` : ''}${dateTimeText(item.creado_en)}</small></div>${!item.leida ? '<span class="unread-dot"></span>' : ''}</button>`;
    }).join('') || empty('No tienes alertas')}</div>`);
  }

  function renderPaymentAlerts() {
    if (!canManageFinance()) {
      renderShell(`${topbar('Avisos de cobro', 'Acceso restringido')}${empty('Solo dirección, secretaría o tesorería pueden configurar las alarmas de mensualidades.')}`);
      return;
    }
    const d = data();
    const settings = Object.assign({ dias_avisos_cobro: [1,4,8,11,14], hora_envio: '10:00', canal_app: true, canal_push: true, canal_email: false, agrupar_por_familia: true, marcar_vencida_dia: 15 }, d.settings || {});
    const days = (settings.dias_aviso || settings.dias_avisos_cobro || [1,4,8,11,14]).map(Number);
    const history = d.historial_avisos_cuota || [];
    const pendingValidation = d.pagos.filter((p) => p.estado_validacion === 'pendiente').length;
    const paused = d.cuotas.filter((q) => q.avisos_pausados && !['pagada','anulada','exenta'].includes(q.estado)).length;
    renderShell(`${topbar('Avisos automáticos de cobro', 'Cinco avisos en los primeros quince días')}
      <section class="stats-grid">${stat('Avisos emitidos', String(history.length), 'Historial trazable')}${stat('Pagos por validar', String(pendingValidation), 'Avisos suspendidos')}${stat('Cuotas pausadas', String(paused), 'Gestión manual')}${stat('Vencimiento', `Día ${settings.marcar_vencida_dia || 15}`, 'Alerta a tesorería')}</section>
      <section class="panel reminder-plan"><div class="section-head"><div><h2>Secuencia mensual</h2><p>Se detiene al registrar, comunicar o validar el pago</p></div></div><div class="reminder-timeline">${days.map((day,index) => `<div class="reminder-step"><span class="reminder-number">${index+1}</span><strong>Día ${day}</strong><small>Aviso ${index+1}</small></div>`).join('')}</div></section>
      <section class="panel settings-panel"><form id="reminder-settings-form"><div class="section-head"><div><h2>Configuración</h2><p>Editable por dirección, secretaría y tesorería</p></div></div><div class="form-grid five-days">${days.map((day,index) => `<div class="field"><label>Aviso ${index+1}</label><input class="input" name="aviso_${index+1}" type="number" min="1" max="28" value="${day}" required /></div>`).join('')}</div><div class="form-grid two"><div class="field"><label>Hora de envío</label><input class="input" name="hora_envio" type="time" value="${escapeHtml(String(settings.hora_envio || '10:00').slice(0,5))}" required /></div><div class="field"><label>Marcar vencida el día</label><input class="input" name="marcar_vencida_dia" type="number" min="1" max="28" value="${settings.marcar_vencida_dia || 15}" /></div><div class="field"><label><input type="checkbox" checked disabled /> Notificación interna (obligatoria)</label><input type="hidden" name="canal_app" value="on" /></div><div class="field"><label><input type="checkbox" name="canal_push" ${config.push?.enabled && settings.canal_push !== false ? 'checked' : ''} ${config.push?.enabled ? '' : 'disabled'} /> Push al móvil${config.push?.enabled ? '' : ' (pendiente de Firebase)'}</label></div><div class="field"><label><input type="checkbox" name="canal_email" ${settings.canal_email ? 'checked' : ''} /> Correo complementario (requiere proveedor)</label></div><div class="field"><label><input type="checkbox" name="agrupar_por_familia" ${settings.agrupar_por_familia !== false ? 'checked' : ''} /> Agrupar hermanos por familia</label></div></div><div class="btn-row"><button class="btn btn-primary" type="submit">Guardar configuración</button></div></form></section>
      <section class="panel"><div class="section-head"><div><h2>Prueba y ejecución manual</h2><p>El cron de Supabase lo ejecutará automáticamente cada día</p></div></div><div class="toolbar"><input class="input" id="reminder-test-date" type="date" value="${todayIso()}" /><button class="btn btn-secondary" data-action="process-reminders">Procesar fecha seleccionada</button></div></section>
      <section class="section"><div class="section-head"><div><h2>Historial de avisos</h2><p>Cuota, destinatario y resultado</p></div></div><div class="list">${history.slice(0,100).map((item) => { const fee=byId(d.cuotas,item.cuota_id); const member=byId(d.socios,fee?.socio_id); return `<article class="list-item"><div class="list-top"><div><h3 class="list-title">Aviso ${item.aviso_numero} de 5 · ${escapeHtml(member?.nombre || 'Alumno')}</h3><p class="list-subtitle">${dateText(item.fecha_programada)} · ${escapeHtml(item.canal || 'app')}</p></div>${statusBadge(item.estado)}</div></article>`; }).join('') || empty('Todavía no se han emitido avisos')}</div></section>`);
  }

  function renderMore() {
    const sections = [['users', '◉', 'Usuarios y permisos', 'Equipo e invitaciones'], ['enrollments', '✦', 'Preinscripciones', 'Solicitudes y listas de espera'], ['disciplines', '◈', 'Disciplinas y grados', 'Oferta deportiva'], ['communications', '●', 'Publicaciones y eventos', 'Carteles, imágenes y posts'], ['materials', '□', 'Material y pedidos', 'Catálogo, compras y entregas'], ['payment-alerts', '€', 'Avisos automáticos de cobro', 'Días 1, 4, 8, 11 y 14'], ['notifications', '♢', 'Notificaciones', 'Alertas y recordatorios'], ['settings', '⚙', 'Configuración', 'Datos e identidad del club'], ['download', '⌁', 'APK y código QR', 'Instalación y distribución']];
    renderShell(`${topbar('Administración', 'Configuración y módulos')}<div class="card-grid two">${sections.map(([route, icon, title, subtitle]) => `<button class="card card-row menu-card" data-route="${route}"><div class="card-icon">${icon}</div><div class="card-main"><h3>${title}</h3><p>${subtitle}</p></div><div>›</div></button>`).join('')}</div>`);
  }

  function renderUsers() {
    const d = data();
    const inviteBase = `${location.origin}${location.pathname}#/accept-invite?token=`;
    renderShell(`${topbar('Usuarios y permisos', 'Equipo del club e invitaciones')}<div class="toolbar"><button class="btn btn-primary" data-action="open-invite-form">Invitar personal</button></div><section class="section"><div class="section-head"><div><h2>Equipo activo</h2><p>Roles con acceso al club</p></div></div><div class="list">${(d.miembros || []).map((m) => `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(`${m.nombre || ''} ${m.apellidos || ''}`.trim() || 'Usuario')}</h3><p class="list-subtitle">${escapeHtml(m.perfiles?.id || m.perfil_id || '')}</p></div>${statusBadge(m.rol)}</div></article>`).join('') || empty('No hay miembros visibles')}</div></section><section class="section"><div class="section-head"><div><h2>Invitaciones</h2><p>Comparte el enlace con la persona invitada</p></div></div><div class="list">${(d.invitaciones || []).map((i) => `<article class="list-item"><div class="list-top"><div><h3 class="list-title">${escapeHtml(i.email)}</h3><p class="list-subtitle">Rol: ${escapeHtml(i.rol)} · vence ${dateText(i.expira_en)}</p></div>${statusBadge(i.estado)}</div>${i.estado === 'pendiente' ? `<div class="list-actions"><button class="btn btn-small btn-secondary" data-copy-invite="${escapeHtml(inviteBase + i.token)}">Copiar enlace</button></div>` : ''}</article>`).join('') || empty('No hay invitaciones pendientes')}</div></section>`);
  }

  function renderDisciplines() {
    const d = data();
    renderShell(`${topbar('Disciplinas y grados', 'Catálogo editable')}${catalogControl(`<div class="toolbar"><button class="btn btn-primary" data-action="open-discipline-form">Nueva disciplina</button><button class="btn btn-secondary" data-action="open-grade-form">Nuevo grado</button></div>`) || '<div class="toolbar"><span class="list-subtitle">Solo Dirección y Secretaría pueden modificar el catálogo.</span></div>'}<div class="card-grid two">${d.disciplinas.map((disc) => { const grades=d.grados.filter((g)=>g.disciplina_id===disc.id).sort((a,b)=>Number(a.orden)-Number(b.orden)); return `<article class="card"><div class="list-top"><div><h3 class="list-title">${escapeHtml(disc.nombre)}</h3><p class="list-subtitle">${escapeHtml(disc.descripcion || 'Sin descripción')}</p></div>${statusBadge(disc.activa ? 'activo' : 'inactivo')}</div><div class="grade-list" style="margin-top:14px">${grades.map((g)=>`${catalogControl(`<button class="badge ${g.activo===false?'info':''}" style="margin:0 5px 5px 0" data-edit-grade="${g.id}">${escapeHtml(g.orden)} · ${escapeHtml(g.nombre)}</button>`) || `<span class="badge ${g.activo===false?'info':''}" style="margin:0 5px 5px 0">${escapeHtml(g.orden)} · ${escapeHtml(g.nombre)}</span>`}`).join('') || '<span class="list-subtitle">Sin escala de grados</span>'}</div>${catalogControl(`<div class="list-actions"><button class="btn btn-small btn-secondary" data-edit-discipline="${disc.id}">Editar</button><button class="btn btn-small btn-ghost" data-add-grade="${disc.id}">Añadir grado</button><button class="btn btn-small btn-ghost" data-toggle-discipline="${disc.id}">${disc.activa ? 'Desactivar' : 'Activar'}</button></div>`)}</article>`; }).join('') || empty('No hay disciplinas')}</div>`);
  }

  function renderSettings() {
    const d = data();
    renderShell(`${topbar('Configuración', 'Identidad, mensualidades y alertas')}<section class="panel settings-panel"><form id="settings-form" class="form-grid two"><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(d.club.nombre)}" required /></div><div class="field"><label>Lema</label><input class="input" name="lema" value="${escapeHtml(d.club.lema || '')}" /></div><div class="field"><label>Teléfono</label><input class="input" name="telefono" value="${escapeHtml(d.club.telefono || '')}" /></div><div class="field"><label>Correo</label><input class="input" name="email" type="email" value="${escapeHtml(d.club.email || '')}" /></div><div class="field"><label>Dirección</label><input class="input" name="direccion" value="${escapeHtml(d.club.direccion || '')}" /></div><div class="field"><label>Día de vencimiento habitual</label><input class="input" name="dia_vencimiento" type="number" min="1" max="28" value="${escapeHtml(d.settings.dia_vencimiento || 15)}" /></div><div class="field"><label>Avisar clase con antelación (horas)</label><input class="input" name="avisos_clase_horas" type="number" min="0" max="48" value="${escapeHtml(d.settings.avisos_clase_horas || 3)}" /></div><div class="field"><label>Color principal</label><input class="input" name="color_primario" type="color" value="${escapeHtml(d.club.color_primario || '#ffffff')}" /></div><div class="field"><label>Color secundario</label><input class="input" name="color_secundario" type="color" value="${escapeHtml(d.club.color_secundario || '#050608')}" /></div><div class="wide-field notice-panel"><strong>Avisos de mensualidades</strong><p>La secuencia de cinco avisos se configura desde su módulo específico.</p><button class="btn btn-secondary" type="button" data-route="payment-alerts">Abrir configuración de avisos</button></div><div class="wide-field btn-row"><button class="btn btn-primary" type="submit">Guardar cambios</button>${store.mode === 'demo' ? '<button class="btn btn-danger" type="button" data-action="reset-demo">Restablecer demo</button>' : ''}</div></form></section>`);
  }

  function renderProfile() {
    const user = currentUser(); const members = familyMembers();
    const member = isMemberPortal() ? selectedMember() : null;
    const progress = member ? (data().progreso || []).find((p) => p.socio_id === member.id) : null;
    const attendancePct = progress?.asistencias_registradas ? Math.round(Number(progress.asistencias_presentes || 0) * 100 / Number(progress.asistencias_registradas)) : 0;
    const docs = member ? (data().documentos || []).filter((d) => d.socio_id === member.id) : [];
    renderShell(`${topbar('Mi perfil', 'Cuenta, alumnos y evolución')}<section class="panel profile-panel"><div class="card-row"><div class="avatar large-avatar">${escapeHtml(initials(user.nombre))}</div><div class="card-main"><h3>${escapeHtml(user.nombre)} ${escapeHtml(user.apellidos || '')}</h3><p>${escapeHtml(user.email || '')} · ${statusBadge(user.rol)}</p></div><button class="btn btn-small btn-secondary" data-action="open-profile-form">Editar perfil</button></div>${isMemberPortal() ? `<section class="stats-grid">${stat('Asistencia', `${attendancePct}%`, `${progress?.asistencias_presentes || 0} presencias`)}${stat('Grado actual', progress?.grado_actual || member?.grado || 'Sin asignar', 'Evolución deportiva')}${stat('Seguimientos', String(progress?.observaciones_seguimiento || data().seguimiento.filter((x) => x.socio_id === member?.id).length), 'Observaciones registradas')}${stat('Última graduación', progress?.ultima_graduacion ? dateText(progress.ultima_graduacion) : '—', 'Historial')}</section><section class="section"><div class="section-head"><div><h2>Alumnos vinculados</h2><p>${members.length} perfiles</p></div>${user.rol === 'familia' ? '<button class="btn btn-small btn-primary" data-action="open-add-child-form">Añadir menor</button>' : ''}<button class="btn btn-small btn-secondary" data-action="open-add-enrollment-form">Añadir deporte o grupo</button></div>${members.map((m) => row('◎', `${m.nombre} ${m.apellidos}`, `${statusBadge(m.estado)} · ${escapeHtml(m.grado || 'Sin grado')}`, '')).join('')}</section>${member ? `<section class="section"><div class="section-head"><div><h2>Documentos</h2><p>Imágenes o PDF vinculados al alumno</p></div><button class="btn btn-small btn-primary" data-action="open-document-form">Subir documento</button></div><div class="list">${docs.map((doc) => `<button class="notification-item" data-view-document="${doc.id}"><div class="notification-icon">□</div><div class="card-main"><h3>${escapeHtml(doc.nombre)}</h3><p>${escapeHtml(doc.tipo)} · ${dateText(doc.creado_en)}</p></div></button>`).join('') || empty('No hay documentos')}</div></section>` : ''}` : ''}<div class="list-actions profile-actions"><button class="btn btn-secondary" data-route="notifications">Notificaciones</button><button class="btn btn-secondary" data-route="download">Instalar aplicación</button><button class="btn btn-danger" data-action="logout">Cerrar sesión</button></div></section>`);
  }

  function renderDownloadAuthenticated() {
    const release = config.release;
    renderShell(`${topbar('Instalar Urban Warriors', 'APK, PWA y código QR')}<section class="panel download-card"><img class="download-logo" src="${escapeHtml(config.brand.logo)}" alt="Urban Warriors" /><h2>Aplicación oficial</h2><p class="list-subtitle">Instala la aplicación en Android o añade la versión web a la pantalla de inicio.</p><div class="qr-wrap"><img src="./assets/install-qr.png" alt="Código QR de instalación" /></div><div class="btn-row" style="justify-content:center">${release.apkUrl ? `<a class="btn btn-primary" href="${escapeHtml(release.apkUrl)}">Descargar APK</a>` : `<button class="btn btn-primary" disabled>APK pendiente de publicar</button>`}<button class="btn btn-secondary" data-action="install-pwa">Instalar PWA</button><a class="btn btn-ghost" href="./assets/docs/Manual_Urban_Warriors.pdf" target="_blank" rel="noopener">Abrir manual</a></div><p class="release-meta">Versión ${escapeHtml(release.version)} · build ${escapeHtml(release.build)}</p></section>`);
  }

  function openModal(title, body, submitLabel, formId) {
    document.getElementById('modal-backdrop')?.remove();
    const modal = document.createElement('div'); modal.className = 'modal-backdrop'; modal.id = 'modal-backdrop';
    modal.innerHTML = `<section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div class="modal-head"><h2 id="modal-title">${escapeHtml(title)}</h2><button class="icon-btn" data-action="close-modal">×</button></div><div class="modal-body"><form id="${formId}">${body}<div class="form-error" data-form-error role="alert" hidden></div><div class="modal-actions"><button class="btn btn-ghost" type="button" data-action="close-modal">Cancelar</button><button class="btn btn-primary" type="button" data-action="submit-modal-form">${escapeHtml(submitLabel || 'Guardar')}</button></div></form></div></section>`;
    document.body.appendChild(modal);
  }
  function closeModal() { document.getElementById('modal-backdrop')?.remove(); }

  function finishMutation(message, options) {
    const opts = options || {};
    closeModal();
    if (opts.route) {
      const hash = `#/${opts.route}`;
      if (location.hash !== hash) history.replaceState(null, '', hash);
      state.route = opts.route;
    } else {
      state.route = getRoute();
    }
    render();
    requestAnimationFrame(() => toast(message));
  }


  function memberForm(member) {
    const d = data();
    const activeDisciplines = d.disciplinas.filter((x) => x.activa !== false || x.id === member?.disciplina_id);
    const activeGroups = d.grupos.filter((x) => x.activo !== false || x.id === member?.grupo_id);
    const activeTariffs = d.tarifas.filter((x) => x.activa !== false || x.id === member?.tarifa_id);
    openModal(member ? 'Editar alumno' : 'Alta directa de alumno', `<input type="hidden" name="id" value="${escapeHtml(member?.id || '')}" /><p class="mode-note">Alta interna por dirección o secretaría. Para solicitudes públicas utiliza Preinscripciones. Esta pantalla añade o actualiza la matrícula elegida y conserva las demás disciplinas y grupos del alumno.</p><div class="form-grid two">
      <div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(member?.nombre || '')}" required /></div>
      <div class="field"><label>Apellidos</label><input class="input" name="apellidos" value="${escapeHtml(member?.apellidos || '')}" required /></div>
      <div class="field"><label>Fecha de nacimiento</label><input class="input" name="fecha_nacimiento" type="date" value="${escapeHtml(member?.fecha_nacimiento || '')}" /></div>
      <div class="field"><label>Estado</label><select class="select" name="estado"><option value="activo" ${member?.estado==='activo'?'selected':''}>Activo</option><option value="prealta" ${member?.estado==='prealta'?'selected':''}>Prealta</option><option value="suspendido" ${member?.estado==='suspendido'?'selected':''}>Suspendido</option><option value="baja" ${member?.estado==='baja'?'selected':''}>Baja</option></select></div>
      <div class="field"><label>Teléfono</label><input class="input" name="telefono" value="${escapeHtml(member?.telefono || '')}" /></div>
      <div class="field"><label>Correo</label><input class="input" name="email" type="email" value="${escapeHtml(member?.email || '')}" /></div>
      <div class="field"><label>Tutor/a</label><input class="input" name="tutor" value="${escapeHtml(member?.tutor || '')}" /></div>
      <div class="field"><label>Contacto de emergencia</label><input class="input" name="contacto_emergencia" value="${escapeHtml(member?.contacto_emergencia || '')}" /></div>
      <div class="field"><label>Teléfono de emergencia</label><input class="input" name="telefono_emergencia" value="${escapeHtml(member?.telefono_emergencia || '')}" /></div>
      <div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" id="member-discipline" required><option value="">Sin asignar</option>${activeDisciplines.map((x) => `<option value="${x.id}" ${member?.disciplina_id === x.id ? 'selected' : ''}>${escapeHtml(x.nombre)}</option>`).join('')}</select></div>
      <div class="field"><label>Grupo</label><select class="select" name="grupo_id" id="member-group" required><option value="">Sin asignar</option>${activeGroups.map((x) => `<option data-discipline="${x.disciplina_id}" value="${x.id}" ${member?.grupo_id === x.id ? 'selected' : ''}>${escapeHtml(byId(d.disciplinas,x.disciplina_id)?.nombre || '')} · ${escapeHtml(x.nombre)}</option>`).join('')}</select></div>
      <div class="field"><label>Grado actual</label><select class="select" name="grado_id" id="member-grade"><option value="">Sin asignar</option>${d.grados.filter((g)=>g.activo!==false || g.id===member?.grado_id).map((g) => `<option data-discipline="${g.disciplina_id}" value="${g.id}" ${member?.grado_id === g.id ? 'selected' : ''}>${escapeHtml(byId(d.disciplinas,g.disciplina_id)?.nombre || '')} · ${escapeHtml(g.nombre)}</option>`).join('')}</select></div>
      <div class="field"><label>Tarifa</label><select class="select" name="tarifa_id"><option value="">Sin tarifa</option>${activeTariffs.map((t) => `<option value="${t.id}" ${member?.tarifa_id === t.id ? 'selected' : ''}>${escapeHtml(t.nombre)} · ${money(t.importe)}</option>`).join('')}</select></div>
      <div class="field wide-field"><label>Notas internas</label><textarea class="textarea" name="notas_internas">${escapeHtml(member?.notas_internas || '')}</textarea></div>
    </div>`, member ? 'Actualizar alumno' : 'Crear alumno directamente', 'member-form');
    filterMemberCatalogs();
  }

  function filterMemberCatalogs() {
    const discipline = document.getElementById('member-discipline')?.value || '';
    for (const selectId of ['member-group','member-grade']) {
      const select = document.getElementById(selectId); if (!select) continue;
      [...select.options].forEach((option, index) => { if (index) option.hidden = Boolean(discipline && option.dataset.discipline !== discipline); });
      const selected = select.selectedOptions?.[0];
      if (selected?.hidden) select.value = '';
    }
  }

  function addChildForm() {
    const d = data();
    openModal('Añadir otro menor', `<div class="form-grid two"><div class="field"><label>Nombre</label><input class="input" name="nombre" required /></div><div class="field"><label>Apellidos</label><input class="input" name="apellidos" required /></div><div class="field"><label>Fecha de nacimiento</label><input class="input" name="fecha_nacimiento" type="date" required /></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" required>${catalogOptions(d.disciplinas, '')}</select></div><div class="field"><label>Grupo preferido</label><select class="select" name="grupo_id"><option value="">Lo asignará el gimnasio</option>${catalogOptions(d.grupos, '')}</select></div></div>`, 'Enviar solicitud', 'add-child-form');
  }

  function additionalEnrollmentForm() {
    const d = data();
    const members = familyMembers();
    openModal('Añadir deporte o grupo', `<p class="mode-note">Envía una nueva solicitud para un alumno ya vinculado. Puede elegir otra disciplina o un grupo adicional de la misma disciplina.</p><div class="form-grid two"><div class="field"><label>Alumno</label><select class="select" name="socio_id" required>${catalogOptions(members, selectedMember()?.id || '')}</select></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" required><option value="">Selecciona</option>${catalogOptions(d.disciplinas.filter(x => x.activa !== false), '')}</select></div><div class="field"><label>Grupo</label><select class="select" name="grupo_id" required><option value="">Selecciona</option>${catalogOptions(d.grupos.filter(x => x.activo !== false), '')}</select></div><div class="field"><label>Tarifa</label><select class="select" name="tarifa_id"><option value="">Mantener o asignar después</option>${catalogOptions(d.tarifas.filter(x => x.activa !== false), '')}</select></div></div>`, 'Enviar solicitud', 'additional-enrollment-form');
  }

  function enrollmentForm() {
    const d = data();
    openModal('Nueva preinscripción', `<div class="form-grid two"><div class="field"><label>Tipo</label><select class="select" name="tipo_solicitud"><option value="adulto">Alumno adulto</option><option value="menor">Menor con tutor</option></select></div><div class="field"><label>Nombre</label><input class="input" name="nombre" required /></div><div class="field"><label>Apellidos</label><input class="input" name="apellidos" required /></div><div class="field"><label>Fecha de nacimiento</label><input class="input" name="fecha_nacimiento" type="date" /></div><div class="field"><label>Tutor/a</label><input class="input" name="tutor" /></div><div class="field"><label>Correo de contacto</label><input class="input" name="tutor_email" type="email" /></div><div class="field"><label>Teléfono</label><input class="input" name="telefono" required /></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id"><option value="">Sin asignar</option>${catalogOptions(d.disciplinas, '')}</select></div><div class="field"><label>Grupo</label><select class="select" name="grupo_id"><option value="">Sin asignar</option>${catalogOptions(d.grupos, '')}</select></div><div class="field"><label>Tarifa</label><select class="select" name="tarifa_id"><option value="">Sin asignar</option>${catalogOptions(d.tarifas, '')}</select></div><div class="field wide-field"><label>Observaciones</label><textarea class="textarea" name="observaciones"></textarea></div></div>`, 'Registrar solicitud', 'enrollment-form');
  }

  function disciplineForm(disc) {
    openModal(disc ? 'Editar disciplina' : 'Nueva disciplina', `<input type="hidden" name="id" value="${escapeHtml(disc?.id || '')}" /><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(disc?.nombre || '')}" required /></div><div class="field"><label>Descripción</label><textarea class="textarea" name="descripcion">${escapeHtml(disc?.descripcion || '')}</textarea></div><div class="field"><label>Color</label><input class="input" name="color" type="color" value="${escapeHtml(disc?.color || '#ffffff')}" /></div><label class="check-row"><input type="checkbox" name="activa" ${disc?.activa === false ? '' : 'checked'} /><span>Disciplina activa</span></label>`, disc ? 'Guardar cambios' : 'Crear disciplina', 'discipline-form');
  }

  function gradeForm(grade, disciplineId) {
    const d = data();
    openModal(grade ? 'Editar grado' : 'Nuevo grado', `<input type="hidden" name="id" value="${escapeHtml(grade?.id || '')}" /><div class="form-grid two"><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" required>${d.disciplinas.map((x)=>`<option value="${x.id}" ${(grade?.disciplina_id || disciplineId)===x.id?'selected':''}>${escapeHtml(x.nombre)}</option>`).join('')}</select></div><div class="field"><label>Nombre del grado</label><input class="input" name="nombre" value="${escapeHtml(grade?.nombre || '')}" required /></div><div class="field"><label>Orden de progresión</label><input class="input" name="orden" type="number" min="1" value="${escapeHtml(grade?.orden || 1)}" required /></div><div class="field"><label>Color</label><input class="input" name="color" type="color" value="${escapeHtml(grade?.color || '#ffffff')}" /></div><div class="field"><label>Meses mínimos orientativos</label><input class="input" name="meses_minimos" type="number" min="0" value="${escapeHtml(grade?.meses_minimos ?? '')}" /></div><label class="check-row"><input type="checkbox" name="activo" ${grade?.activo===false?'':'checked'} /><span>Grado activo</span></label></div>`, grade ? 'Guardar grado' : 'Crear grado', 'grade-form');
  }

  function graduationForm(memberId) {
    const d = data(); const member = byId(d.socios, memberId) || d.socios[0];
    const disciplineId = memberDisciplineIds(member)[0] || d.disciplinas[0]?.id || '';
    openModal('Registrar graduación', `<div class="form-grid two"><div class="field"><label>Alumno</label><select class="select" name="socio_id" id="graduation-member">${d.socios.map((x)=>`<option value="${x.id}" ${x.id===member?.id?'selected':''}>${escapeHtml(x.nombre)} ${escapeHtml(x.apellidos)}</option>`).join('')}</select></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" id="graduation-discipline">${d.disciplinas.map((x)=>`<option value="${x.id}" ${x.id===disciplineId?'selected':''}>${escapeHtml(x.nombre)}</option>`).join('')}</select></div><div class="field"><label>Nuevo grado</label><select class="select" name="grado_id" id="graduation-grade" required>${d.grados.filter((g)=>g.disciplina_id===disciplineId && g.activo!==false).map((g)=>`<option value="${g.id}">${escapeHtml(g.nombre)}</option>`).join('')}</select></div><div class="field"><label>Fecha</label><input class="input" name="fecha" type="date" value="${todayIso()}" required /></div><div class="field"><label>Examinador</label><input class="input" name="examinador" value="${escapeHtml(currentUser()?.nombre || '')}" /></div><div class="field wide-field"><label>Nota</label><textarea class="textarea" name="nota"></textarea></div></div>`, 'Registrar graduación', 'graduation-form');
  }

  function scheduleRow(item) {
    return `<div class="schedule-edit-row" data-schedule-row><select class="select" name="dia_semana"><option value="">Día</option>${days.slice(1).map((day,index) => `<option value="${index+1}" ${Number(item?.dia_semana) === index+1 ? 'selected' : ''}>${day}</option>`).join('')}</select><input class="input" name="hora_inicio" type="time" value="${escapeHtml(String(item?.hora_inicio || '').slice(0,5))}" /><input class="input" name="hora_fin" type="time" value="${escapeHtml(String(item?.hora_fin || '').slice(0,5))}" /><button class="btn btn-small btn-danger" type="button" data-action="remove-schedule-row">×</button></div>`;
  }

  function groupForm(group) {
    const d = data(); const schedules = group ? d.horarios.filter((h) => h.grupo_id === group.id) : [];
    openModal(group ? 'Editar grupo y horarios' : 'Crear grupo y horarios', `<input type="hidden" name="id" value="${escapeHtml(group?.id || '')}" /><div class="form-grid two"><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(group?.nombre || '')}" required /></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id" required>${d.disciplinas.map((x) => `<option value="${x.id}" ${group?.disciplina_id === x.id ? 'selected' : ''}>${escapeHtml(x.nombre)}</option>`).join('')}</select></div><div class="field"><label>Monitor</label><input class="input" name="monitor" value="${escapeHtml(group?.monitor || '')}" /></div><div class="field"><label>Sala</label><input class="input" name="sala" value="${escapeHtml(group?.sala || '')}" /></div><div class="field"><label>Plazas</label><input class="input" name="plazas" type="number" min="1" value="${escapeHtml(group?.plazas || 20)}" /></div><div class="field"><label>Edad mínima</label><input class="input" name="edad_min" type="number" min="0" value="${escapeHtml(group?.edad_min ?? '')}" /></div><div class="field"><label>Edad máxima</label><input class="input" name="edad_max" type="number" min="0" value="${escapeHtml(group?.edad_max ?? '')}" /></div><label class="check-row"><input type="checkbox" name="activo" ${group?.activo === false ? '' : 'checked'} /><span>Grupo activo</span></label></div><div class="field wide-field"><div class="section-head"><div><h3>Horarios semanales</h3><p>Se guardan junto con el grupo</p></div><button class="btn btn-small btn-secondary" type="button" data-action="add-schedule-row">Añadir horario</button></div><div id="schedule-rows">${(schedules.length ? schedules : [{}]).map(scheduleRow).join('')}</div></div>`, group ? 'Guardar grupo' : 'Crear grupo', 'group-form');
  }

  function communicationForm(item) {
    openModal(item ? 'Editar publicación' : 'Nueva publicación', `<input type="hidden" name="id" value="${escapeHtml(item?.id || '')}" /><input type="hidden" name="imagen_actual" value="${escapeHtml(item?.imagen_url || '')}" /><div class="form-grid two"><div class="field"><label>Tipo</label><select class="select" name="tipo"><option value="noticia" ${item?.tipo==='noticia'?'selected':''}>Noticia o post</option><option value="evento" ${item?.tipo==='evento'?'selected':''}>Evento</option><option value="clase" ${item?.tipo==='clase'?'selected':''}>Clase especial</option><option value="cartel" ${item?.tipo==='cartel'?'selected':''}>Cartel</option></select></div><div class="field"><label>Audiencia</label><select class="select" name="audiencia"><option value="todos" ${item?.audiencia==='todos'?'selected':''}>Todos</option><option value="familias" ${item?.audiencia==='familias'?'selected':''}>Familias y alumnos</option><option value="monitores" ${item?.audiencia==='monitores'?'selected':''}>Monitores</option></select></div><div class="field wide-field"><label>Título</label><input class="input" name="titulo" value="${escapeHtml(item?.titulo || '')}" required /></div><div class="field wide-field"><label>Texto</label><textarea class="textarea" name="cuerpo" required>${escapeHtml(item?.cuerpo || '')}</textarea></div><div class="field"><label>Fecha del evento</label><input class="input" name="evento_fecha" type="datetime-local" value="${escapeHtml(item?.evento_fecha ? String(item.evento_fecha).slice(0,16) : '')}" /></div><div class="field"><label>Ubicación</label><input class="input" name="ubicacion" value="${escapeHtml(item?.ubicacion || '')}" /></div><div class="field"><label>Estado</label><select class="select" name="estado"><option value="publicada" ${item?.estado==='publicada'?'selected':''}>Publicada</option><option value="programada" ${item?.estado==='programada'?'selected':''}>Programada</option><option value="borrador" ${item?.estado==='borrador'?'selected':''}>Borrador</option><option value="archivada" ${item?.estado==='archivada'?'selected':''}>Archivada</option></select></div><div class="field"><label>Imagen o cartel</label><input class="input" name="imagen" type="file" accept="image/jpeg,image/png,image/webp,image/gif" /></div></div>`, item ? 'Guardar publicación' : 'Publicar', 'communication-form');
  }

  function tariffForm(item) { openModal(item ? 'Editar tarifa' : 'Nueva tarifa', `<input type="hidden" name="id" value="${escapeHtml(item?.id || '')}" /><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(item?.nombre || '')}" required /></div><div class="field"><label>Importe mensual</label><input class="input" name="importe" type="number" min="0" step="0.01" value="${escapeHtml(item?.importe || '')}" required /></div><div class="field"><label>Matrícula</label><input class="input" name="matricula" type="number" min="0" step="0.01" value="${escapeHtml(item?.matricula || 0)}" /></div><div class="field"><label>Descripción</label><textarea class="textarea" name="descripcion">${escapeHtml(item?.descripcion || '')}</textarea></div><label class="check-row"><input type="checkbox" name="activa" ${item?.activa === false ? '' : 'checked'} /><span>Tarifa activa</span></label>`, item ? 'Guardar tarifa' : 'Crear tarifa', 'tariff-form'); }

  function materialForm(item) { openModal(item ? 'Editar material' : 'Añadir material', `<input type="hidden" name="id" value="${escapeHtml(item?.id || '')}" /><input type="hidden" name="imagen_actual" value="${escapeHtml(item?.imagen_url || '')}" /><div class="form-grid two"><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(item?.nombre || '')}" required /></div><div class="field"><label>Categoría</label><input class="input" name="categoria" value="${escapeHtml(item?.categoria || '')}" /></div><div class="field"><label>Disciplina</label><select class="select" name="disciplina_id"><option value="">Todas</option>${data().disciplinas.map((d) => `<option value="${d.id}" ${item?.disciplina_id===d.id?'selected':''}>${escapeHtml(d.nombre)}</option>`).join('')}</select></div><div class="field"><label>Precio</label><input class="input" name="precio" type="number" step="0.01" min="0" value="${escapeHtml(item?.precio || 0)}" /></div><div class="field"><label>Stock</label><input class="input" name="stock" type="number" min="0" value="${escapeHtml(item?.stock || 0)}" /></div><div class="field"><label>Obligatorio</label><select class="select" name="obligatorio"><option value="false" ${item?.obligatorio?'':'selected'}>No</option><option value="true" ${item?.obligatorio?'selected':''}>Sí</option></select></div><div class="field"><label>Imagen</label><input class="input" name="imagen" type="file" accept="image/jpeg,image/png,image/webp,image/gif" /></div><label class="check-row"><input type="checkbox" name="activo" ${item?.activo === false ? '' : 'checked'} /><span>Producto activo</span></label></div>`, item ? 'Guardar material' : 'Añadir material', 'material-form'); }

  function inviteForm() { openModal('Invitar personal', `<div class="field"><label>Correo</label><input class="input" name="email" type="email" required /></div><div class="field"><label>Rol</label><select class="select" name="rol"><option value="monitor">Monitor</option><option value="secretaria">Secretaría</option><option value="economia">Tesorería / Economía</option><option value="comunicacion">Comunicación</option><option value="direccion">Dirección</option></select></div><p class="mode-note">Al guardar se creará un enlace válido durante siete días para compartir con la persona invitada.</p>`, 'Crear invitación', 'invite-form'); }

  function profileForm() { const u=currentUser(); openModal('Editar mi perfil', `<div class="form-grid two"><div class="field"><label>Nombre</label><input class="input" name="nombre" value="${escapeHtml(u.nombre || '')}" required /></div><div class="field"><label>Apellidos</label><input class="input" name="apellidos" value="${escapeHtml(u.apellidos || '')}" /></div><div class="field"><label>Teléfono</label><input class="input" name="telefono" value="${escapeHtml(u.telefono || '')}" /></div></div>`, 'Guardar perfil', 'profile-form'); }

  function documentForm() { const m=selectedMember(); openModal('Subir documento', `<input type="hidden" name="socio_id" value="${escapeHtml(m?.id || '')}" /><div class="field"><label>Nombre del documento</label><input class="input" name="nombre" required /></div><div class="field"><label>Tipo</label><select class="select" name="tipo"><option value="documentacion">Documentación</option><option value="autorizacion">Autorización</option><option value="certificado">Certificado</option><option value="otro">Otro</option></select></div><div class="field"><label>Archivo</label><input class="input" name="archivo" type="file" accept="image/jpeg,image/png,image/webp,application/pdf" required /></div>`, 'Subir documento', 'document-form'); }

  function progressForm(memberId) { const d = data(); openModal('Añadir seguimiento', `<div class="field"><label>Alumno</label><select class="select" name="socio_id">${d.socios.map((s) => `<option value="${s.id}" ${memberId === s.id ? 'selected' : ''}>${escapeHtml(s.nombre)} ${escapeHtml(s.apellidos)}</option>`).join('')}</select></div><div class="field"><label>Tipo</label><select class="select" name="tipo"><option value="técnico">Técnico</option><option value="actitud">Actitud</option><option value="graduación">Preparación para graduación</option></select></div><div class="field"><label>Observación</label><textarea class="textarea" name="nota" required></textarea></div><div class="field"><label>Visibilidad</label><select class="select" name="visibilidad"><option value="equipo">Solo equipo</option><option value="familia">Visible para familia</option></select></div>`, 'Guardar seguimiento', 'progress-form'); }

  function sessionForm(session, groupId) {
    const d=data(); const selectedGroup=groupId || session?.grupo_id || d.grupos.find((g)=>g.activo!==false)?.id || '';
    openModal(session ? 'Editar sesión' : 'Nueva sesión de entrenamiento', `<input type="hidden" name="id" value="${escapeHtml(session?.id || '')}" /><div class="form-grid two"><div class="field"><label>Grupo</label><select class="select" name="grupo_id" required>${d.grupos.filter((g)=>g.activo!==false || g.id===selectedGroup).map((g)=>`<option value="${g.id}" ${g.id===selectedGroup?'selected':''}>${escapeHtml(g.nombre)}</option>`).join('')}</select></div><div class="field"><label>Fecha</label><input class="input" name="fecha" type="date" value="${escapeHtml(session?.fecha || todayIso())}" required /></div><div class="field"><label>Hora inicio</label><input class="input" name="hora_inicio" type="time" value="${escapeHtml(String(session?.hora_inicio || '18:00').slice(0,5))}" required /></div><div class="field"><label>Hora fin</label><input class="input" name="hora_fin" type="time" value="${escapeHtml(String(session?.hora_fin || '19:00').slice(0,5))}" /></div><div class="field"><label>Monitor</label><input class="input" name="monitor" value="${escapeHtml(session?.monitor || byId(d.grupos,selectedGroup)?.monitor || currentUser()?.nombre || '')}" /></div><div class="field"><label>Estado</label><select class="select" name="estado"><option value="programada" ${session?.estado==='programada'?'selected':''}>Programada</option><option value="en_curso" ${session?.estado==='en_curso'?'selected':''}>En curso</option><option value="completada" ${session?.estado==='completada'?'selected':''}>Completada</option><option value="cancelada" ${session?.estado==='cancelada'?'selected':''}>Cancelada</option></select></div><div class="field"><label>Código de acceso</label><input class="input" name="codigo_acceso" maxlength="12" value="${escapeHtml(session?.codigo_acceso || `UW${String(Date.now()).slice(-4)}`)}" /></div><div class="field wide-field"><label>Observación general</label><textarea class="textarea" name="observacion_general">${escapeHtml(session?.observacion_general || '')}</textarea></div></div>`, session ? 'Guardar sesión' : 'Crear sesión', 'session-form');
  }

  function materialVariantForm(materialId, variant) {
    const material=byId(data().material, materialId);
    openModal(variant ? 'Editar variante' : `Añadir variante · ${material?.nombre || ''}`, `<input type="hidden" name="id" value="${escapeHtml(variant?.id || '')}" /><input type="hidden" name="material_id" value="${escapeHtml(materialId)}" /><div class="form-grid two"><div class="field"><label>Talla</label><input class="input" name="talla" value="${escapeHtml(variant?.talla || '')}" /></div><div class="field"><label>Color</label><input class="input" name="color" value="${escapeHtml(variant?.color || '')}" /></div><div class="field"><label>Referencia</label><input class="input" name="referencia" value="${escapeHtml(variant?.referencia || '')}" /></div><div class="field"><label>Stock</label><input class="input" name="stock" type="number" min="0" value="${escapeHtml(variant?.stock || 0)}" /></div><label class="check-row"><input type="checkbox" name="activa" ${variant?.activa===false?'':'checked'} /><span>Variante activa</span></label></div>`, variant ? 'Guardar variante' : 'Crear variante', 'material-variant-form');
  }

  function rejectEnrollmentForm(id) {
    openModal('Rechazar preinscripción', `<input type="hidden" name="preinscripcion_id" value="${escapeHtml(id)}" /><div class="field"><label>Motivo</label><textarea class="textarea" name="motivo" required placeholder="Explica brevemente el motivo para que la familia reciba una información clara."></textarea></div>`, 'Rechazar solicitud', 'reject-enrollment-form');
  }

  function waitlistEnrollmentForm(id) {
    openModal('Pasar a lista de espera', `<input type="hidden" name="preinscripcion_id" value="${escapeHtml(id)}" /><div class="field"><label>Mensaje para la familia</label><textarea class="textarea" name="motivo" placeholder="Te avisaremos cuando haya una plaza disponible."></textarea></div>`, 'Guardar en lista de espera', 'waitlist-enrollment-form');
  }

  function paymentForm(feeId) {
    const d = data(); const member = isMemberPortal() ? selectedMember() : null; const fee = byId(d.cuotas, feeId);
    const availableFees = d.cuotas.filter((c) => (!member || c.socio_id === member.id) && !['pagada','anulada','exenta'].includes(c.estado));
    openModal(isMemberPortal() ? 'Comunicar que ya has pagado' : 'Registrar cobro', `<div class="form-grid two"><div class="field"><label>Alumno</label><select class="select" name="socio_id" ${member ? 'disabled' : ''}>${d.socios.map((s) => `<option value="${s.id}" ${member?.id === s.id || fee?.socio_id === s.id ? 'selected' : ''}>${escapeHtml(s.nombre)} ${escapeHtml(s.apellidos)}</option>`).join('')}</select>${member ? `<input type="hidden" name="socio_id" value="${member.id}" />` : ''}</div><div class="field"><label>Mensualidad</label><select class="select" name="cuota_id" required>${availableFees.map((c) => `<option value="${c.id}" ${feeId === c.id ? 'selected' : ''}>${escapeHtml(byId(d.socios,c.socio_id)?.nombre || '')} · ${escapeHtml(c.concepto)} · ${money(c.importe)}</option>`).join('')}</select></div><div class="field"><label>Importe</label><input class="input" name="importe" type="number" min="0.01" step="0.01" value="${escapeHtml(fee?.importe || '')}" required /></div><div class="field"><label>Método</label><select class="select" name="metodo"><option value="transferencia">Transferencia</option><option value="bizum">Bizum</option><option value="efectivo">Efectivo</option><option value="tarjeta">Tarjeta</option><option value="otro">Otro</option></select></div><div class="field"><label>Fecha</label><input class="input" name="fecha" type="date" value="${todayIso()}" required /></div><div class="field"><label>Referencia</label><input class="input" name="referencia" /></div><div class="field wide-field"><label>Justificante ${isMemberPortal() ? '(recomendado)' : '(opcional)'}</label><input class="input" name="justificante" type="file" accept="image/*,.pdf" /></div><div class="field wide-field"><label>Observaciones</label><textarea class="textarea" name="observaciones" placeholder="Información útil para secretaría o tesorería"></textarea></div>${isMemberPortal() ? '<p class="wide-field mode-note">Al enviarlo, los avisos automáticos se detienen hasta que el club valide o rechace el pago.</p>' : ''}</div>`, isMemberPortal() ? 'Enviar para validar' : 'Registrar cobro', 'payment-form');
  }

  function pauseFeeAlertsForm(feeId) {
    const fee = byId(data().cuotas, feeId); const member = byId(data().socios, fee?.socio_id);
    openModal('Pausar avisos de cobro', `<input type="hidden" name="cuota_id" value="${feeId}" /><p>${escapeHtml(member?.nombre || '')} ${escapeHtml(member?.apellidos || '')} · ${escapeHtml(fee?.concepto || '')}</p><div class="field"><label>Motivo</label><select class="select" name="motivo" required><option value="Cobro localizado pendiente de registrar">Cobro localizado pendiente de registrar</option><option value="Conciliación bancaria pendiente">Conciliación bancaria pendiente</option><option value="Incidencia administrativa">Incidencia administrativa</option><option value="Acuerdo con la familia">Acuerdo con la familia</option><option value="Beca o exención pendiente">Beca o exención pendiente</option><option value="Otro">Otro</option></select></div><div class="field"><label>Pausar hasta (opcional)</label><input class="input" name="hasta" type="date" /></div><div class="field"><label>Nota adicional</label><textarea class="textarea" name="nota"></textarea></div>`, 'Pausar avisos', 'pause-alerts-form');
  }

  function rejectPaymentForm(paymentId) {
    const payment = byId(data().pagos, paymentId);
    openModal('Rechazar justificante', `<input type="hidden" name="pago_id" value="${paymentId}" /><p>Pago comunicado por ${money(payment?.importe)}.</p><div class="field"><label>Motivo del rechazo</label><textarea class="textarea" name="motivo" required placeholder="Ej.: el justificante no permite identificar la operación"></textarea></div>`, 'Rechazar y reactivar avisos', 'reject-payment-form');
  }

  function materialOrderForm(materialId) {
    const m = byId(data().material, materialId); const variants = data().material_variantes.filter((v) => v.material_id === materialId && v.activa);
    openModal(`Solicitar ${m?.nombre || 'material'}`, `<input type="hidden" name="material_id" value="${materialId}" /><div class="field"><label>Alumno</label><select class="select" name="socio_id">${familyMembers().map((s) => `<option value="${s.id}" ${selectedMember()?.id === s.id ? 'selected' : ''}>${escapeHtml(s.nombre)} ${escapeHtml(s.apellidos)}</option>`).join('')}</select></div><div class="field"><label>Talla o variante</label><select class="select" name="variante_id"><option value="">Sin variante</option>${variants.map((v) => `<option value="${v.id}">${escapeHtml([v.talla, v.color].filter(Boolean).join(' · '))} · stock ${v.stock}</option>`).join('')}</select></div><div class="field"><label>Cantidad</label><input class="input" name="cantidad" type="number" min="1" max="10" value="1" /></div><p>Total unitario: <strong>${money(m?.precio)}</strong>. La solicitud deberá ser preparada por el gimnasio.</p>`, 'Solicitar material', 'material-order-form');
  }

  function checkinForm(sessionId) {
    const session = byId(data().sesiones, sessionId); const group = byId(data().grupos, session?.grupo_id);
    openModal('Registrar acceso a clase', `<input type="hidden" name="sesion_id" value="${sessionId}" /><div class="field"><label>Alumno</label><select class="select" name="socio_id">${familyMembers().filter((s) => memberInGroup(s, session?.grupo_id)).map((s) => `<option value="${s.id}">${escapeHtml(s.nombre)} ${escapeHtml(s.apellidos)}</option>`).join('')}</select></div><div class="field"><label>Código de acceso</label><input class="input code-input" name="codigo" autocomplete="one-time-code" maxlength="12" placeholder="Código mostrado en el gimnasio" required /></div><p>${escapeHtml(group?.nombre || '')} · ${dateText(session?.fecha)} ${escapeHtml(session?.hora_inicio || '')}</p>`, 'Confirmar llegada', 'checkin-form');
  }

  async function handleSubmit(event) {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;
    event.preventDefault();
    setFormBusy(form, true);
    try {
      if (form.id === 'login-form') {
        await store.login(value(form, 'email'), value(form, 'password'));
        state.selectedMemberId = null;
        await ensureAutomaticNotifications();
        go('home');
        return;
      }
      if (form.id === 'registration-form') {
        if (value(form, 'password') !== value(form, 'password_repeat')) throw new Error('Las contraseñas no coinciden.');
        const payload = Object.fromEntries(new FormData(form).entries());
        const result = await store.registerAccount(payload);
        if (result.confirmationRequired) {
          toast('Revisa tu correo para confirmar la cuenta. Después podrás iniciar sesión.');
          go('home');
          return;
        }
        await ensureAutomaticNotifications();
        toast('Cuenta creada. La preinscripción queda pendiente de revisión por el club.');
        go('home');
        return;
      }
      if (form.id === 'invited-registration-form') {
        if (value(form, 'password') !== value(form, 'password_repeat')) throw new Error('Las contraseñas no coinciden.');
        const result = await store.registerInvitedAccount({ token: value(form,'token'), email: value(form,'email'), nombre: value(form,'nombre'), apellidos: value(form,'apellidos'), telefono: value(form,'telefono'), password: value(form,'password') });
        if (result.confirmationRequired) { toast('Confirma tu correo y después inicia sesión para aceptar la invitación.'); go('home'); return; }
        toast('Cuenta de personal creada'); go('home'); return;
      }
      if (form.id === 'member-form') {
        const id = value(form, 'id');
        const payload = { nombre: value(form, 'nombre'), apellidos: value(form, 'apellidos'), fecha_nacimiento: value(form, 'fecha_nacimiento') || null, telefono: value(form, 'telefono'), email: value(form, 'email'), tutor: value(form, 'tutor'), contacto_emergencia: value(form,'contacto_emergencia'), telefono_emergencia: value(form,'telefono_emergencia'), disciplina_id: value(form, 'disciplina_id') || null, grupo_id: value(form, 'grupo_id') || null, grado_id: value(form,'grado_id') || null, tarifa_id: value(form,'tarifa_id') || null, notas_internas: value(form,'notas_internas'), estado: value(form,'estado') || 'activo' };
        if (!payload.disciplina_id || !payload.grupo_id) throw new Error('Selecciona una disciplina y un grupo para el alta directa.');
        const selectedGroup = byId(data().grupos, payload.grupo_id);
        if (!selectedGroup || selectedGroup.disciplina_id !== payload.disciplina_id) throw new Error('El grupo seleccionado no pertenece a la disciplina.');
        if (id) await store.updateMember(id, payload); else await store.createMember(payload);
        finishMutation(id ? 'Alumno actualizado y guardado en Supabase' : 'Alumno creado y guardado en Supabase', { route: 'members' }); return;
      }
      if (form.id === 'add-child-form') {
        await store.saveEnrollment({
          solicitante_perfil_id: currentUser().id,
          tipo_solicitud: 'menor',
          nombre: value(form, 'nombre'),
          apellidos: value(form, 'apellidos'),
          fecha_nacimiento: value(form, 'fecha_nacimiento'),
          tutor: `${currentUser().nombre} ${currentUser().apellidos || ''}`.trim(),
          tutor_email: currentUser().email,
          telefono: currentUser().telefono || 'Pendiente',
          disciplina_id: value(form, 'disciplina_id'),
          grupo_id: value(form, 'grupo_id'),
          estado: 'enviada'
        });
        finishMutation('Solicitud del menor enviada. Puedes consultar su estado desde tu cuenta.', { route: 'home' }); return;
      }
      if (form.id === 'additional-enrollment-form') {
        const disciplineId = value(form,'disciplina_id');
        const groupId = value(form,'grupo_id');
        const group = byId(data().grupos, groupId);
        if (!group || group.disciplina_id !== disciplineId) throw new Error('El grupo seleccionado no pertenece a la disciplina.');
        await store.requestAdditionalEnrollment(value(form,'socio_id'), disciplineId, groupId, value(form,'tarifa_id'));
        finishMutation('Solicitud enviada. El club debe aprobar la nueva matrícula.', { route: 'profile' });
        return;
      }

      if (form.id === 'enrollment-form') {
        await store.saveEnrollment({ nombre: value(form, 'nombre'), apellidos: value(form, 'apellidos'), fecha_nacimiento: value(form, 'fecha_nacimiento') || null, tutor: value(form, 'tutor'), tutor_email: value(form,'tutor_email'), telefono: value(form, 'telefono'), disciplina_id: value(form, 'disciplina_id'), grupo_id: value(form, 'grupo_id'), tarifa_id:value(form,'tarifa_id'), observaciones:value(form,'observaciones'), estado: 'enviada', fecha: todayIso(), tipo_solicitud: value(form, 'tipo_solicitud') || (value(form, 'tutor') ? 'menor' : 'adulto') });
        finishMutation('Preinscripción registrada correctamente', { route: 'enrollments' }); return;
      }
      if (form.id === 'discipline-form') { const id=value(form,'id'); const payload={ nombre:value(form,'nombre'), descripcion:value(form,'descripcion'), color:value(form,'color') || '#ffffff', activa:new FormData(form).has('activa'), orden:id ? byId(data().disciplinas,id)?.orden || 0 : data().disciplinas.length+1 }; if(id) await store.update('disciplinas',id,payload); else await store.add('disciplinas',payload); finishMutation(id?'Disciplina actualizada':'Disciplina creada', { route: 'disciplines' }); return; }
      if (form.id === 'grade-form') { const id=value(form,'id'); const fd=new FormData(form); const payload={ id:id||null, disciplina_id:value(form,'disciplina_id'), nombre:value(form,'nombre'), orden:Number(value(form,'orden')||1), color:value(form,'color')||null, meses_minimos:value(form,'meses_minimos')||null, activo:fd.has('activo') }; if(id) await store.update('grados',id,payload); else await store.add('grados',payload); finishMutation(id?'Grado actualizado':'Grado creado', { route: 'disciplines' }); return; }
      if (form.id === 'graduation-form') { await store.registerGraduation({ socio_id:value(form,'socio_id'), disciplina_id:value(form,'disciplina_id'), grado_id:value(form,'grado_id'), fecha:value(form,'fecha'), examinador:value(form,'examinador'), nota:value(form,'nota') }); finishMutation('Graduación registrada y grado actual actualizado', { route: 'members' }); return; }
      if (form.id === 'group-form') {
        const fd = new FormData(form); const id = value(form,'id');
        const scheduleDrafts = [...form.querySelectorAll('[data-schedule-row]')].map((row) => ({ dia_semana: Number(row.querySelector('[name="dia_semana"]')?.value || 0), hora_inicio: row.querySelector('[name="hora_inicio"]')?.value || '', hora_fin: row.querySelector('[name="hora_fin"]')?.value || '' }));
        for (const h of scheduleDrafts) {
          const any = Boolean(h.dia_semana || h.hora_inicio || h.hora_fin);
          const complete = Boolean(h.dia_semana && h.hora_inicio && h.hora_fin);
          if (any && !complete) throw new Error('Completa día, hora de inicio y hora de fin en cada horario.');
          if (complete && h.hora_fin <= h.hora_inicio) throw new Error('La hora de fin debe ser posterior a la hora de inicio.');
        }
        const schedules = scheduleDrafts.filter((h) => h.dia_semana && h.hora_inicio && h.hora_fin);
        await store.saveGroup({ id:id||null, nombre:value(form,'nombre'), disciplina_id:value(form,'disciplina_id'), monitor:value(form,'monitor'), sala:value(form,'sala'), plazas:value(form,'plazas'), edad_min:value(form,'edad_min'), edad_max:value(form,'edad_max'), activo:fd.has('activo') }, schedules);
        finishMutation(id?'Grupo y horarios actualizados':'Grupo y horarios creados', { route: 'schedule' }); return;
      }
      if (form.id === 'session-form') {
        const id=value(form,'id'); const start=value(form,'hora_inicio'); const end=value(form,'hora_fin'); if(end && end<=start) throw new Error('La hora de fin debe ser posterior a la hora de inicio.');
        const payload={ id:id||null, grupo_id:value(form,'grupo_id'), fecha:value(form,'fecha'), hora_inicio:start, hora_fin:end||null, monitor:value(form,'monitor'), estado:value(form,'estado')||'programada', codigo_acceso:value(form,'codigo_acceso'), observacion_general:value(form,'observacion_general') };
        if(id) await store.update('sesiones',id,payload); else await store.add('sesiones',payload);
        finishMutation(id?'Sesión actualizada':'Sesión creada', { route: 'schedule' }); return;
      }
      if (form.id === 'communication-form') {
        const fd = new FormData(form); const id=value(form,'id'); const file=fd.get('imagen');
        const previousImage = id ? (byId(data().comunicaciones,id)?.imagen_url || '') : '';
        let uploaded = '';
        try {
          uploaded = file?.size ? await store.uploadPublicMedia(file,'comunicaciones') : '';
          const eventDate=value(form,'evento_fecha') || null;
          const payload={ tipo:value(form,'tipo'), titulo:value(form,'titulo'), cuerpo:value(form,'cuerpo'), audiencia:value(form,'audiencia'), evento_fecha:eventDate, ubicacion:value(form,'ubicacion')||null, imagen_url:uploaded || value(form,'imagen_actual') || null, estado:value(form,'estado') || 'publicada', programada_para:value(form,'estado')==='programada' ? eventDate : null };
          let item; if(id) item=await store.update('comunicaciones',id,payload); else item=await store.add('comunicaciones',payload);
          if(store.mode==='demo' && !id && item.estado!=='borrador') await notifyAudience(item);
          if (uploaded && previousImage && previousImage !== uploaded) await store.removePublicMedia(previousImage).catch(()=>{});
          finishMutation(id?'Publicación actualizada':(item.estado==='borrador'?'Borrador guardado':'Publicación creada y notificada'), { route: 'communications' }); return;
        } catch (error) {
          if (uploaded) await store.removePublicMedia(uploaded).catch(()=>{});
          throw error;
        }
      }
      if (form.id === 'tariff-form') { const id=value(form,'id'); const fd=new FormData(form); const payload={ nombre:value(form,'nombre'), importe:Number(value(form,'importe')), matricula:Number(value(form,'matricula')||0), descripcion:value(form,'descripcion'), periodicidad:'mensual', activa:fd.has('activa') }; if(id) await store.update('tarifas',id,payload); else await store.add('tarifas',payload); finishMutation(id?'Tarifa actualizada':'Tarifa creada', { route: 'fees' }); return; }
      if (form.id === 'material-form') {
        const fd=new FormData(form); const id=value(form,'id'); const file=fd.get('imagen');
        const previousImage = id ? (byId(data().material,id)?.imagen_url || '') : '';
        let uploaded='';
        try {
          uploaded=file?.size ? await store.uploadPublicMedia(file,'material') : '';
          const payload={ nombre:value(form,'nombre'), categoria:value(form,'categoria')||null, disciplina_id:value(form,'disciplina_id')||null, precio:Number(value(form,'precio')||0), stock:Number(value(form,'stock')||0), obligatorio:value(form,'obligatorio')==='true', imagen_url:uploaded || value(form,'imagen_actual') || null, activo:fd.has('activo') };
          if(id) await store.update('material',id,payload); else await store.add('material',payload);
          if (uploaded && previousImage && previousImage !== uploaded) await store.removePublicMedia(previousImage).catch(()=>{});
          finishMutation(id?'Material actualizado':'Material añadido', { route: 'materials' }); return;
        } catch (error) {
          if (uploaded) await store.removePublicMedia(uploaded).catch(()=>{});
          throw error;
        }
      }
      if (form.id === 'material-variant-form') { const id=value(form,'id'); const fd=new FormData(form); const payload={ id:id||null, material_id:value(form,'material_id'), talla:value(form,'talla')||null, color:value(form,'color')||null, referencia:value(form,'referencia')||null, stock:Number(value(form,'stock')||0), activa:fd.has('activa') }; await store.saveMaterialVariant(payload); finishMutation(id?'Variante actualizada':'Variante creada', { route: 'materials' }); return; }
      if (form.id === 'invite-form') { const inv=await store.createInvitation(value(form,'email'),value(form,'rol')); const link=`${location.origin}${location.pathname}#/accept-invite?token=${inv.token}`; closeModal(); await navigator.clipboard?.writeText(link).catch(()=>{}); toast('Invitación creada; enlace copiado'); render(); return; }
      if (form.id === 'profile-form') { await store.saveOwnProfile({ nombre:value(form,'nombre'), apellidos:value(form,'apellidos'), telefono:value(form,'telefono') }); finishMutation('Perfil actualizado', { route: 'profile' }); return; }
      if (form.id === 'document-form') { const fd=new FormData(form); await store.uploadMemberDocument(value(form,'socio_id'),fd.get('archivo'),{ nombre:value(form,'nombre'), tipo:value(form,'tipo'), visible_familia:true }); finishMutation('Documento guardado', { route: 'profile' }); return; }
      if (form.id === 'waitlist-enrollment-form') { await store.waitlistEnrollment(value(form,'preinscripcion_id'),value(form,'motivo')); finishMutation('Solicitud trasladada a lista de espera y usuario informado', { route: 'enrollments' }); return; }
      if (form.id === 'reject-enrollment-form') { await store.rejectEnrollment(value(form,'preinscripcion_id'),value(form,'motivo')); finishMutation('Solicitud rechazada y usuario informado', { route: 'enrollments' }); return; }
      if (form.id === 'progress-form') { await store.saveTracking({ socio_id: value(form, 'socio_id'), tipo: value(form, 'tipo'), nota: value(form, 'nota'), visibilidad: value(form, 'visibilidad'), fecha: todayIso() }); finishMutation('Seguimiento guardado', { route: 'progress' }); return; }
      if (form.id === 'payment-form') {
        const fd = new FormData(form);
        const socioId = value(form, 'socio_id');
        const feeId = value(form, 'cuota_id');
        const file = fd.get('justificante');
        const proofPath = await store.uploadPaymentProof(socioId, file);
        const payload = { socio_id: socioId, cuota_id: feeId, importe: Number(value(form, 'importe')), fecha: value(form, 'fecha'), metodo: value(form, 'metodo'), referencia: value(form, 'referencia'), justificante_url: proofPath, observaciones: value(form, 'observaciones') };
        let payment;
        try {
          if (canManageFinance()) {
            payment = await store.registerAdminPayment(payload);
            if (store.mode === 'demo') await notifyPaymentValidated(payment);
          } else {
            payment = await store.submitPayment(payload);
            if (store.mode === 'demo') {
              for (const role of ['direccion', 'secretaria', 'economia']) {
                await store.add('notificaciones', { perfil_id: null, rol_destino: role, clave: `pago-pendiente-${payment.id}-${role}`, tipo: 'cuota', titulo: 'Justificante pendiente de validar', cuerpo: `${selectedMember()?.nombre || 'Un usuario'} ha informado un pago de ${money(payment.importe)}.`, ruta: 'fees', leida: false, creado_en: new Date().toISOString() });
              }
            }
          }
        } catch (error) {
          if (proofPath) await store.removePaymentProof(proofPath).catch(()=>{});
          throw error;
        }
        finishMutation(canManageFinance() ? 'Cobro registrado y avisos cancelados' : 'Pago enviado; los avisos quedan pausados hasta su revisión', { route: 'fees' }); return;
      }
      if (form.id === 'pause-alerts-form') {
        const reason = [value(form, 'motivo'), value(form, 'nota')].filter(Boolean).join(' · ');
        await store.pauseFeeAlerts(value(form, 'cuota_id'), reason, value(form, 'hasta') || null);
        finishMutation('Avisos pausados y acción registrada', { route: 'fees' }); return;
      }
      if (form.id === 'reject-payment-form') {
        const payment = await store.validatePayment(value(form, 'pago_id'), 'rechazado', value(form, 'motivo'));
        if (store.mode === 'demo') await notifyPaymentDecision(payment, false, value(form, 'motivo'));
        finishMutation('Justificante rechazado; la cuota vuelve a estar pendiente', { route: 'fees' }); return;
      }
      if (form.id === 'reminder-settings-form') {
        const fd = new FormData(form);
        const reminderDays = [1,2,3,4,5].map((index) => Number(value(form, `aviso_${index}`)));
        if (new Set(reminderDays).size !== 5 || reminderDays.some((day) => day < 1 || day > 28)) throw new Error('Los cinco días deben ser distintos y estar entre 1 y 28.');
        if (!reminderDays.every((day, index) => index === 0 || day > reminderDays[index - 1])) throw new Error('Los días de aviso deben estar ordenados de menor a mayor.');
        await store.saveReminderSettings({ dias_aviso: reminderDays, hora_envio: value(form, 'hora_envio'), canal_app: fd.has('canal_app'), canal_push: fd.has('canal_push'), canal_email: fd.has('canal_email'), agrupar_por_familia: fd.has('agrupar_por_familia'), marcar_vencida_dia: Number(value(form, 'marcar_vencida_dia') || 15), activo: true, zona_horaria: config.timezone || 'Europe/Madrid' });
        toast('Secuencia de cinco avisos guardada'); render(); return;
      }
      if (form.id === 'material-order-form') { const material = byId(data().material, value(form, 'material_id')); const qty = Number(value(form, 'cantidad') || 1); await store.requestMaterial({ socio_id: value(form, 'socio_id'), material_id: material.id, variante_id: value(form, 'variante_id') || null, cantidad: qty, observaciones: value(form,'observaciones') || '' }); finishMutation('Solicitud de material enviada', { route: 'materials' }); return; }
      if (form.id === 'checkin-form') { const session = byId(data().sesiones, value(form, 'sesion_id')); if (!session) throw new Error('Sesión no encontrada.'); const socioId = value(form, 'socio_id'); if (!socioId) throw new Error('Selecciona un alumno matriculado en este grupo.'); await store.registerCheckin(session.id, socioId, value(form, 'codigo'), 'codigo'); finishMutation('Acceso y asistencia registrados', { route: 'schedule' }); return; }
      if (form.id === 'settings-form') {
        Object.assign(data().club, { nombre: value(form, 'nombre'), lema: value(form, 'lema'), telefono: value(form, 'telefono'), email: value(form, 'email'), direccion: value(form, 'direccion'), color_primario: value(form, 'color_primario'), color_secundario: value(form, 'color_secundario') });
        Object.assign(data().settings, { dia_vencimiento: Number(value(form, 'dia_vencimiento') || 15), avisos_clase_horas: Number(value(form, 'avisos_clase_horas') || 3) });
        await store.persist(); toast('Configuración guardada'); render(); return;
      }
    } catch (error) {
      await handleOperationError(error, form);
    } finally {
      if (document.body.contains(form)) setFormBusy(form, false);
    }
  }

  async function handleClick(event) {
    const target = event.target.closest('[data-route],[data-action],[data-demo-role],[data-register-type],[data-edit-member],[data-member-progress],[data-member-graduation],[data-approve-enrollment],[data-waitlist-enrollment],[data-reject-enrollment],[data-edit-group],[data-create-session],[data-edit-session],[data-session],[data-group-attendance],[data-payment-fee],[data-validate-payment],[data-reject-payment],[data-view-proof],[data-pause-fee],[data-resume-fee],[data-attendance-state],[data-checkin-session],[data-buy-material],[data-advance-order],[data-notification],[data-edit-discipline],[data-add-grade],[data-edit-grade],[data-toggle-discipline],[data-edit-tariff],[data-toggle-tariff],[data-edit-material],[data-add-variant],[data-edit-variant],[data-toggle-material],[data-edit-communication],[data-archive-communication],[data-copy-invite],[data-view-document],[data-disable-enrollment],[data-receipt],[data-download-receipt]');
    if (!target) return;
    // Guardián único: ninguna acción de catálogo se ejecuta sin rol autorizado,
    // aunque el control se hubiera renderizado por error.
    if (isCatalogTarget(target) && !canManageCatalog()) {
      toast('Solo Dirección y Secretaría pueden modificar el catálogo.', 'error');
      return;
    }
    try {
      if (target.dataset.receipt) { receiptPreview(byId(data().recibos || [], target.dataset.receipt)); return; }
      if (target.dataset.downloadReceipt) { await downloadReceiptPdf(target.dataset.downloadReceipt); return; }
      if (target.dataset.route) { go(target.dataset.route); return; }
      if (target.dataset.registerType) { state.registrationType = target.dataset.registerType; go(`register-${target.dataset.registerType}`); return; }
      if (target.dataset.demoRole) { await store.loginDemo(target.dataset.demoRole); await ensureAutomaticNotifications(); go('home'); return; }
      if (target.dataset.editMember) { memberForm(byId(data().socios, target.dataset.editMember)); return; }
      if (target.dataset.disableEnrollment) {
        if (!confirm('¿Dar de baja únicamente esta matrícula? El resto de deportes y grupos del alumno se conservarán.')) return;
        await store.deactivateEnrollment(target.dataset.disableEnrollment);
        toast('Matrícula dada de baja; las demás se mantienen activas'); render(); return;
      }
      if (target.dataset.memberProgress) { progressForm(target.dataset.memberProgress); return; }
      if (target.dataset.memberGraduation) { graduationForm(target.dataset.memberGraduation); return; }
      if (target.dataset.editGroup) { groupForm(byId(data().grupos, target.dataset.editGroup)); return; }
      if (target.dataset.createSession) { sessionForm(null,target.dataset.createSession); return; }
      if (target.dataset.editSession) { sessionForm(byId(data().sesiones,target.dataset.editSession)); return; }
      if (target.dataset.editDiscipline) { disciplineForm(byId(data().disciplinas,target.dataset.editDiscipline)); return; }
      if (target.dataset.addGrade) { gradeForm(null,target.dataset.addGrade); return; }
      if (target.dataset.editGrade) { gradeForm(byId(data().grados,target.dataset.editGrade)); return; }
      if (target.dataset.toggleDiscipline) { const item=byId(data().disciplinas,target.dataset.toggleDiscipline); await store.update('disciplinas',item.id,{activa:!item.activa}); toast(item.activa?'Disciplina desactivada':'Disciplina activada'); render(); return; }
      if (target.dataset.editTariff) { tariffForm(byId(data().tarifas,target.dataset.editTariff)); return; }
      if (target.dataset.toggleTariff) { const item=byId(data().tarifas,target.dataset.toggleTariff); await store.update('tarifas',item.id,{activa:!item.activa}); toast('Tarifa actualizada'); render(); return; }
      if (target.dataset.editMaterial) { materialForm(byId(data().material,target.dataset.editMaterial)); return; }
      if (target.dataset.addVariant) { materialVariantForm(target.dataset.addVariant); return; }
      if (target.dataset.editVariant) { materialVariantForm(target.dataset.materialId,byId(data().material_variantes,target.dataset.editVariant)); return; }
      if (target.dataset.toggleMaterial) { const item=byId(data().material,target.dataset.toggleMaterial); await store.update('material',item.id,{activo:!item.activo}); toast('Material actualizado'); render(); return; }
      if (target.dataset.editCommunication) { communicationForm(byId(data().comunicaciones,target.dataset.editCommunication)); return; }
      if (target.dataset.archiveCommunication) { const item=byId(data().comunicaciones,target.dataset.archiveCommunication); await store.update('comunicaciones',item.id,{estado:item.estado==='archivada'?'publicada':'archivada'}); toast('Publicación actualizada'); render(); return; }
      if (target.dataset.copyInvite) { await navigator.clipboard.writeText(target.dataset.copyInvite); toast('Enlace copiado'); return; }
      if (target.dataset.viewDocument) { const doc=byId(data().documentos,target.dataset.viewDocument); const url=await store.getMemberDocumentUrl(doc?.storage_path); if(!url) throw new Error('Documento no disponible'); window.open(url,'_blank','noopener,noreferrer'); return; }
      if (target.dataset.session) { state.selectedSession = target.dataset.session; go('attendance'); return; }
      if (target.dataset.groupAttendance) { const groupId = target.dataset.groupAttendance; const session = data().sesiones.find((s) => s.grupo_id === groupId && s.fecha === todayIso()) || await store.add('sesiones', { grupo_id: groupId, fecha: todayIso(), hora_inicio: '18:00', estado: 'programada', monitor: currentUser().nombre, codigo_acceso: `UW${String(Date.now()).slice(-4)}` }); state.selectedSession = session.id; go('attendance'); return; }
      if (target.dataset.attendanceState) { const rowEl = target.closest('[data-student]'); rowEl.querySelectorAll('.attendance-option').forEach((button) => button.classList.remove('selected')); target.classList.add('selected'); rowEl.dataset.state = target.dataset.attendanceState; return; }
      if (target.dataset.approveEnrollment) { await approveEnrollment(target.dataset.approveEnrollment); return; }
      if (target.dataset.waitlistEnrollment) { waitlistEnrollmentForm(target.dataset.waitlistEnrollment); return; }
      if (target.dataset.rejectEnrollment) { rejectEnrollmentForm(target.dataset.rejectEnrollment); return; }
      if (target.dataset.paymentFee !== undefined) { paymentForm(target.dataset.paymentFee); return; }
      if (target.dataset.pauseFee) { pauseFeeAlertsForm(target.dataset.pauseFee); return; }
      if (target.dataset.resumeFee) { await store.resumeFeeAlerts(target.dataset.resumeFee); toast('Avisos reactivados'); render(); return; }
      if (target.dataset.validatePayment) {
        const payment = await store.validatePayment(target.dataset.validatePayment, 'validado', null);
        if (store.mode === 'demo') await notifyPaymentDecision(payment, true);
        toast('Pago validado y avisos cancelados'); render(); return;
      }
      if (target.dataset.rejectPayment) { rejectPaymentForm(target.dataset.rejectPayment); return; }
      if (target.dataset.viewProof) {
        const payment = byId(data().pagos, target.dataset.viewProof);
        const url = await store.getPaymentProofUrl(payment?.justificante_url);
        if (!url) throw new Error('Este pago no tiene justificante adjunto.');
        window.open(url, '_blank', 'noopener,noreferrer');
        return;
      }
      if (target.dataset.checkinSession) { checkinForm(target.dataset.checkinSession); return; }
      if (target.dataset.buyMaterial) { materialOrderForm(target.dataset.buyMaterial); return; }
      if (target.dataset.advanceOrder) { const order = byId(data().pedidos_material, target.dataset.advanceOrder); const next = order.estado === 'reservado' ? 'preparado' : 'entregado'; await store.updateMaterialOrder(order.id, next); toast(`Pedido marcado como ${next}`); render(); return; }
      if (target.dataset.notification) { const item = byId(data().notificaciones, target.dataset.notification); if (item && !item.leida) await store.markNotificationRead(item.id); go(target.dataset.notificationRoute || 'home'); return; }
      const action = target.dataset.action;
      if (action === 'submit-modal-form') {
        const form = target.closest('form');
        if (!form) throw new Error('No se encontró el formulario a guardar.');
        if (!form.reportValidity()) return;
        await handleSubmit({ target: form, preventDefault() {} });
        return;
      }
      if (action === 'profile') go('profile');
      else if (action === 'logout') { await store.logout(); state.selectedMemberId = null; go('home'); }
      else if (action === 'close-modal') closeModal();
      else if (action === 'open-member-form') memberForm();
      else if (action === 'open-add-child-form') addChildForm();
      else if (action === 'open-enrollment-form') enrollmentForm();
      else if (action === 'open-add-enrollment-form') additionalEnrollmentForm();
      else if (action === 'open-discipline-form') disciplineForm();
      else if (action === 'run-diagnostic') {
        try {
          const diagnostic = await store.runFinalDiagnostic();
          console.info('Diagnóstico del canal de escritura', diagnostic);
          toast('Canal de guardado verificado correctamente');
        } catch (error) {
          toast(error?.message || 'El canal de guardado sigue bloqueado', 'error');
        }
        render();
      }
      else if (action === 'open-grade-form') gradeForm();
      else if (action === 'open-group-form') groupForm();
      else if (action === 'open-session-form') sessionForm();
      else if (action === 'open-communication-form') communicationForm();
      else if (action === 'open-tariff-form') tariffForm();
      else if (action === 'open-material-form') materialForm();
      else if (action === 'open-progress-form') progressForm();
      else if (action === 'open-payment-form') paymentForm();
      else if (action === 'open-invite-form') inviteForm();
      else if (action === 'open-profile-form') profileForm();
      else if (action === 'open-document-form') documentForm();
      else if (action === 'add-schedule-row') document.getElementById('schedule-rows')?.insertAdjacentHTML('beforeend', scheduleRow({}));
      else if (action === 'remove-schedule-row') target.closest('[data-schedule-row]')?.remove();
      else if (action === 'save-attendance') await saveAttendance();
      else if (action === 'generate-fees') await generateFees();
      else if (action === 'enable-notifications') await enableDeviceNotifications();
      else if (action === 'process-reminders') {
        const date = document.getElementById('reminder-test-date')?.value || todayIso();
        const result = await store.processPaymentReminders(date);
        const count = result?.avisos_generados ?? result?.[0]?.avisos_generados ?? 0;
        toast(`Proceso completado: ${count} aviso(s) generado(s)`);
        render();
      }
      else if (action === 'mark-all-read') { for (const notification of visibleNotifications().filter((item) => !item.leida)) await store.markNotificationRead(notification.id); toast('Notificaciones marcadas como leídas'); render(); }
      else if (action === 'reset-demo') { if (confirm('¿Restablecer todos los datos de demostración?')) { await store.resetDemo(); toast('Demo restablecida'); go('home'); } }
      else if (action === 'install-pwa') installPwa();
    } catch (error) { await handleOperationError(error); }
  }

  async function approveEnrollment(id) {
    if (store.mode === 'demo') { await store.update('preinscripciones',id,{estado:'aprobada'}); }
    else await store.approveEnrollment(id);
    toast('Inscripción aprobada y alumno activado'); render();
  }

  async function saveAttendance() {
    const selected = state.selectedSession; const rows = [...document.querySelectorAll('[data-student]')];
    if (!selected) throw new Error('Selecciona una sesión.');
    for (const rowEl of rows) {
      const socioId = rowEl.dataset.student;
      const chosen = rowEl.querySelector('.attendance-option.selected')?.dataset.attendanceState || rowEl.dataset.state || 'pendiente';
      await store.saveAttendance(selected, socioId, chosen, '');
    }
    await store.update('sesiones', selected, { estado: 'completada' });
    await store.loadRemote();
    toast('Asistencia guardada en Supabase'); render();
  }

  async function generateFees() {
    const period = `${new Date().toISOString().slice(0,7)}-01`;
    if (store.mode === 'demo') { toast('La generación real se ejecuta con Supabase.'); return; }
    const result = await store.generateFees(period);
    const count = Number(Array.isArray(result) ? result[0] : result || 0);
    toast(count ? `${count} mensualidades generadas` : 'No se crearon duplicados'); render();
  }

  async function updateFeeFromPayments(feeId) {
    // Solo para la demo. En producción la cuota se recalcula dentro de la transacción del backend.
    if (store.mode !== 'demo' || !feeId) return;
    const fee = byId(data().cuotas, feeId); if (!fee) return;
    const paid = data().pagos.filter((p) => p.cuota_id === feeId && p.estado_validacion === 'validado').reduce((sum, p) => sum + Number(p.importe), 0);
    await store.update('cuotas', feeId, { estado: paid >= Number(fee.importe) ? 'pagada' : paid > 0 ? 'parcialmente_pagada' : fee.estado });
  }

  async function notifyAudience(item) {
    // Solo para la demo. En producción la puerta de mutación notifica dentro de la misma transacción.
    if (store.mode !== 'demo') return;
    const users = Object.values(data().users || {});
    const recipients = users.filter((u) => item.audiencia === 'todos' || (item.audiencia === 'familias' && ['familia', 'alumno'].includes(u.rol)) || (item.audiencia === 'monitores' && u.rol === 'monitor'));
    for (const user of recipients) await store.add('notificaciones', { perfil_id: user.id, tipo: item.tipo === 'evento' ? 'evento' : 'comunicacion', titulo: item.titulo, cuerpo: item.cuerpo, ruta: 'communications', leida: false, creado_en: new Date().toISOString() });
  }

  async function notifyPaymentValidated(payment) {
    return notifyPaymentDecision(payment, true);
  }

  async function notifyPaymentDecision(payment, accepted, reason) {
    // Solo para la demo. En producción la RPC de pago genera la notificación transaccionalmente.
    if (store.mode !== 'demo') return;
    const member = byId(data().socios, payment?.socio_id);
    const profileId = member?.tutor_perfil_id || member?.perfil_id;
    if (!profileId) return;
    await store.add('notificaciones', {
      perfil_id: profileId,
      tipo: 'cuota',
      titulo: accepted ? 'Pago validado' : 'Justificante no validado',
      cuerpo: accepted ? `Se ha validado el pago de ${money(payment.importe)}.` : `No se ha podido validar el pago de ${money(payment.importe)}.${reason ? ` Motivo: ${reason}` : ''}`,
      ruta: 'fees', leida: false, creado_en: new Date().toISOString()
    });
  }

  async function ensureAutomaticNotifications() {
    if (!currentUser() || !data().notificaciones) return;
    // En producción los avisos los generan Supabase Cron y las Edge Functions.
    if (store.mode !== 'demo') return;
    await store.processPaymentReminders(todayIso());
    if (!isMemberPortal()) return;
    for (const member of familyMembers()) {
      const profileId = currentUser().id;
      for (const session of data().sesiones.filter((item) => memberGroupIds(member).includes(item.grupo_id) && item.fecha === todayIso())) {
        const key = `session-${session.id}-${member.id}`;
        if (!data().notificaciones.some((notification) => notification.clave === key && notification.perfil_id === profileId)) {
          await store.add('notificaciones', { perfil_id: profileId, clave: key, tipo: 'clase', titulo: 'Clase hoy', cuerpo: `${member.nombre} tiene clase a las ${session.hora_inicio}.`, ruta: 'schedule', leida: false, creado_en: new Date().toISOString() });
        }
      }
    }
  }

  async function enableDeviceNotifications() {
    if (window.UW_PUSH?.configured?.()) {
      const token = await window.UW_PUSH.requestPermissionAndToken();
      await store.registerPushToken(token, 'web');
      toast('Notificaciones push activadas en este dispositivo');
      return;
    }
    // La APK puede exponer un puente nativo; la PWA utiliza la API web.
    if (window.UrbanWarriorsNative?.requestNotifications) {
      const token = await window.UrbanWarriorsNative.requestNotifications();
      if (token) await store.registerPushToken(token, 'android');
      toast('Alertas del dispositivo activadas');
      return;
    }
    if (!('Notification' in window)) { toast('Este dispositivo no admite notificaciones web.', 'error'); return; }
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
      new Notification('Urban Warriors', { body: 'Las alertas del dispositivo están activadas.', icon: config.brand.logo });
      toast(config.push?.enabled ? 'Permiso concedido. Falta registrar el token FCM al publicar.' : 'Alertas locales activadas. El push remoto se habilita al configurar Firebase.');
    } else toast('No se concedió permiso para mostrar alertas.', 'error');
  }

  let deferredInstall = null;
  window.addEventListener('beforeinstallprompt', (event) => { event.preventDefault(); deferredInstall = event; });
  async function installPwa() { if (deferredInstall) { deferredInstall.prompt(); await deferredInstall.userChoice; deferredInstall = null; } else toast('En Android: menú del navegador → Añadir a pantalla de inicio.'); }

  function render() {
    state.route = getRoute();
    if (!currentUser()) {
      if (state.route === 'register') renderRegisterChoice();
      else if (state.route === 'register-adulto') renderRegistration('adulto');
      else if (state.route === 'register-tutor') renderRegistration('tutor');
      else if (state.route === 'staff') renderLogin(true);
      else if (state.route === 'accept-invite') renderInviteRegistration();
      else if (state.route === 'download') renderPublicDownload();
      else renderLogin(false);
      bindDynamic(); return;
    }
    const routeMap = { home: renderHome, members: renderMembers, enrollments: renderEnrollments, schedule: renderSchedule, groups: renderGroups, attendance: renderAttendance, fees: renderFees, communications: renderCommunications, progress: renderProgress, notifications: renderNotifications, more: renderMore, users: renderUsers, disciplines: renderDisciplines, materials: renderMaterials, 'payment-alerts': renderPaymentAlerts, settings: renderSettings, profile: renderProfile, download: renderDownloadAuthenticated };
    (routeMap[state.route] || renderHome)(); bindDynamic();
  }

  function bindDynamic() {
    const search = document.getElementById('member-search'); if (search) search.addEventListener('input', (e) => { state.query = e.target.value; renderMembers(); document.getElementById('member-search')?.focus(); });
    const sessionSelect = document.getElementById('session-select'); if (sessionSelect) sessionSelect.addEventListener('change', (e) => { state.selectedSession = e.target.value; renderAttendance(); });
    const profileSwitch = document.getElementById('profile-switch'); if (profileSwitch) profileSwitch.addEventListener('change', (e) => { state.selectedMemberId = e.target.value; render(); });
    const memberDiscipline = document.getElementById('member-discipline'); if (memberDiscipline) memberDiscipline.addEventListener('change', filterMemberCatalogs);
    const graduationDiscipline = document.getElementById('graduation-discipline'); if (graduationDiscipline) graduationDiscipline.addEventListener('change', (e) => { const select=document.getElementById('graduation-grade'); if(!select) return; const grades=data().grados.filter((g)=>g.disciplina_id===e.target.value && g.activo!==false); select.innerHTML=grades.map((g)=>`<option value="${g.id}">${escapeHtml(g.nombre)}</option>`).join(''); });
  }

  document.addEventListener('click', handleClick);
  document.addEventListener('submit', handleSubmit);
  window.addEventListener('hashchange', render);
  window.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeModal(); });

  (async function boot() {
    try {
      await store.init();
      state.route = getRoute();
      if (currentUser()) await ensureAutomaticNotifications();
      render();
    } catch (error) {
      if (error?.code === 'AUTH_EXPIRED') {
        await store.logout().catch(() => {});
        render();
        toast('La sesión anterior había caducado. Inicia sesión de nuevo.', 'error');
        return;
      }
      app.innerHTML = `<main class="login-page"><section class="panel login-panel"><h2>No se pudo iniciar la aplicación</h2><p>${escapeHtml(error.message)}</p><button class="btn btn-primary" onclick="location.reload()">Reintentar</button></section></main>`;
    }
  })();
})();
