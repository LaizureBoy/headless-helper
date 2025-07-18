Write-Host "      ~~~~~Make sure this script is placed into an empty folder, named something like 'fika-headless'~~~~~" -ForegroundColor Red
Write-Host
Write-Host "               Here's a quick explanation of what the server, headless, and clients are in Fika:"  #Added this because I feel that people are fundamentally misunderstanding what each of these are on the gitbook instructions. Hell, maybe I do too! Input is welcome.
Write-Host
Write-Host "The 'Server' for Fika is the computer that runs the SPT Server.exe program, which is required to host the backend `nfeatures of SPT like your profiles, stash, traders and quests. 
You must have a Server for anyone to connect to and play together. The Server typically uses mods that contain a 'mods' folder, and the Server (as well as all connecting players, including the headless client) are REQUIRED to have EFT `nand SPT installed. 
Only the Server host needs most mods installed, but large mods, like those that add weapons, will `ngenerate bundles that the players will have to download. "
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
Write-Host "Finally, the 'Client' is everyone who connects to the 'Server' computer. They run using the SPT Launcher.exe program. They require the same mods as each other (For simplicity sake) in order for Fika to operate as usual. This includes yourself, your friends, and the headless client (with some exceptions)."
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

# Integrity check: compare Assembly-CSharp.dll with its .spt.bak backup
$asmPath = Join-Path $sourcePath 'EscapeFromTarkov_Data\Managed\Assembly-CSharp.dll'
$bakPath = Join-Path (Split-Path $asmPath) 'Assembly-CSharp.dll.spt-bak'
if ((Test-Path $asmPath) -and (Test-Path $bakPath)) {
    try {
        $hashOrig = (Get-FileHash -Path $asmPath -Algorithm SHA256).Hash
        $hashBak  = (Get-FileHash -Path $bakPath -Algorithm SHA256).Hash
    } catch {
        Write-Host 'Failed to compute file hashes for comparison.' -ForegroundColor Red
        Read-Host 'Press Enter to continue...' | Out-Null
    }
    if ($hashOrig -eq $hashBak) {
        Write-Host 'Assembly-CSharp.dll has not been patched correctly! Make sure you have launched SPT, created a character, and made it to the Stash in your source folder!' -ForegroundColor Red
    } else {
        Write-Host 'Assembly-CSharp.dll has been patched correctly!' -ForegroundColor Green
        Write-Host "  Original: $asmPath"
        Write-Host "  Backup:   $bakPath"
        Out-Null
    }
} else {
    if (-not (Test-Path $asmPath)) { Write-Host "Original DLL not found: $asmPath" -ForegroundColor Red }
    if (-not (Test-Path $bakPath)) { Write-Host "Backup DLL not found:   $bakPath" -ForegroundColor Red }
    Write-Host | Out-Null
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
    Write-Host "Profiles folder not found at '$profileFolder'. Make sure you have launched SPT, created a character, and made it to the Stash in your source folder!" -foregroundcolor red
    Start-Sleep -seconds 3 
    return
}

function Get-HeadlessProfiles {
    param(
        [string]$folder
    )
    $root = (Get-Item $folder).FullName.TrimEnd('\')

    function Test-HeadlessProfile($file) {
        try {
            $content = Get-Content -Path $file.FullName -Raw
            return ($file.DirectoryName.TrimEnd('\') -eq $root -and $content -match '"password"\s*:\s*"fika-headless"')
        } catch {
            return $false
        }
    }

    Get-ChildItem -Path $folder -Recurse -Filter '*.json' -File | Where-Object { Test-HeadlessProfile $_ }
}

Write-Host

do {
    # 0) always re-scan the profiles folder
    $found = Get-HeadlessProfiles -folder $profileFolder

    # 1) display them
    Write-Host "`nDetected headless profiles:`n" -ForegroundColor Green
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $found[$i].Name) -ForegroundColor Green 
    }
    $createOption = $found.Count + 1
    Write-Host ("  {0}) Create a new profile" -f $createOption) -ForegroundColor Yellow
    Write-Host

    # 2) prompt for selection
    [int]$choice = 0
    do {
        $selection = Read-Host "Choose a profile by number (1-$createOption)"
        if ([int]::TryParse($selection, [ref]$choice) -and $choice -ge 1 -and $choice -le $createOption) {
            break
        }
        Write-Host 'Invalid selection. Please try again.' -ForegroundColor Red
    } while ($true)

    # 3) branch
    if ($choice -eq $createOption) {
        # Immediately increment amount in fika.jsonc
        $configPath = Join-Path $sourcePath 'user\mods\fika-server\assets\configs\fika.jsonc'
        if (Test-Path $configPath) {
            $content = Get-Content -Raw -Path $configPath
            if ($content -match '"amount"\s*:\s*(\d+)') {
                $amount = [int]($matches[1]) + 1
                $content = $content -replace '"amount"\s*:\s*\d+', "`"amount`": $amount"
                Set-Content -Path $configPath -Value $content
                Write-Host "Incremented headless profile amount to $amount in fika.jsonc." -ForegroundColor Green
            } else {
                Write-Warning "Could not find 'amount' field in fika.jsonc."
            }
        } else {
            Write-Warning "fika.jsonc not found at $configPath"
        }

        # Instruct user to start server to generate new profile
        Write-Host "Please start the SPT server now to generate a new headless profile, then press Enter when you see 'Created 1 headless client profiles'" -ForegroundColor Yellow
        $oldProfiles = @()
        if ($found) { $oldProfiles = $found | ForEach-Object { $_.Name } }
        Read-Host | Out-Null

        # Wait for new profile to appear
        do {
            $found = Get-HeadlessProfiles -folder $profileFolder
            $newProfiles = @()
            if ($found) { $newProfiles = $found | ForEach-Object { $_.Name } }
            $diff = Compare-Object $oldProfiles $newProfiles | Where-Object { $_.SideIndicator -eq '=>' }
            if ($diff) { break }
            Write-Host "Waiting for new profile to appear in $profileFolder..."
            Start-Sleep -Seconds 2
        } while ($true)

        $newProfileName = ($diff | Select-Object -First 1).InputObject
        Write-Host "New profile detected: $newProfileName" -ForegroundColor Green

        # Prompt for custom alias
        $aliasChoice = Read-Host "Would you like to set a custom name for this headless profile? (Y/N)"
        if ($aliasChoice -match '^[Yy]$') {
            $customAlias = Read-Host "Enter custom name for headless profile"
            $profileBase = [IO.Path]::GetFileNameWithoutExtension($newProfileName)
            if (Test-Path $configPath) {
                $content = Get-Content -Raw -Path $configPath
                # Update aliases
                if ($content -match '"aliases"\s*:\s*\{') {
                    $content = $content -replace '("aliases"\s*:\s*\{)', "`$1`n        `"$profileBase`": `"$customAlias`""
                } else {
                    $content = $content -replace '("profiles"\s*:\s*\{)', "`$1`n    `"amount`": 1,`n    `"aliases`": {`n        `"$profileBase`": `"$customAlias`"`n    },"
                }
                Set-Content -Path $configPath -Value $content
                Write-Host "Set alias for $profileBase to $customAlias in fika.jsonc." -ForegroundColor Green
            } else {
                Write-Warning "fika.jsonc not found at $configPath"
            }
        } else {
            Write-Host "Skipping custom alias setup."
        }

        continue    # loop back, but $found will be freshly reloaded at top
    } else {
        $chosen = $found[$choice - 1]
        Write-Host "`nYou selected: $($chosen.Name)" -ForegroundColor Cyan
        break   # <-- This exits the loop and continues the script
    }
} while ($true)

Write-Host
Write-Host

# Ask if the server is hosted elsewhere
do {
    $remote = Read-Host "Are you hosting the server on another computer? (Y/N)"
    if ($remote -match '^[Yy]$' -or $remote -match '^[Nn]$') {

        # Only prompt for IP:Port if remote
        if ($remote -match '^[Yy]$') {
            $ipPort = Read-Host 'Enter the remote server computerIP:Port (e.g. 192.168.1.100:6969)'
        } else {
            # Local backend – no prompt
            $ipPort = '127.0.0.1:6969'
            Write-Host "`nAssuming local backend at $ipPort. You can edit the headless startup script's backendUrl if incorrect."
        }

        # Update the Start_headless_<Profile>.ps1 file
        $profileBase    = [IO.Path]::GetFileNameWithoutExtension($chosen.Name)
        $scriptDir      = Join-Path $sourcePath 'user\mods\fika-server\assets\scripts'
        $startScript    = "Start_headless_$profileBase.ps1"
        $startScriptPath= Join-Path $scriptDir $startScript

        if (Test-Path $startScriptPath) {
            $pattern     = '\$BackendUrl\s*=\s*".*"'
            $replacement = "`$BackendUrl = `"https://$ipPort`""
            (Get-Content $startScriptPath) -replace $pattern, $replacement |
                Set-Content $startScriptPath
            Write-Host "Updated $startScript with BackendUrl https://$ipPort" -ForegroundColor Green

            # Copy it next to this setup script
            $currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
            Copy-Item $startScriptPath -Destination $currentDir -Force
            Write-Host "Copied $startScript to $currentDir" -ForegroundColor Green
        } else {
            Write-Warning "Could not find $startScript in $scriptDir"
        }

        break
    }
    else {
        Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Yellow
    }
} while ($true)

Write-Host

Write-Host "I've moved the Start_headless_$profileBase to the root of this folder. Make sure that it's started from the headless computer when you move this folder and not the server PC!" -ForegroundColor Cyan

Write-Host

Write-Host "Press Enter to begin copying your files!" -ForegroundColor Yellow
Read-Host

$src = $sourcePath.TrimEnd('\\')
$dst = (Get-Location).Path.TrimEnd('\\')
Write-Host "Starting Robocopy from '$src' to '$dst'... This might take a while!" -ForegroundColor Green
# STOP DELETING THE SCRIPT GODDAMN YOU
$exitCode = & robocopy "$src" "$dst" /E /MT:8 /Z /R:1 /W:1
Write-Host
if ($exitCode -lt 8) {
    Write-Host "Copy completed successfully." -ForegroundColor Green
} else {
    Write-Warning "Robocopy reported errors. Exit code: $exitCode."
}

Write-Host

# Incompatibility Checker in mods and plugins folders
$incompat = @{
    'Raid Overhaul'            = 'Certain settings are not compatible with Fika. Still in testing.'
    'Declutter'                = 'Works in some cases, others not. Test it for yourself.'
    'Profile Editor'           = 'Can corrupt presets. Use at your own peril.'
    'Pity Loot'                = 'Breaks scav runs.'
    'Friendly PMCs'            = 'Not friendly when >1 player; may cause weird errors.'
    "That's Lit"              = 'Needs the sync add-on (Check Pins on Discord) or significant FPS drop.'
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

Write-Host "All done! `nCopy the entire folder that this script is located in to the PC you want the headless server to run on and start the 'start_headless_$profileBase' script!" -ForegroundColor DarkGreen
Write-Host 
Write-Host "Note: When copying this folder, you'll have two SPT Server.exe files." -ForegroundColor
Write-Host "You can run either, but know that you should stick to using the same one and possibly even delete the SPT.Server.exe that you're not using to avoid confusion." -ForegroundColor Yellow
Write-Host "Failure to use the same SPT.Server.exe consistently may result in profiles not being updated or mods not being loaded!" -ForegroundColor Red
Write-Host
Read-Host "Press Enter to close."