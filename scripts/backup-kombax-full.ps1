param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if(-not $env:KOMBAX_DATABASE_URL){ throw 'Define KOMBAX_DATABASE_URL en esta sesión segura.' }
if(-not $env:KOMBAX_SUPABASE_URL){ throw 'Define KOMBAX_SUPABASE_URL en esta sesión segura.' }
if(-not $env:KOMBAX_SERVICE_ROLE_KEY){ throw 'Define KOMBAX_SERVICE_ROLE_KEY en esta sesión segura. No la guardes en archivos.' }
if(-not (Get-Command pg_dump -ErrorAction SilentlyContinue)){ throw 'pg_dump no está disponible en PATH.' }
if(-not (Get-Command node -ErrorAction SilentlyContinue)){ throw 'Node.js no está disponible en PATH.' }

$root=[System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $root | Out-Null
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$run=Join-Path $root "kombax-full-$stamp"
New-Item -ItemType Directory -Force -Path $run | Out-Null

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'backup-supabase-free.ps1') -OutputDirectory (Join-Path $run 'database')
if($LASTEXITCODE -ne 0){ throw 'Falló el backup PostgreSQL.' }

& node (Join-Path $PSScriptRoot 'backup-supabase-storage.mjs') --output (Join-Path $run 'storage') --all
if($LASTEXITCODE -ne 0){ throw 'Falló el backup Storage.' }

$files=Get-ChildItem -LiteralPath $run -Recurse -File
$manifest=@()
foreach($f in $files){
  $manifest += [pscustomobject]@{
    path=$f.FullName.Substring($run.Length+1).Replace('\\','/')
    bytes=$f.Length
    sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
  }
}
$manifestPath=Join-Path $run 'FULL_BACKUP_MANIFEST.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8
$manifestHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $run 'FULL_BACKUP_MANIFEST.sha256') -Encoding utf8 -Value "$manifestHash  FULL_BACKUP_MANIFEST.json"
Write-Host "Backup KOMBAX completo: $run"
