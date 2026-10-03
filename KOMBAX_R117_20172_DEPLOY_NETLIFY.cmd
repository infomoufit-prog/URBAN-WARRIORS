@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20172 - DEPLOY NETLIFY REGISTRO/AUTH
echo ================================================================
where node >nul 2>nul || (echo ERROR: Node.js no esta disponible.& exit /b 1)
where netlify >nul 2>nul || (
  echo ERROR: Netlify CLI no esta instalado.
  echo Ejecuta primero: npm install -g netlify-cli
  exit /b 1
)
call npm run verify:20172
if errorlevel 1 exit /b 1
node scripts/release-netlify-r104-3.mjs
if errorlevel 1 exit /b 1
netlify status
if errorlevel 1 (
  echo.
  echo Este directorio no esta enlazado a un sitio Netlify.
  echo Ejecuta: netlify login
  echo Despues: netlify link
  echo Selecciona EXPLICITAMENTE el sitio KOMBAX de kombax.es y vuelve a ejecutar este CMD.
  exit /b 2
)
echo.
echo IMPORTANTE: verifica arriba que el sitio enlazado es KOMBAX/kombax.es.
echo Se publicara dist como PRODUCCION.
set /p CONFIRM=Escribe DESPLEGAR para continuar: 
if /I not "%CONFIRM%"=="DESPLEGAR" (echo Cancelado.& exit /b 3)
netlify deploy --prod --dir=dist
if errorlevel 1 exit /b 1
echo.
echo OK: deploy Netlify solicitado para build 20172.
echo Realiza despues smoke test de alta con DOB, login y perfil.
