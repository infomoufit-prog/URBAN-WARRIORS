@echo off
setlocal
cd /d "%~dp0"
node scripts/android-debug-qa.mjs
exit /b %errorlevel%
