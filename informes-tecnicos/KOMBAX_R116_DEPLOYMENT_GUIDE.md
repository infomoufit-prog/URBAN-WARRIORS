# KOMBAX R116 — Guía de despliegue piloto

## 1. Verificar local

En CMD, dentro de la carpeta R116:

```bat
KOMBAX_R116_VERIFY_LOCAL.cmd
```

Después:

```bat
npm run dev
```

Abrir `http://127.0.0.1:4173`. Validar login, cuenta gratuita, los 8 recorridos, Miembro/Familiar, Competidor, Social, Events, Showcase, Owner y página de planes sin precios.

## 2. Supabase — no usar db push global

Proyecto esperado: `poggsobhtutbuagjiydc`.

En Supabase Dashboard > SQL Editor, ejecutar por separado:

1. `supabase/deploy/KOMBAX_R116_SUPABASE_PREFLIGHT.sql`
2. Si todo está correcto: `supabase/deploy/KOMBAX_R116_REQUIRED_PATCH.sql`
3. `supabase/deploy/KOMBAX_R116_SUPABASE_POSTFLIGHT.sql`

Todos los booleanos del postflight deben ser `true`.

Después, con Supabase CLI autenticada:

```bat
KOMBAX_R116_DEPLOY_SUPABASE_FUNCTIONS.cmd
```

No despliega todas las funciones: solo `notification-dispatch`, `kombax-owner-report-r114` y `health`.

### Smoke tests remotos

- Health debe devolver build `20169`.
- Crear una notificación de miembro y confirmar push.
- Crear/usar una alerta Owner global y confirmar que encuentra tokens sin `club_id`.
- Generar PDF Owner y abrir la URL firmada.
- Confirmar que Miembro sin membresía aprobada no publica.
- Confirmar que Miembro aprobado sí puede activar Social según edad/reglas.
- Confirmar Competidor verificado autónomo.

## 3. Netlify

La configuración de release usa Node 22, `npm run release:build` y publica `dist`.

Instalar/autenticar CLI si no está disponible:

```bat
npm install -g netlify-cli
netlify login
```

Desde R116:

```bat
netlify link
```

Seleccionar el proyecto KOMBAX/urban01 existente. No crear uno nuevo por error.

Preview recomendado:

```bat
npm run release:build
netlify deploy --dir=dist
```

Validar la URL de preview. Después:

```bat
KOMBAX_R116_DEPLOY_NETLIFY.cmd
```

Verificar `https://kombax.es`, service worker, login, Social, Showcase, Events, Owner, privacidad, términos y eliminación de cuenta.

## 4. APK de prueba

Con JDK 17 o 21 y acceso a Internet para que Gradle/Maven descarguen dependencias:

```bat
KOMBAX_R116_BUILD_ANDROID_QA.cmd
```

Salida esperada:

`artifacts\KOMBAX_20169_R116_GOLDEN_PILOT_QA_DEBUG.apk`

## 5. AAB Google Play

Crear `android/keystore.properties` a partir de `android/keystore.properties.example` usando **la upload key ya registrada para la app**, o definir:

- `UW_KEYSTORE_PATH`
- `UW_KEYSTORE_PASSWORD`
- `UW_KEY_ALIAS`
- `UW_KEY_PASSWORD`

No generar una upload key nueva si Google Play ya conoce otra, salvo proceso formal de reset de upload key.

Ejecutar:

```bat
KOMBAX_R116_BUILD_ANDROID_PLAY.cmd
```

Salidas esperadas:

- `artifacts\KOMBAX_20169_R116_GOLDEN_PILOT_GOOGLE_PLAY.aab`
- `artifacts\KOMBAX_20169_R116_GOLDEN_PILOT_SIGNED.apk`

## 6. Play Console

R116 usa `targetSdk 36`, requerido para nuevas apps/actualizaciones desde 31/08/2026.

Para el piloto, subir el AAB a **Prueba interna** o **Prueba cerrada**. Si la cuenta es personal creada después del 13/11/2023 y se pretende pedir acceso a producción, Google exige una prueba cerrada con al menos 12 testers inscritos de forma continua durante 14 días.

Checklist de Play:

- ficha de Store completa;
- Data safety;
- privacidad pública;
- URL de eliminación de cuenta;
- Child Safety si corresponde;
- clasificación de contenido;
- acceso a la app/instrucciones si hay login;
- países/regiones de la prueba;
- testers añadidos y enlace de opt-in compartido;
- AAB con `versionCode 20169`;
- upload key correcta.

## 7. Qué no está automatizado

Esta entrega no incluye credenciales privadas, keystore ni contraseñas. Tampoco debe incluirlas. La firma y el acceso a Netlify/Play Console deben ejecutarse con las credenciales del titular.
