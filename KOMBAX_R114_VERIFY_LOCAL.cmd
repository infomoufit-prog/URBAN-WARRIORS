@echo off
setlocal
cd /d "%~dp0"
echo =====================================================
echo KOMBAX R114 - VERIFICACION LOCAL BUILD 20167
echo =====================================================
where node >nul 2>&1 || (echo ERROR: Node.js no esta disponible en PATH & exit /b 1)
node --version
call npm run test:20167:r114 || exit /b 1
call npm run pretest || exit /b 1
call npm run release:build || exit /b 1
call npm run android:preflight
if errorlevel 1 echo AVISO: revisar el preflight Android, especialmente firma local.
echo.
echo QA local finalizado. Para abrir KOMBAX: npm run dev
echo URL por defecto: http://127.0.0.1:4173
endlocal
