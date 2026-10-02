@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20172 - VERIFICACION LOCAL
echo ================================================================
where node >nul 2>nul || (echo ERROR: Node.js no esta instalado o no esta en PATH.& exit /b 1)
node -v
call npm run verify:r117-hotfix
if errorlevel 1 exit /b 1
node scripts/release-netlify-r104-3.mjs
if errorlevel 1 exit /b 1
echo.
echo OK: QA web/Netlify completado.
echo Ejecutando preflight Android...
call npm run android:preflight
if errorlevel 2 (
  echo.
  echo AVISO: el codigo esta preparado pero falta configurar la firma Android local.
  echo Copia android\keystore.properties.example a android\keystore.properties y completa los valores,
  echo o usa UW_KEYSTORE_PATH, UW_KEYSTORE_PASSWORD, UW_KEY_ALIAS y UW_KEY_PASSWORD.
  exit /b 0
)
if errorlevel 1 exit /b 1
echo OK: preflight Android completo.
