@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20171 - DEPLOY NETLIFY
echo ================================================================
where node >nul 2>nul || (echo ERROR: Node.js no esta disponible.& exit /b 1)
where netlify >nul 2>nul || (
  echo ERROR: Netlify CLI no esta instalado.
  echo Ejecuta primero: npm install -g netlify-cli
  exit /b 1
)
call npm run verify:r117-hotfix
if errorlevel 1 exit /b 1
node scripts/release-netlify-r104-3.mjs
if errorlevel 1 exit /b 1
netlify status >nul 2>nul
if errorlevel 1 (
  echo.
  echo Este directorio no esta enlazado a un sitio Netlify.
  echo Ejecuta: netlify login
  echo Despues: netlify link
  echo Selecciona el sitio KOMBAX correcto y vuelve a ejecutar este CMD.
  exit /b 2
)
echo.
echo ATENCION: se va a publicar dist como PRODUCCION en el sitio Netlify enlazado.
set /p CONFIRM=Escribe DESPLEGAR para continuar: 
if /I not "%CONFIRM%"=="DESPLEGAR" (echo Cancelado.& exit /b 3)
netlify deploy --prod --dir=dist
if errorlevel 1 exit /b 1
echo.
echo OK: deploy Netlify solicitado para build 20171.
