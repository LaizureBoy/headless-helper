<#
This PowerShell script automates downloading and installing the FIKA headless mod.
Assumes you already have FIKA installed per instructions:
https://project-fika.gitbook.io/wiki/installing-fika
#>

#region Elevation Check
if (-not ([Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
    Write-Host "Relaunching with Administrator rights…" -ForegroundColor Yellow
    Start-Process PowerShell `
        -Verb RunAs `
        -ArgumentList @(
            '-NoExit',
            '-ExecutionPolicy','Bypass',
            '-File', "`"$PSCommandPath`""
        )
    exit
}
#endregion

# ——————————————————————————————————————
# Y/N prompt helper
function Read-YesNo {
    param([string]$Prompt)
    do {
        $resp = Read-Host "$Prompt (Y/N)"
    } until ($resp -match '^[YyNn]$')
    return $resp -match '^[Yy]$'
}
# ——————————————————————————————————————


Write-Host "This script assumes you've read the installation instructions for FIKA and have a working installation of FIKA."
Write-Host "If you haven't done that yet, read about it here: https://project-fika.gitbook.io/wiki/installing-fika"
Write-Host "It's HIGHLY RECOMMENDED to read the installation instructions for the headless client. This will help resolve errors you might come across, and contains very important information on configuration. Check it out here: https://project-fika.gitbook.io/wiki/advanced-features/headless-client"
Write-Host "Then press Enter to continue installing and configuring the Headless server."
Write-Host "Make sure you're using this script on the PC you'd like to be a headless client."
Read-Host "Press Enter to continue..."

# Determine script folder
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Installing into: $ScriptDir"

# Fetch latest headless release info from GitHub
$apiUrl  = 'https://api.github.com/repos/project-fika/Fika-Headless/releases/latest'
$release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell' }

# Find the headless ZIP by matching “headless” (case‑insensitive) anywhere in the filename
$asset = $release.assets |
    Where-Object { $_.name -match '(?i)headless.*\.zip$' } |
    Select-Object -First 1

if (-not $asset) {
    Write-Error "Could not find any headless .zip asset in the latest release. Available assets:"
    $release.assets | ForEach-Object { Write-Host "  $_.name" }
    exit 1
}

Write-Host "Found headless asset: $($asset.name)"


# Download the zip
$zipPath = Join-Path $ScriptDir $asset.name
Write-Host "Downloading $($asset.name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

# Extract into script directory
Write-Host "Extracting contents into $ScriptDir..."
Expand-Archive -Path $zipPath -DestinationPath $ScriptDir -Force
Remove-Item $zipPath
Write-Host "Extraction complete." -ForegroundColor Green

# Scan for incompatible mods
$searchPaths = @(
    Join-Path $ScriptDir 'BepInEx\plugins'
    Join-Path $ScriptDir 'user\mods'
) | Where-Object { Test-Path $_ }


# Define incompatible mods and their messages
$incompatList = @{
    'Raid Overhaul'           = 'Raid Overhaul - certain settings are not compatible with Fika. Still in testing.'
    'Declutter'               = 'Declutter - Works in some cases, others not. Test it for yourself.'
    'Profile Editor'          = 'Profile Editor - it can corrupt presets. Use at your own peril.'
    'Pity Loot'               = 'Pity Loot - breaks scav runs.'
    'Friendly PMCs'           = 'Friendly PMCs - not friendly when >1 player. Can cause weird errors.'
    "That's Lit"             = "That's Lit - needs the sync add-on otherwise you'll see a significant fps drop. NOTE: we have had reports of crashes for SOME. Test and see."
    'Loot Radius'             = 'Loot Radius - currently not working with latest Fika. Will sometimes only allow you to view but not take or drop items.'
    'Loot Value'              = 'Loot Value - will lag the game out the longer raid goes on.'
    'Various Hardcore Starts'  = 'Various Hardcore Starts - prevents the dedicated client from generating the .bat file.'
    'Boss Notifier'           = 'Boss Notifier - only works accurately for raid host but not for clients.'
}

# Scan and report
$found = Get-ChildItem -Path $searchPaths -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    foreach ($mod in $incompatList.Keys) {
        if ($_.Name -match [regex]::Escape($mod)) { [PSCustomObject]@{ Path = $_.FullName; Mod = $mod } }
    }
}

if ($found) {
    Write-Host "`nIncompatible mods detected:" -ForegroundColor Yellow
    foreach ($item in $found) {
        Write-Host "  $($item.Mod) - $($incompatList[$item.Mod])" -ForegroundColor Yellow
        Write-Host "    Path: $($item.Path)"
    }
    Write-Host "Please remove these mods before running the headless client." -ForegroundColor Yellow
} else {
    Write-Host "No known incompatible mods detected." -ForegroundColor Green
}

# ————————————————
# Ask how they’re hosting and pick the right IP
$hostMethod = Read-Host "How are you hosting the server? (Enter VPN, LAN, or Port)"
$method     = $hostMethod.ToLower()

switch ($method) {
    'lan' {
        # Grab the first non-loopback IPv4 on the machine
        $targetIP = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^(127\.0\.0\.1|169\.254\.)' } |
            Select-Object -First 1 -ExpandProperty IPAddress)
        Write-Host "Using local IPv4 address: $targetIP" -ForegroundColor Cyan
    }

    'vpn' {
        # Prompt until they enter a valid IPv4
        do {
            $targetIP = Read-Host "Enter the VPN IPv4 address"
        } until ($targetIP -match '^\d{1,3}(?:\.\d{1,3}){3}$')
        Write-Host "Using VPN IP: $targetIP" -ForegroundColor Cyan
    }

    'port' {
        # Use 0.0.0.0 here; the start_headless patcher will swap in the real local IP
        $targetIP = '0.0.0.0'
        Write-Host "Using placeholder IP $targetIP (will be replaced in start_headless scripts)" -ForegroundColor Yellow
    }

    default {
        Write-Warning "Unknown hosting method; defaulting to LAN."
        # Repeat LAN logic:
        $targetIP = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^(127\.0\.0\.1|169\.254\.)' } |
            Select-Object -First 1 -ExpandProperty IPAddress)
        Write-Host "Using local IPv4 address: $targetIP" -ForegroundColor Cyan
    }
}


# — Ensure scripts.forceIp is set correctly — 
if ($content -match '"scripts"\s*:\s*{') {
    # 1) Replace an existing but empty or incorrect forceIp line
    $content = [regex]::Replace(
        $content,
        '("scripts"\s*:\s*{[\s\S]*?)"forceIp"\s*:\s*".*?"([\s\S]*?})',
        "`$1`"forceIp`": `"$targetIp`"`$2",
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    # 2) If forceIp still isn’t present at all, inject it immediately after the “scripts”: { line
    if ($content -notmatch '"forceIp"\s*:') {
        $content = $content -replace '("scripts"\s*:\s*{)',
            "`$1`r`n        `"forceIp`": `"$targetIp`","
    }
}


# Locate the JSONC file (only once, earlier in your script)
$jsonc = Get-ChildItem -Path $ScriptDir -Recurse -Filter 'fika.jsonc' -ErrorAction SilentlyContinue | Select-Object -First 1


# ==== Safe write‑back ====
if (-not $jsonc -or [string]::IsNullOrWhiteSpace($jsonc.FullName)) {
    Write-Warning "Could not locate fika.jsonc under '$ScriptDir'. Skipping write‑back."
}
elseif ([string]::IsNullOrWhiteSpace($content)) {
    Write-Warning "Modified content is empty (length $($content.Length)). Skipping write‑back to avoid wiping the file."
}
else {
    Write-Host "Writing updated JSONC to: $($jsonc.FullName) (content length $($content.Length))" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText(
        $jsonc.FullName,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "fika.jsonc updated successfully." -ForegroundColor Green
}



# In‑game F12 reminder based on hosting type
if ($hostMethod -match '^(?i)vpn$') {
    Write-Host "In‑game: Press F12, select the Fika.Core tab, and set 'Force IP' and 'Force Bind IP' to your VPN IP ($targetIP)." -ForegroundColor DarkCyan
}
elseif ($hostMethod -match '^(?i)lan$') {
    Write-Host "In‑game: Press F12, select the Fika.Core tab, and set 'Force IP' and 'Force Bind IP' to your LAN IP ($targetIP)." -ForegroundColor DarkCyan
}

# Find and patch fika.jsonc
$jsonc = Get-ChildItem -Path $ScriptDir -Recurse -Filter 'fika.jsonc' |
         Select-Object -First 1
if ($jsonc) {
    Write-Host "Updating `"$($jsonc.FullName)`" to use IP $targetIp..."
    $content = Get-Content $jsonc.FullName -Raw
    # build replacements
    $ipRepl    = '"ip": "'       + $targetIp + '"'
    $backRepl  = '"backendIp": "' + $targetIp + '"'
    $forceRepl = '"forceIp": "'   + $targetIp + '"'
    $amtRepl   = '"amount": 1'
    # apply each with exactly two args
    $content = $content -replace '"ip"\s*:\s*".*?"',       $ipRepl
    $content = $content -replace '"backendIp"\s*:\s*".*?"', $backRepl
    $content = $content -replace '"forceIp"\s*:\s*".*?"',   $forceRepl
    $content = $content -replace '"amount"\s*:\s*\d+',     $amtRepl
    # write back without BOM
    [System.IO.File]::WriteAllText(
        $jsonc.FullName,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "fika.jsonc updated successfully." -ForegroundColor Green
} else {
    Write-Warning "Could not find a fika.jsonc to update."
}
# ————————————————

# Offer to open FIKA ports
if (Read-YesNo "Open inbound ports UDP 25565 and TCP 6969?") {
    # UDP 25565
    if (-not (Get-NetFirewallRule -Name 'FIKA_UDP_25565' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -Name 'FIKA_UDP_25565' `
            -DisplayName 'FIKA UDP 25565' `
            -Direction Inbound `
            -Protocol UDP `
            -LocalPort 25565 `
            -Action Allow
        Write-Host "Created firewall rule FIKA_UDP_25565." -ForegroundColor Green
    }
    else {
        Write-Host "Firewall rule FIKA_UDP_25565 already exists." -ForegroundColor Yellow
    }

    # TCP 6969
    if (-not (Get-NetFirewallRule -Name 'FIKA_TCP_6969' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -Name 'FIKA_TCP_6969' `
            -DisplayName 'FIKA TCP 6969' `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 6969 `
            -Action Allow
        Write-Host "Created firewall rule FIKA_TCP_6969." -ForegroundColor Green
    }
    else {
        Write-Host "Firewall rule FIKA_TCP_6969 already exists." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Skipping firewall configuration." -ForegroundColor Yellow
}

# ————————————————

# Update start_headless*.ps1 to point at the correct backend IP and port

$startScripts = Get-ChildItem -Path $ScriptDir -Filter 'start_headless*.ps1' -Recurse -ErrorAction SilentlyContinue
if ($startScripts) {

    # 1) Determine port from fika.jsonc (fallback to 6969)
    $jsonc = Get-ChildItem -Path $ScriptDir -Recurse -Filter 'fika.jsonc' | Select-Object -First 1
    if ($jsonc) {
        $raw   = Get-Content $jsonc.FullName -Raw
        $m     = [regex]::Match($raw, '"port"\s*:\s*(\d+)')
        if ($m.Success) { 
    $port = $m.Groups[1].Value 
} else { 
    $port = '6969' 
}

    }
    else {
        Write-Warning "Could not find fika.jsonc; defaulting port to 6969."
        $port = '6969'
    }

    # 2) Pick IP to use in the script:
    #    - If hostMethod is “Port”, use local IPv4
    #    - Otherwise use the user’s chosen targetIP (VPN or LAN)
    if ($hostMethod -match '^(?i)port$') {
        $backendIp = (Get-NetIPAddress -AddressFamily IPv4 `
                         | Where-Object {
                             $_.IPAddress -notmatch '^(127\.0\.0\.1|169\.254\.)'
                         } `
                         | Select-Object -First 1 -ExpandProperty IPAddress)
        Write-Host "Using local IPv4 for Port mode: $backendIp" -ForegroundColor Cyan
    }
    else {
        $backendIp = $targetIP
        Write-Host "Using chosen IP for $hostMethod mode: $backendIp" -ForegroundColor Cyan
    }

    # 3) Patch each start_headless script
    foreach ($script in $startScripts) {
        Write-Host "Patching $($script.Name) → https://$backendIp`:$port" -ForegroundColor Cyan

        $lines       = Get-Content $script.FullName
        $backendLine = '$BackendUrl = "https://' + $backendIp + ':' + $port + '"'

        # Two-argument replace: pattern + one replacement string
        $patched     = $lines -replace '^\s*\$BackendUrl\s*=.*', $backendLine

        # Write it back
        Set-Content -Path $script.FullName -Value $patched -Encoding UTF8
    }

    Write-Host "Updated BackendUrl (with port) in $($startScripts.Count) script(s)." -ForegroundColor Green
}
else {
    Write-Warning "No start_headless*.ps1 scripts found to patch."
}


# ————— Offer to copy the headless launch script —————
if ( Read-YesNo "Copy headless*.ps1 from user\mods\fika-server\assets\scripts to SPT root? You will launch the headless server from this file!" ) {
    # Use double‑quotes here to avoid any stray apostrophe issues:
    $srcDir = Join-Path $ScriptDir 'user\mods\fika-server\assets\scripts'
    if (-not (Test-Path $srcDir)) {
        Write-Warning "Source folder not found: $srcDir"
    }
    else {
        $headlessScript = Get-ChildItem `
            -Path $srcDir `
            -Filter "headless*.ps1" `
            -Recurse `
            -ErrorAction SilentlyContinue |
          Select-Object -First 1

        if ($headlessScript) {
            Copy-Item $headlessScript.FullName -Destination $ScriptDir -Force
            Write-Host "Copied $($headlessScript.Name) to $ScriptDir" -ForegroundColor Green
        }
        else {
            Write-Warning "No headless*.ps1 file found in $srcDir"
        }
    }
}
else {
    Write-Host "Skipping headless script copy." -ForegroundColor Yellow
}

Write-Host "Headless installation, configuration and compatibility scan complete. Make sure to update the URL in your SPT Launcher in the settings, development options! Remember to include https:// and the port! e.g https://192.168.1.1:6969 Enjoy FIKA!"

