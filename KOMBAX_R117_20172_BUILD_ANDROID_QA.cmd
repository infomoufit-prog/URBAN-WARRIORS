@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================================
echo KOMBAX R117 build 20172 - ANDROID QA DEBUG
echo ================================================================
where java >nul 2>nul || (echo ERROR: Java no esta en PATH. Usa JDK 17 o 21.& exit /b 1)
where node >nul 2>nul || (echo ERROR: Node.js no esta en PATH.& exit /b 1)
call npm run verify:r117-hotfix
if errorlevel 1 exit /b 1
call npm run android:debug:r117
if errorlevel 1 exit /b 1
echo.
echo OK: APK QA:
echo artifacts\KOMBAX_20172_R117_PILOT_HOTFIX_QA_DEBUG.apk
