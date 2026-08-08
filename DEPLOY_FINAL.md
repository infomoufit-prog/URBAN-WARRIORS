# Despliegue final · un solo ciclo Netlify

## Objetivo

No usar Netlify para depuración iterativa. Certificar primero desde localhost contra el Supabase real y hacer después un único deploy final.

## Paso A · Certificación local

1. Instalar Node.js 20+ si no está disponible.
2. Abrir una terminal en la raíz del proyecto.
3. Ejecutar:
   `npm run build`
4. Ejecutar:
   `npm run dev`
5. Abrir `http://127.0.0.1:4173`.
6. Iniciar sesión como Dirección.
7. Abrir **Certificación E2E**.
8. Introducir la contraseña únicamente cuando el runner la solicite para comprobar logout/login.
9. Ejecutar la certificación completa.
10. Exportar el JSON de resultados.

Si un control falla, corregir localmente y repetir; no subir a Netlify.

## Paso B · Build final

Cuando el runner haya superado los controles:
`npm run build`

Comprobar que termina con igualdad Web = dist = Android.

## Paso C · GitHub / Netlify

1. Copiar esta RC al repositorio local de Urban Warriors.
2. GitHub Desktop → revisar cambios.
3. Commit sugerido:
   `Urban Warriors 2.0.0-rc.1 - reconstrucción frontend`
4. Push origin.
5. Netlify realizará el único deploy.
6. Confirmar `Published`.

## Paso D · Smoke final de producción

Desde una ventana privada:
- login;
- abrir Diagnóstico y comprobar contrato/probe;
- crear una disciplina E2E pequeña o ejecutar el runner si se desea la repetición completa;
- recargar;
- logout/login;
- confirmar persistencia.

Si el smoke coincide con la certificación local, fijar esta RC como base estable.

## Supabase

Esta RC no requiere una nueva migración. Usa el backend ya existente 1.6.0 / epoch 160.
