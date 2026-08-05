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
  demoMode: true,
  supabase: {
    enabled: false,
    url: '',
    anonKey: ''
  },
  release: {
    version: '1.2.0',
    build: 3,
    apkUrl: '',
    webUrl: '',
    publishedAt: '2026-08-05'
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
