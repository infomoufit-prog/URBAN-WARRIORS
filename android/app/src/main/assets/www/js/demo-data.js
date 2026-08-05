(function () {
  const today = new Date();
  const iso = (date) => date.toISOString().slice(0, 10);
  const plusDays = (n) => {
    const d = new Date(today);
    d.setDate(d.getDate() + n);
    return iso(d);
  };

  window.UW_DEMO_SEED = {
    club: {
      id: '11111111-1111-4111-8111-111111111111',
      nombre: 'Urban Warriors',
      slug: 'urban-warriors',
      lema: 'Bring the Pain',
      cif: '',
      telefono: '+34 600 000 000',
      email: 'info@urbanwarriors.local',
      direccion: 'Configurar dirección del gimnasio',
      color_primario: '#ffffff',
      color_secundario: '#050608',
      logo_url: './assets/urban-warriors-logo.png'
    },
    users: {
      admin: { id: 'demo-admin', nombre: 'Administración', rol: 'direccion', email: 'admin@urbanwarriors.demo', socio_ids: [] },
      monitor: { id: 'demo-monitor', nombre: 'Álex', rol: 'monitor', email: 'monitor@urbanwarriors.demo', socio_ids: [] },
      family: { id: 'demo-family', nombre: 'Marta', apellidos: 'Martínez', rol: 'familia', email: 'familia@urbanwarriors.demo', socio_ids: ['s1','s5'] }
    },
    accounts: [
      { email: 'admin@urbanwarriors.demo', password: 'demo1234', user_key: 'admin' },
      { email: 'monitor@urbanwarriors.demo', password: 'demo1234', user_key: 'monitor' },
      { email: 'familia@urbanwarriors.demo', password: 'demo1234', user_key: 'family' }
    ],
    disciplinas: [
      { id: 'd1', nombre: 'Muay Thai', descripcion: 'Técnica, acondicionamiento y combate.', color: '#ffffff', activa: true, orden: 1 },
      { id: 'd2', nombre: 'Kickboxing', descripcion: 'Trabajo de golpeo, coordinación y resistencia.', color: '#d1d5db', activa: true, orden: 2 },
      { id: 'd3', nombre: 'Boxeo', descripcion: 'Fundamentos, técnica y preparación física.', color: '#9ca3af', activa: true, orden: 3 }
    ],
    grados: [
      { id: 'gr1', disciplina_id: 'd1', nombre: 'Inicial', orden: 1 },
      { id: 'gr2', disciplina_id: 'd1', nombre: 'Intermedio', orden: 2 },
      { id: 'gr3', disciplina_id: 'd1', nombre: 'Avanzado', orden: 3 }
    ],
    grupos: [
      { id: 'g1', disciplina_id: 'd1', nombre: 'Infantil', monitor: 'Álex', edad_min: 7, edad_max: 13, plazas: 20, activos: 14, activo: true },
      { id: 'g2', disciplina_id: 'd1', nombre: 'Adultos tarde', monitor: 'Álex', edad_min: 14, edad_max: null, plazas: 24, activos: 19, activo: true },
      { id: 'g3', disciplina_id: 'd2', nombre: 'Adultos noche', monitor: 'Nerea', edad_min: 16, edad_max: null, plazas: 22, activos: 17, activo: true }
    ],
    horarios: [
      { id: 'h1', grupo_id: 'g1', dia_semana: 2, hora_inicio: '17:00', hora_fin: '18:00' },
      { id: 'h2', grupo_id: 'g1', dia_semana: 4, hora_inicio: '17:00', hora_fin: '18:00' },
      { id: 'h3', grupo_id: 'g2', dia_semana: 2, hora_inicio: '18:30', hora_fin: '20:00' },
      { id: 'h4', grupo_id: 'g2', dia_semana: 4, hora_inicio: '18:30', hora_fin: '20:00' },
      { id: 'h5', grupo_id: 'g3', dia_semana: 1, hora_inicio: '20:00', hora_fin: '21:30' },
      { id: 'h6', grupo_id: 'g3', dia_semana: 3, hora_inicio: '20:00', hora_fin: '21:30' }
    ],
    socios: [
      { id: 's1', nombre: 'Leo', apellidos: 'Martínez', fecha_nacimiento: '2015-04-12', telefono: '', email: '', estado: 'activo', grupo_id: 'g1', disciplina_id: 'd1', grado: 'Inicial', tutor: 'Marta Martínez', tutor_perfil_id: 'demo-family', cuota_estado: 'pagada' },
      { id: 's2', nombre: 'Hugo', apellidos: 'Sánchez', fecha_nacimiento: '2013-11-03', telefono: '', email: '', estado: 'activo', grupo_id: 'g1', disciplina_id: 'd1', grado: 'Intermedio', tutor: 'Laura Sánchez', cuota_estado: 'pendiente' },
      { id: 's3', nombre: 'Paula', apellidos: 'Ruiz', fecha_nacimiento: '1998-06-21', telefono: '600 123 123', email: 'paula@example.com', estado: 'activo', grupo_id: 'g2', disciplina_id: 'd1', grado: 'Inicial', tutor: '', cuota_estado: 'pagada' },
      { id: 's4', nombre: 'Marc', apellidos: 'Vidal', fecha_nacimiento: '1994-02-09', telefono: '600 222 222', email: 'marc@example.com', estado: 'activo', grupo_id: 'g3', disciplina_id: 'd2', grado: 'Inicial', tutor: '', cuota_estado: 'vencida' },
      { id: 's5', nombre: 'Nora', apellidos: 'Martínez', fecha_nacimiento: '2012-09-18', telefono: '', email: '', estado: 'activo', grupo_id: 'g1', disciplina_id: 'd1', grado: 'Inicial', tutor: 'Marta Martínez', tutor_perfil_id: 'demo-family', cuota_estado: 'pendiente' }
    ],
    preinscripciones: [
      { id: 'p1', nombre: 'Noa', apellidos: 'García', edad: 10, tutor: 'Sergio García', telefono: '600 333 333', disciplina_id: 'd1', grupo_id: 'g1', estado: 'en_revision', fecha: plusDays(-2), tipo_solicitud: 'menor' },
      { id: 'p2', nombre: 'Eric', apellidos: 'López', edad: 19, tutor: '', telefono: '600 444 444', disciplina_id: 'd2', grupo_id: 'g3', estado: 'pendiente_documentacion', fecha: plusDays(-1), tipo_solicitud: 'adulto' }
    ],
    tarifas: [
      { id: 't1', nombre: 'Infantil', importe: 35, periodicidad: 'mensual', activa: true },
      { id: 't2', nombre: 'Adultos', importe: 45, periodicidad: 'mensual', activa: true },
      { id: 't3', nombre: 'Ilimitado', importe: 60, periodicidad: 'mensual', activa: true }
    ],
    cuotas: [
      { id: 'c1', socio_id: 's1', concepto: 'Cuota mensual', periodo: iso(new Date(today.getFullYear(), today.getMonth(), 1)), importe: 35, vencimiento: plusDays(5), estado: 'pagada' },
      { id: 'c2', socio_id: 's2', concepto: 'Cuota mensual', periodo: iso(new Date(today.getFullYear(), today.getMonth(), 1)), importe: 35, vencimiento: plusDays(5), estado: 'pendiente' },
      { id: 'c3', socio_id: 's3', concepto: 'Cuota mensual', periodo: iso(new Date(today.getFullYear(), today.getMonth(), 1)), importe: 45, vencimiento: plusDays(5), estado: 'pagada' },
      { id: 'c4', socio_id: 's4', concepto: 'Cuota mensual', periodo: iso(new Date(today.getFullYear(), today.getMonth(), 1)), importe: 45, vencimiento: plusDays(-3), estado: 'vencida', avisos_pausados: false },
      { id: 'c5', socio_id: 's5', concepto: 'Cuota mensual', periodo: iso(new Date(today.getFullYear(), today.getMonth(), 1)), importe: 35, vencimiento: iso(new Date(today.getFullYear(), today.getMonth(), 15)), estado: 'pendiente', avisos_pausados: false }
    ],
    pagos: [
      { id: 'pg1', cuota_id: 'c1', socio_id: 's1', importe: 35, fecha: plusDays(-3), metodo: 'bizum', referencia: 'UW-LEO-08', estado_validacion: 'validado' },
      { id: 'pg2', cuota_id: 'c3', socio_id: 's3', importe: 45, fecha: plusDays(-4), metodo: 'transferencia', referencia: 'AGO-PAULA', estado_validacion: 'validado' }
    ],
    sesiones: [
      { id: 'se1', grupo_id: 'g1', fecha: iso(today), hora_inicio: '17:00', hora_fin: '18:00', estado: 'programada', monitor: 'Álex', codigo_acceso: 'UW1700' },
      { id: 'se2', grupo_id: 'g2', fecha: iso(today), hora_inicio: '18:30', hora_fin: '20:00', estado: 'programada', monitor: 'Álex', codigo_acceso: 'UW1830' }
    ],
    asistencias: [
      { id: 'a1', sesion_id: 'se1', socio_id: 's1', estado: 'presente' },
      { id: 'a2', sesion_id: 'se1', socio_id: 's2', estado: 'pendiente' }
    ],
    registros_acceso: [
      { id: 'ra1', sesion_id: 'se1', socio_id: 's1', registrado_en: new Date().toISOString(), metodo: 'codigo', resultado: 'permitido' }
    ],
    comunicaciones: [
      { id: 'co1', tipo: 'noticia', titulo: 'Bienvenida a la nueva app', cuerpo: 'Ya puedes consultar horarios, cuotas, material y avisos desde el móvil.', audiencia: 'todos', fecha: plusDays(-1), estado: 'publicada', imagen_url: './assets/urban-warriors-logo.png', destacado: true },
      { id: 'co2', tipo: 'evento', titulo: 'Entrenamiento abierto', cuerpo: 'El sábado realizaremos una sesión abierta para familias.', audiencia: 'familias', fecha: plusDays(2), evento_fecha: plusDays(2), ubicacion: 'Sala principal', estado: 'programada', imagen_url: '', destacado: false }
    ],
    seguimiento: [
      { id: 'sg1', socio_id: 's1', fecha: plusDays(-8), tipo: 'técnico', nota: 'Buena mejora en guardia y desplazamientos.', visibilidad: 'familia' }
    ],
    consentimientos: [
      { id: 'cn1', socio_id: 's1', tipo: 'privacidad', version: '1.0', aceptado: true, fecha: plusDays(-30) },
      { id: 'cn2', socio_id: 's1', tipo: 'imagen', version: '1.0', aceptado: false, fecha: null }
    ],
    material: [
      { id: 'm1', nombre: 'Guantes de entrenamiento', disciplina_id: 'd1', categoria: 'protección', precio: 35, obligatorio: true, stock: 12, imagen_url: '' },
      { id: 'm2', nombre: 'Camiseta Urban Warriors', disciplina_id: null, categoria: 'equipación', precio: 18, obligatorio: false, stock: 24, imagen_url: './assets/urban-warriors-logo.png' }
    ],
    material_variantes: [
      { id: 'mv1', material_id: 'm1', talla: '10 oz', color: 'Negro', stock: 6, activa: true },
      { id: 'mv2', material_id: 'm1', talla: '12 oz', color: 'Negro', stock: 6, activa: true },
      { id: 'mv3', material_id: 'm2', talla: 'M', color: 'Negro', stock: 10, activa: true },
      { id: 'mv4', material_id: 'm2', talla: 'L', color: 'Negro', stock: 14, activa: true }
    ],
    pedidos_material: [
      { id: 'pm1', socio_id: 's1', material_id: 'm2', variante_id: 'mv3', cantidad: 1, importe_total: 18, estado: 'reservado', creado_en: new Date().toISOString() }
    ],
    notificaciones: [
      { id: 'n1', perfil_id: 'demo-family', tipo: 'cuota', titulo: 'Cuota al día', cuerpo: 'La cuota de Leo consta como pagada.', ruta: 'fees', leida: false, programada_para: null, creado_en: new Date().toISOString() },
      { id: 'n2', perfil_id: 'demo-family', tipo: 'clase', titulo: 'Clase hoy', cuerpo: 'Leo tiene clase a las 17:00.', ruta: 'schedule', leida: false, programada_para: null, creado_en: new Date().toISOString() },
      { id: 'n3', perfil_id: null, rol_destino: 'direccion', tipo: 'inscripcion', titulo: 'Nueva preinscripción', cuerpo: 'Hay una solicitud pendiente de revisar.', ruta: 'enrollments', leida: false, programada_para: null, creado_en: new Date().toISOString() }
    ],
    historial_avisos_cuota: [
      { id: 'ha1', cuota_id: 'c5', perfil_id: 'demo-family', aviso_numero: 1, fecha_programada: iso(new Date(today.getFullYear(), today.getMonth(), 1)), canal: 'app', estado: 'enviado', enviado_en: new Date().toISOString() },
      { id: 'ha2', cuota_id: 'c5', perfil_id: 'demo-family', aviso_numero: 2, fecha_programada: iso(new Date(today.getFullYear(), today.getMonth(), 4)), canal: 'app', estado: 'enviado', enviado_en: new Date().toISOString() }
    ],
    settings: {
      dia_vencimiento: 15,
      dia_generacion: 1,
      dias_avisos_cobro: [1, 4, 8, 11, 14],
      hora_envio: '10:00',
      zona_horaria: 'Europe/Madrid',
      canal_app: true,
      canal_push: true,
      canal_email: false,
      agrupar_por_familia: true,
      marcar_vencida_dia: 15,
      avisos_clase_horas: 3,
      idioma: 'es',
      direccion: 'Configurar dirección del gimnasio',
      telefono: '+34 600 000 000',
      email: 'info@urbanwarriors.local'
    }
  };
})();
