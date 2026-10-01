@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo KOMBAX R116 GOLDEN PILOT FREEZE - VERIFICACION LOCAL
echo ============================================================
where node >nul 2>nul || (echo ERROR: Node.js no esta instalado o no esta en PATH.& exit /b 1)
node --version
npm --version
call npm run verify:r116 || exit /b 1
echo.
echo QA LOCAL OK. Para abrir KOMBAX en local ejecuta: npm run dev
echo URL esperada: http://127.0.0.1:4173
endlocal
