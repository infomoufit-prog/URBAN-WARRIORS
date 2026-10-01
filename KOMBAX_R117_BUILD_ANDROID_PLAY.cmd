@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo KOMBAX R117 - AAB GOOGLE PLAY + APK RELEASE FIRMADA
echo ============================================================
where node >nul 2>nul || (echo ERROR: Node.js no encontrado.& exit /b 1)
where java >nul 2>nul || (echo ERROR: Java no encontrado. Usa JDK 17 o 21.& exit /b 1)
call npm run android:preflight
if errorlevel 1 (
  echo.
  echo BLOQUEADO: completa android\keystore.properties o las variables UW_* con la upload key registrada en Google Play.
  exit /b 2
)
call npm run android:play:r117 || exit /b 1
echo.
echo AAB: artifacts\KOMBAX_20170_R117_GOLDEN_PILOT_GOOGLE_PLAY.aab
echo APK: artifacts\KOMBAX_20170_R117_GOLDEN_PILOT_SIGNED.apk
endlocal
