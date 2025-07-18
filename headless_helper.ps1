Write-Host "      ~~~~~Make sure this script is placed into an empty folder, named something like 'fika-headless'~~~~~" -ForegroundColor Red
Write-Host
Write-Host
Write-Host "               Here's a quick explanation of what the server, headless, and clients are in Fika:"  #Added this because I feel that people are fundamentally misunderstanding what each of these are on the gitbook instructions. Hell, maybe I do too! Input is welcome.
Write-Host
Write-Host "The 'Server' for Fika is the computer that runs the SPT Server.exe program, which is required to host the backend `nfeatures of SPT like your profiles, stash, traders and quests. 
You must have a Server for anyone to connect to and play together. The Server typically uses mods that contain a 'mods' folder, and the Server (as well as all connecting players, including the headless client) are REQUIRED to have EFT `nand SPT installed. 
Only the Server host needs to have these installed, but large mods like those that add weapons, will `ngenerate bundles that the players will have to download. "
Write-Host
Write-host "    For more information, check this post on the discord: https://discord.com/channels/1202292159366037545/1234332919443488799/1235518309882007552  " -ForegroundColor Yellow
Write-Host
Write-Host
Write-Host "The 'Headless' is a 'player' that is used to host the raid. They're invisible and in the skybox, but they drastically improve performance because the person that hosts the raid is the one that does all of the in-game calculations,
which put a heavy strain on your computer. You can think of the headless client as just another player with `nsome extra configuration, except that there are some gameplay mods that you "  -NoNewline
Write-Host "!!DO NOT WANT INSTALLED ON THE HEADLESS!!" -NoNewline -ForegroundColor Red
Write-Host
Write-Host
Write-Host "Check the gitbook installation instructions for more info: https://project-fika.gitbook.io/wiki/advanced-features/headless-client" -ForegroundColor Yellow
Write-Host
Write-Host
Write-Host "Finally, the 'Client' is everyone who connects to the 'Server' computer. They run using the SPT Launcher.exe program. They require the same mods as each other (For simplicity's sake) in order for Fika to operate as usual. This includes yourself, your friends, and the headless client (with some exceptions)."
Write-Host
Read-Host "Press ENTER to continue, and choose your SPT Fika installation folder you want to copy the files from"

# Load WinForms for folder picker dialog
Add-Type -AssemblyName System.Windows.Forms

# Prompt the user to pick the FIKA installation folder (SPT root) and verify SPT.Launcher.exe exists
do {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select your SPT installation folder (Escape From Tarkov)'
    $dlg.ShowNewFolderButton = $false
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host 'No folder selected. Exiting.'
        Start-Sleep 3
        return
    }
    $sourcePath = $dlg.SelectedPath
    if (-not (Test-Path (Join-Path $sourcePath 'SPT.Launcher.exe'))) {
        Write-Host "SPT.Launcher.exe not found in '$sourcePath'. Please select the correct SPT root folder." -ForegroundColor Yellow
        Read-Host 'Press Enter to choose again' | Out-Null
        continue
    }
    break
} while ($true)
Write-Host "Selected SPT folder: '$sourcePath'"

Write-Host

# Integrity check on Assembly-CSharp.dll
$asmPath = Join-Path $sourcePath 'EscapeFromTarkov_Data\Managed\Assembly-CSharp.dll'
$expectedHash = '12D5FD1728C58A9CD71A454FB5EAE506B5A0A3C2BB35D543C4022800E10F47D5'
if (Test-Path $asmPath) {
    try {
        $actualHash = (Get-FileHash -Path $asmPath -Algorithm SHA256).Hash
    } catch {
        Write-Host "Failed to compute hash for $asmPath"
        Read-Host 'Press Enter to continue...'
    }
    if ($actualHash -ne $expectedHash) {
        Write-Host "Assembly-CSharp.dll hash mismatch. Expected: $expectedHash";
        Write-Host "Actual:   $actualHash";
        Write-Host 'Please start the SPT Launcher at least once to generate the correct DLL, then press Enter to continue.'
        Read-Host | Out-Null
    } else {
        Write-Host 'Assembly-CSharp.dll integrity verified. Hash: '$actualHash'' -ForegroundColor Green
    }
} 

Write-Host

# Function to wait for fika.jsonc to exist
function Wait-ForFikaConfig {
    param(
        [string]$configPath
    )
    while (-not (Test-Path $configPath)) {
        Write-Host "fika.jsonc not found at '$configPath', `nhave you installed fika on the server yet and ran SPT Server?" -ForegroundColor Red
        Read-Host 'Press Enter after installing to recheck.' | Out-Null
    }
}

# Define and wait for fika.jsonc before proceeding
$configPath = Join-Path -Path $sourcePath -ChildPath 'user\mods\fika-server\assets\configs\fika.jsonc'
Wait-ForFikaConfig -configPath $configPath

Write-Host

# Verify profiles folder exists under user\profiles
$profileFolder = Join-Path $sourcePath 'user\profiles'
if (-not (Test-Path $profileFolder -PathType Container)) {
    Write-Host "Profiles folder not found at '$profileFolder'. Exiting." -foregroundcolor red
    Start-Sleep -seconds 3 
    return
}

Write-Host

# Function to find JSON profiles whose password is 'fika-headless'
function Get-HeadlessProfiles {
    param($folder)
    Get-ChildItem -Path $folder -Filter '*.json' -File -Recurse | Where-Object {
        try {
            (Get-Content -Path $_.FullName -Raw) -match '"password"\s*:\s*"fika-headless"'
        } catch {
            $false
        }
    } | ForEach-Object {
        [PSCustomObject]@{
            FileName = $_.Name
            FullPath = $_.FullName
        }
    }
}

# Loop until at least one headless profile is detected
$found = @()
while ($found.Count -eq 0) {
    $found = Get-HeadlessProfiles -folder $profileFolder
    if ($found.Count -gt 0) { break }

    # No profiles yet: update fika.jsonc "amount" to 1
    $configPath = Join-Path $sourcePath 'user\mods\fika-server\assets\configs\fika.jsonc'
    if (Test-Path $configPath) {
        (Get-Content -Path $configPath -Raw) -replace '"amount"\s*:\s*\d+', '"amount": 1' |
            Set-Content -Path $configPath
        Write-Host "Set 'amount' to 1 in '$configPath'" -foregroundcolor green
    } else {
        Write-Host "Config file not found at '$configPath'. Have you installed Fika yet and ran the server?" -foregroundcolor red
    }

    Write-Host "No headless profiles detected. `nPlease start the SPT Server in the folder you chose above and wait until you see 'Happy Playing!!' `nPress Enter to rescan." -foregroundcolor red
    Read-Host | Out-Null
}

Write-Host

# Display detected profiles
Write-Host "`nDetected headless profiles:`n" -foregroundcolor green
for ($i = 0; $i -lt $found.Count; $i++) {
    Write-Host ("  {0}) {1}" -f ($i + 1), $found[$i].FileName) -ForegroundColor Green
}

Write-Host

# Prompt the user to select a profile
do {
    $selection = Read-Host "Choose a profile by number (1-$($found.Count))"
    if ([int]::TryParse($selection, [ref]0) -and [int]$selection -ge 1 -and [int]$selection -le $found.Count) {
        break
    }
    Write-Host 'Invalid selection. Please try again.' -ForegroundColor Red
} while ($true)

# Once we have a good selection:
$chosen = $found[[int]$selection - 1]
Write-Host
Write-Host ("You selected: {0}" -f $chosen.FileName)


Write-Host "Press Enter to begin copying your files!" -ForegroundColor Yellow
Read-Host

$src = $sourcePath.TrimEnd('\\')
$dst = (Get-Location).Path.TrimEnd('\\')
Write-Host "Starting Robocopy from '$src' to '$dst'..." -ForegroundColor Green
# STOP DELETING THE SCRIPT GODDAMN YOU
$exitCode = & robocopy "$src" "$dst" /E /MT:8 /Z /R:1 /W:1
Write-Host
if ($exitCode -lt 8) {
    Write-Host "Copy completed successfully." -ForegroundColor Green
} else {
    Write-Warning "Robocopy reported errors. Exit code: $exitCode."
}

# Find and copy headless script
$scriptDir = Join-Path $sourcePath 'user\mods\fika-server\assets\scripts'
$item = Get-ChildItem $scriptDir -Recurse -Filter 'Start_headless_*' -File | Select-Object -First 1
if (-not $item) { Write-Warning "No Start_headless_* script found in $scriptDir" } else {
    $headlessScript = $item.FullName; Write-Host "Found script: $headlessScript"
    $ipPort = Read-Host 'Enter IP:Port (e.g. 127.0.0.1:443) that your SPT Server is using'
    $backendUrl = "https://$ipPort"
    $pattern = '\$BackendUrl\s*=\s*".*"'
    $replacement = "`$BackendUrl = `"$backendUrl`""
    (Get-Content $headlessScript) -replace $pattern, $replacement | Set-Content $headlessScript
    Write-Host "Updated BackendUrl to $backendUrl"
    Copy-Item $headlessScript -Destination (Split-Path -Parent $MyInvocation.MyCommand.Path) -Force
}

Write-Host

# Incompatibility Checker in mods and plugins folders
$incompat = @{
    'Raid Overhaul'            = 'Certain settings are not compatible with Fika. Still in testing.'
    'Declutter'                = 'Works in some cases, others not. Test it for yourself.'
    'Profile Editor'           = 'Can corrupt presets. Use at your own peril.'
    'Pity Loot'                = 'Breaks scav runs.'
    'Friendly PMCs'            = 'Not friendly when >1 player; may cause weird errors.'
    "That's Lit"              = 'Needs the sync add-on (Check Pins) or significant FPS drop.'
    'LootRadius'              = 'Not working with latest Fika; view-only issues.'
    'LootValue'               = 'Will lag game the longer raid goes on.'
    'Various Hardcore Starts*'  = 'Prevents dedicated client from generating the .bat file.'
    'Boss Notifier*'            = 'Only accurate for raid host, not clients.'
    'Amands Graphics'          = 'Useless for the headless server.'
    'MoreCheckmarks'           = 'Client mod that reduces performance'
    'EFTApi'                   = ''
    'Game Panel Hud'             = 'Client mod that reduces perfomance.'
    'Dynamic Maps'              = 'Client mod that reduces perfomance.'
    'Ram Cleaner Interval'     = 'Client mod that reduces perfomance.'
    'All Quests Checkmarks'     = 'Causes performance issues.'
}
# Scan user\mods for incompatible mod folders (including all subfolders)
$modDir = Join-Path $sourcePath 'user\mods'
if (Test-Path $modDir) {
    Write-Host "`nScanning user\mods for incompatible folders..."
    Write-Host
    Get-ChildItem -Path $modDir -Recurse -Directory | ForEach-Object {
        $name = $_.Name
        foreach ($mod in $incompat.Keys) {
            # build a wildcard pattern from the mod key (splitting on spaces)
            $pattern = '*' + ($mod -split '\s+' -join '*') + '*'
            if ($name -ilike $pattern) {
                Write-Host "  WARNING: Incompatible mod detected:" -ForegroundColor Red
                Write-Host "  Name: $($_.Name)" -ForegroundColor Red
                Write-Host "  Path: $($_.FullName)" -ForegroundColor Red
                if ($incompat[$mod]) { Write-Host "  Note: $($incompat[$mod])" -ForegroundColor Red } 
            }
        }
    }
} else {
    Write-Host "Mods folder not found at '$modDir'"
}

Write-Host

# Scan BepInEx\plugins for incompatible plugin DLLs (including all subfolders)
$pluginDir = Join-Path $sourcePath 'BepInEx\plugins'
if (Test-Path $pluginDir) {
    Write-Host "`nScanning BepInEx\plugins for incompatible DLLs..."
    Write-Host
    Get-ChildItem -Path $pluginDir -Recurse -Filter '*.dll' -File | ForEach-Object {
        $name = $_.Name
        foreach ($mod in $incompat.Keys) {
            $pattern = '*' + ($mod -split '\s+' -join '*') + '*'
            if ($name -ilike $pattern) {
                Write-Host "  WARNING: Incompatible plugin detected:" -ForegroundColor Red
                Write-Host "  Name: $($_.Name)" -ForegroundColor Red
                Write-Host "  Path: $($_.FullName)" -ForegroundColor Red
                if ($incompat[$mod]) { Write-Host "  Note: $($incompat[$mod])" -ForegroundColor Red } 
            }
        }
    }
} else {
    Write-Host "Plugin folder not found at '$pluginDir'"
}

Write-Host

# AHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH WHY IS THE SCRIPT DELETING ITSELF
Write-Host 'Downloading and extracting latest Fika-Headless release...'
try {
    # Get latest release metadata
    $release = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/project-fika/Fika-Headless/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -match 'fika\.headless.*\.zip' } | Select-Object -First 1

    # Setup temp paths
    $tmpBase = Join-Path $env:TEMP 'fika_headless'
    $tmpZip = Join-Path $tmpBase $asset.name
    $tmpDir = Join-Path $tmpBase ([Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    Write-Host "Downloading $($asset.name) to temp folder..."
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $tmpZip

    Write-Host "Extracting to temp folder..."
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force

    # Copy to script directory, excluding any .ps1 to protect script
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Write-Host "Copying extracted files to '$scriptDir'..."
    Copy-Item -Path (Join-Path $tmpDir '*') -Destination $scriptDir -Recurse -Force -Exclude '*.ps1'

    # Cleanup
    Write-Host 'Cleaning up temporary files...'
    Remove-Item -Path $tmpBase -Recurse -Force

    Write-Host 'Headless release extraction complete.'
} catch {
    Write-Error ("Failed headless download/extract: {0}" -f $_)
}

Write-Host

Write-Host "All done! `nCopy the entire folder that this script is located in to the PC you want the headless server to run on and start the 'start_headless_' script!" -ForegroundColor DarkGreen
Read-Host "Press Enter to close."
