/* Urban Warriors runtime configuration.
 * This file can be edited after deployment without rebuilding the app.
 */
window.UW_CONFIG = {
  appName: 'Urban Warriors',
  clubSlug: 'urban-warriors',
  primaryClubId: '11111111-1111-4111-8111-111111111111',
  locale: 'es-ES',
  currency: 'EUR',
  timezone: 'Europe/Madrid',
  demoMode: false,
  supabase: {
    enabled: true,
    url: 'https://poggsobhtutbuagjiydc.supabase.co',
    anonKey: 'sb_publishable_wLRr_1E8WmJcOW_gd-VH4g_KquHKiL3',
  },
  release: {
    version: '1.6.0',
    build: 12,
    apkUrl: '',
    webUrl: 'https://urban01.netlify.app',
    publishedAt: '2026-08-07',
    backendVersion: '1.6.0',
    schemaEpoch: 160
  },
  push: {
    enabled: false,
    vapidKey: '',
    firebase: {
      apiKey: '',
      authDomain: '',
      projectId: '',
      storageBucket: '',
      messagingSenderId: '',
      appId: ''
    }
  },
  brand: {
    name: 'Urban Warriors',
    slogan: 'Bring the Pain',
    logo: './assets/urban-warriors-logo.png',
    primary: '#ffffff',
    secondary: '#050608',
    accent: '#9ca3af'
  }
};
