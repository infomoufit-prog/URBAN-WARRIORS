@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo KOMBAX R116 - EDGE FUNCTIONS REQUERIDAS
echo Proyecto esperado: poggsobhtutbuagjiydc
echo ============================================================
where supabase >nul 2>nul || (echo ERROR: Supabase CLI no encontrado. Instala la CLI oficial y ejecuta de nuevo.& exit /b 1)
supabase --version
supabase link --project-ref poggsobhtutbuagjiydc || exit /b 1
echo.
echo IMPORTANTE: antes de continuar aplica en SQL Editor:
echo   supabase\deploy\KOMBAX_R116_SUPABASE_PREFLIGHT.sql
echo   supabase\deploy\KOMBAX_R116_REQUIRED_PATCH.sql
echo   supabase\deploy\KOMBAX_R116_SUPABASE_POSTFLIGHT.sql
echo y confirma que el POSTFLIGHT devuelve todos los campos TRUE.
set /p CONFIRM=Escribe FUNCTIONS para desplegar SOLO las funciones R116 requeridas: 
if /I not "%CONFIRM%"=="FUNCTIONS" (echo Cancelado.& exit /b 2)
supabase functions deploy notification-dispatch --project-ref poggsobhtutbuagjiydc --use-api || exit /b 1
supabase functions deploy kombax-owner-report-r114 --project-ref poggsobhtutbuagjiydc --use-api || exit /b 1
supabase functions deploy health --project-ref poggsobhtutbuagjiydc --use-api || exit /b 1
echo.
echo EDGE FUNCTIONS DESPLEGADAS. Valida health, push Owner/miembros y PDF Owner en remoto.
endlocal
