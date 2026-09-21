param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if(-not $env:KOMBAX_DATABASE_URL){throw 'Define KOMBAX_DATABASE_URL en esta sesión segura.'}
$resolved=[System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolved | Out-Null
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$dump=Join-Path $resolved "kombax-$stamp.dump"
& pg_dump --format=custom --no-owner --no-privileges --file=$dump $env:KOMBAX_DATABASE_URL
if($LASTEXITCODE -ne 0){throw "pg_dump terminó con código $LASTEXITCODE"}
$hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $dump).Hash.ToLowerInvariant()
$manifest=Join-Path $resolved "kombax-$stamp.sha256.txt"
Set-Content -LiteralPath $manifest -Encoding utf8 -Value "$hash  $([System.IO.Path]::GetFileName($dump))"
Get-Item -LiteralPath $dump,$manifest | Select-Object FullName,Length,LastWriteTimeUtc
