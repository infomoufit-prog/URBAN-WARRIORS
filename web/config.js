window.UW_CONFIG = {
  appName: 'KOMBAX',
  clubSlug: 'urban-warriors',
  primaryClubId: '11111111-1111-4111-8111-111111111111',
  locale: 'es-ES',
  currency: 'EUR',
  timezone: 'Europe/Madrid',
  supabase: {
    enabled: true,
    url: 'https://poggsobhtutbuagjiydc.supabase.co',
    anonKey: 'sb_publishable_wLRr_1E8WmJcOW_gd-VH4g_KquHKiL3'
  },
  release: {
    version: '2.0.0-rc.13',
    build: 20065,
    backendVersion: '1.6.0',
    schemaEpoch: 160,
    mutationEndpoint: 'app_mutate_v160',
    contractEndpoint: 'app_runtime_contract_v160',
    probeEndpoint: 'app_write_channel_probe_v160',
    diagnosticEndpoint: 'app_diagnostico_final_v166',
    requiredOperations: [
      'perfil_deportivo.guardar','perfil_deportivo.foto','perfil_deportivo.moderar','comunidad.like',
      'evento.guardar','evento.estado','evento.participante.externo','evento.inscripcion.solicitar',
      'evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar',
      'notificacion.revisar','club_publico.guardar','comunidad.denunciar',
      'comunidad.bloquear','comunidad.denuncia.estado','comunidad_general.moderar_acceso'
    ],
    webUrl: 'https://urban01.netlify.app'
  },
  features: {
    kombaxGateway: true,
    directProfiles: true,
    kombaxSocial: true,
    kombaxShowcase: true,
    demoDirectory: false,
    showcaseDemo: false
  },
  brand: {
    name: 'Urban Warriors',
    slogan: 'Bring the Pain',
    logo: './assets/urban-warriors-logo.png'
  }
};
