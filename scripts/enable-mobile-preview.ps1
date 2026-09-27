$ErrorActionPreference = 'Stop'

$node = 'C:\Users\Bryan Work\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$ruleName = 'KOMBAX mobile preview TCP 4174'

# Windows has public-profile block rules for this Node executable. The default
# inbound policy remains BlockInbound; this rule only permits the LAN preview.
netsh advfirewall firewall set rule name='node.exe' dir=in profile=public program=$node new enable=no | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not disable the public Node block rules.' }

netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=TCP localport=4174 localip=192.168.0.14 remoteip=192.168.0.0/24 profile=public program=$node | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not add the scoped KOMBAX LAN rule.' }

Write-Output 'KOMBAX mobile preview enabled at http://192.168.0.14:4174/'
