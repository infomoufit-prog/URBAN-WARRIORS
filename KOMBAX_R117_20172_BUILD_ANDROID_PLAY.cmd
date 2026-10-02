@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20172 - ANDROID GOOGLE PLAY
echo ================================================================
echo IMPORTANTE: no canceles la release que Google Play ya tenga en revision.
echo Esta build se sube como actualizacion del MISMO track cerrado cuando Play lo permita.
echo.
where java >nul 2>nul || (echo ERROR: Java no esta en PATH. Usa JDK 17 o 21.& exit /b 1)
where node >nul 2>nul || (echo ERROR: Node.js no esta en PATH.& exit /b 1)
call npm run android:preflight
if errorlevel 1 (
  echo ERROR: preflight Android incompleto. Revisa la firma/keystore y vuelve a ejecutar.
  exit /b 1
)
call npm run android:play:r117
if errorlevel 1 exit /b 1
echo.
echo OK: AAB para Google Play:
echo artifacts\KOMBAX_20172_R117_PILOT_HOTFIX_GOOGLE_PLAY.aab
echo.
echo APK release firmada:
echo artifacts\KOMBAX_20172_R117_PILOT_HOTFIX_SIGNED.apk
