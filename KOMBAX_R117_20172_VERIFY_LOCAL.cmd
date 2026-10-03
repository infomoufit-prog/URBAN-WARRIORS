@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20172 - VERIFICACION LOCAL REGISTRO/AUTH
echo ================================================================
where node >nul 2>nul || (echo ERROR: Node.js no esta instalado o no esta en PATH.& exit /b 1)
node -v
call npm run verify:20172
if errorlevel 1 exit /b 1
node scripts/release-netlify-r104-3.mjs
if errorlevel 1 exit /b 1
echo.
echo OK: contrato de registro + QA web/Netlify completados.
echo Ejecutando preflight Android...
call npm run android:preflight
if errorlevel 2 (
  echo.
  echo AVISO: codigo/Android preparados, pero falta configurar la firma local.
  echo Copia android\keystore.properties.example a android\keystore.properties y completa los valores,
  echo o usa UW_KEYSTORE_PATH, UW_KEYSTORE_PASSWORD, UW_KEY_ALIAS y UW_KEY_PASSWORD.
  exit /b 0
)
if errorlevel 1 exit /b 1
echo OK: preflight Android completo.
