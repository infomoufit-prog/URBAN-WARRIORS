param(
  [Parameter(Mandatory=$true)][string]$BackupFile,
  [Parameter(Mandatory=$true)][string]$ConfirmIsolated
)
$ErrorActionPreference='Stop'
if($ConfirmIsolated -ne 'TARGET_IS_ISOLATED'){ throw 'Restauración bloqueada. Usa -ConfirmIsolated TARGET_IS_ISOLATED únicamente contra un proyecto aislado.' }
if(-not $env:KOMBAX_RESTORE_DATABASE_URL){ throw 'Define KOMBAX_RESTORE_DATABASE_URL para el proyecto AISLADO.' }
if(-not (Test-Path -LiteralPath $BackupFile)){ throw "No existe el backup: $BackupFile" }
$pgRestore=(Get-Command pg_restore -ErrorAction SilentlyContinue)
if(-not $pgRestore){ throw 'pg_restore no está disponible en PATH.' }
& pg_restore --clean --if-exists --no-owner --no-privileges --dbname=$env:KOMBAX_RESTORE_DATABASE_URL $BackupFile
if($LASTEXITCODE -ne 0){ throw "pg_restore terminó con código $LASTEXITCODE" }
Write-Host 'KOMBAX DB restore completado en destino aislado. Ejecuta después las verificaciones de RLS, conteos, Auth refs y Storage.'
