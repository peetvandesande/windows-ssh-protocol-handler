# Download the handler
$url = "https://gist.githubusercontent.com/thorstenkramm/b25a2c09ca7414595d48d1db581833fc/raw/1fecf170378390eebe778209a8b88972d6893657/ssh-protocol-handler.ps1"
$file = "$env:LOCALAPPDATA\ssh-protocol-handler.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $file

# Download the registry keys
$url = "https://gist.githubusercontent.com/thorstenkramm/b25a2c09ca7414595d48d1db581833fc/raw/1fecf170378390eebe778209a8b88972d6893657/ssh-protocol-handler.reg"
$file = "$env:LOCALAPPDATA\ssh-protocol-handler.reg"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $file
(Get-Content -path $file -Raw) -replace '<LOCALAPPDATA>', "$( [regex]::escape($env:LOCALAPPDATA) )"| Set-Content -Path $file
get-Content $file
reg import $file

# Now, log out and back in to apply the new registry keys
Write-Output "Log out and then back in to apply changes, then open any ssh: URL and select the correct handler."