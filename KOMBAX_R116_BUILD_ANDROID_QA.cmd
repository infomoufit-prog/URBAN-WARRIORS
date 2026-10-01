@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo KOMBAX R116 - APK DEBUG PARA QA / PILOTO
echo ============================================================
where node >nul 2>nul || (echo ERROR: Node.js no encontrado.& exit /b 1)
where java >nul 2>nul || (echo ERROR: Java no encontrado. Usa JDK 17 o 21.& exit /b 1)
call npm run verify:r116 || exit /b 1
call npm run android:debug:r116 || exit /b 1
echo.
echo APK QA creada en artifacts\KOMBAX_20169_R116_GOLDEN_PILOT_QA_DEBUG.apk
endlocal
