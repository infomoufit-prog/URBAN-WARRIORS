@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo KOMBAX R117 - NETLIFY PRODUCTION DEPLOY
echo ============================================================
where node >nul 2>nul || (echo ERROR: Node.js no encontrado.& exit /b 1)
where netlify >nul 2>nul || (echo ERROR: Netlify CLI no encontrado. Instala: npm install -g netlify-cli& exit /b 1)
call npm run release:build || exit /b 1
if not exist ".netlify\state.json" (
  echo.
  echo El proyecto local aun no esta enlazado. Selecciona el proyecto KOMBAX existente, NO crees uno nuevo.
  call netlify link || exit /b 1
)
echo.
echo Se realizara el despliegue de produccion del contenido dist\ al proyecto enlazado.
set /p CONFIRM=Escribe DEPLOY para continuar: 
if /I not "%CONFIRM%"=="DEPLOY" (echo Cancelado.& exit /b 2)
call netlify deploy --prod --dir=dist || exit /b 1
echo.
echo DEPLOY NETLIFY COMPLETADO. Comprueba https://kombax.es y el healthcheck antes de abrir el piloto.
endlocal
