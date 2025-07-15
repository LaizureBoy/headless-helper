# install-fika.ps1
# PowerShell script to install FIKA core, server, and headless plugins for Single Player Tarkov.
# Automatically requests elevation, guides you through each step, and can configure firewall & JSON settings.

#region -- HELPER: Read Yes/No Input --
function Read-YesNo {
    param([string]$Prompt)
    do { $resp = Read-Host $Prompt } until ($resp -match '^[YyNn]$')
    return $resp -match '^[Yy]$'
}
#endregion

#region -- ELEVATION CHECK --
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Not running as Administrator. Relaunching with elevation…"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
#endregion

#region -- READ INSTALLATION INSTRUCTIONS --
do {
    Write-Host ""
    Write-Host "Before we begin, please read the FIKA installation instructions here:"
    Write-Host "  https://project-fika.gitbook.io/wiki/installing-fika" -ForegroundColor Cyan
    Write-Host "Also, download the Headless mod from:"
    Write-Host "  https://project-fika.gitbook.io/wiki/advanced-features/headless-client" -ForegroundColor Cyan
    Write-Host ""
    $ack = Read-Host "Type 'Yes' when you've read and understand the instructions and downloaded the fika plugin, server, and the Headless mod"
} until ($ack -eq 'Yes')
#endregion

#region -- PICK SPT INSTALL DIRECTORY --
Add-Type -AssemblyName System.Windows.Forms
$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description = "Select your Single Player Tarkov installation folder"
if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Write-Error "No folder selected. Exiting."; exit }
$SPT = $fbd.SelectedPath
Write-Host "Using SPT directory: $SPT" -ForegroundColor Green
#endregion

#region -- FUNCTION: SCAN FOR REQUIRED FILES --
function Get-FikaStatus {
    $coreDir  = Join-Path $SPT 'BepInEx\plugins'
    $userMods = Join-Path $SPT 'user\mods'
    $core     = if (Test-Path $coreDir)  { Get-ChildItem -Path $coreDir  -Filter 'fika.core.dll'     -ErrorAction SilentlyContinue } else { @() }
    $headless = if (Test-Path $coreDir)  { Get-ChildItem -Path $coreDir  -Filter 'fika.headless.dll' -ErrorAction SilentlyContinue } else { @() }
    $server   = if (Test-Path $userMods) { Get-ChildItem -Path $userMods -Directory -Filter 'fika-server' -ErrorAction SilentlyContinue } else { @() }
    return @{ CoreDll = $core; ServerFolder = $server; HeadlessDll = $headless }
}
#endregion

#region -- DOWNLOAD LOOP FOR MISSING --
do {
    $status = Get-FikaStatus; $missing = @()
    if (-not $status.CoreDll)      { $missing += 'fika.core.dll (BepInEx/plugins)' }
    if (-not $status.ServerFolder) { $missing += 'fika-server folder (user/mods)' }
    if (-not $status.HeadlessDll)  { $missing += 'fika.headless.dll (BepInEx/plugins)' }
    if ($missing) {
        Write-Host "`nMissing: $($missing -join ', ')" -ForegroundColor Yellow
        if (Read-YesNo "Open GitHub download page to get them? (Y/N)") { Start-Process 'https://github.com/project-fika'; Read-Host "Downloaded? Press Enter when done." }
        else { Read-Host "Place files manually, then press Enter." }
    }
} until (-not $missing)
Write-Host "All required files detected!" -ForegroundColor Green
#endregion

#region -- START SPT SERVER STEP --
Write-Host "`nStep: Start your SPT Server until you see 'happy playing!!' in green text." -ForegroundColor Cyan
Read-Host "Press Enter to continue once you see it."
#endregion

#region -- CREATE LAUNCHER PROFILE STEP --
Write-Host "`nLaunch SPT Launcher and create a new profile (e.g. Headless)."
$profileName = Read-Host "What name did you choose?"
Read-Host "Profile '$profileName' created. Press Enter to continue."
#endregion

#region -- LAUNCH GAME TO GENERATE FILES STEP --
Write-Host "`nNow launch the game with that profile, get to the main menu, and wait for the disclaimer to finish."
Read-Host "Then close the game and press Enter to continue."
#endregion

#region -- FIREWALL RULES STEP --
Write-Host "`nConfigure inbound firewall rules for FIKA?"
if (Read-YesNo "Open TCP 6969 & UDP 25565 inbound? (Y/N)") {
    Try {
        New-NetFirewallRule -Name "FIKA_TCP_6969"  -DisplayName "FIKA TCP 6969"  -Direction Inbound -Protocol TCP -LocalPort 6969  -Action Allow
        New-NetFirewallRule -Name "FIKA_UDP_25565" -DisplayName "FIKA UDP 25565" -Direction Inbound -Protocol UDP -LocalPort 25565 -Action Allow
        Write-Host "Firewall rules created." -ForegroundColor Green
    } Catch { Write-Warning "Failed to create firewall rules: $_" }
} else { Write-Host "Skipping firewall setup." -ForegroundColor Yellow }
#endregion

#region -- CONFIGURE fika.jsonc STEP --
Write-Host "`nConfigure IP settings in fika.jsonc? (Recommended)"
# Determine target IP: VPN or local
if (Read-YesNo "Will you host the server using a VPN like Radmin? (Y/N)") {
    do { $targetIP = Read-Host "Enter the Radmin VPN server address" } until ($targetIP -match '^\d{1,3}(?:\.\d{1,3}){3}$')
} elseif (Read-YesNo "Auto-configure fika.jsonc with your local IPv4? This is required to ensure that your headless client can connect to the server. (Y/N)") {
    $targetIP = (Get-NetIPAddress -AddressFamily IPv4 |
                 Where-Object { $_.IPAddress -notmatch '^(127\.0\.0\.1|169\.254\.)' } |
                 Select-Object -First 1 -ExpandProperty IPAddress)
} else {
    $targetIP = $null
}

if ($targetIP) {
    $jsonc = Get-ChildItem -Path $SPT -Recurse -Filter 'fika.jsonc' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jsonc) {
        Write-Host "Updating $($jsonc.FullName) to use IP $targetIP..."
        $content = Get-Content $jsonc.FullName -Raw
        $content = $content -replace '"ip"\s*:\s*".*?"', "`"ip`":`"$targetIP`""
        $content = $content -replace '"backendIp"\s*:\s*".*?"', "`"backendIp`":`"$targetIP`""
        $content = $content -replace '"forceIp"\s*:\s*".*?"', "`"forceIp`":`"$targetIP`""
        $content = $content -replace '"amount"\s*:\s*\d+', '"amount":1'
        Set-Content -Path $jsonc.FullName -Value $content -Encoding UTF8
        Write-Host "fika.jsonc configured." -ForegroundColor Green
    } else { Write-Warning "fika.jsonc not found. Skipping." }
} else {
    Write-Host "Skipping JSONC configuration." -ForegroundColor Yellow
}
#endregion

#region -- COPY HEADLESS LAUNCH SCRIPT --
Write-Host "`nCopying headless helper script to SPT root..."
$scriptDir = Join-Path $SPT 'user\mods\fika-server\assets\scripts'
$files = Get-ChildItem -Path $scriptDir -Filter '*headless*.ps1' -Recurse -ErrorAction SilentlyContinue
if ($files) { foreach ($f in $files) { Copy-Item -Path $f.FullName -Destination $SPT -Force; Write-Host "Copied $($f.Name)" } }
Write-Host "Helper script ready in $SPT." -ForegroundColor Green
#endregion

Write-Host "`nSetup complete! Right click the .ps1 file in your root directory and launch with powershell to start the headless server! Enjoy FIKA."
Read-Host "Press Enter to exit."
