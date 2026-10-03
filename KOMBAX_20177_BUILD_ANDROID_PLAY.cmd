@echo off
setlocal
cd /d "%~dp0"
node scripts/android-play-bundle.mjs
exit /b %errorlevel%
