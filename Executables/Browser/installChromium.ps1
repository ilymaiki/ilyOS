$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$archive = @(
        (Join-Path $PSScriptRoot 'ugc.7z')
        (Join-Path $PSScriptRoot '..\ugc.7z')
        (Join-Path (Get-Location) 'ugc.7z')
        (Join-Path $env:TEMP 'ugc.7z')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$archive) { throw 'ugc.7z not found; the download step must fetch it before running this script.' }

$sevenZip = @(
        (Join-Path $PSScriptRoot '7zr.exe')
        (Join-Path $PSScriptRoot '..\7zr.exe')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$sevenZip) { throw '7zr.exe is missing from the browser executables folder; re-pack the playbook.' }

$sandbox = Join-Path $env:TEMP 'UGC_Install'
Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null

Write-Host 'Extracting Chromium archive...'
& $sevenZip x $archive ("-o" + $sandbox) -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Extraction failed (exit $LASTEXITCODE); the downloaded file is likely corrupt, re-run the playbook." }

$build = Get-ChildItem $sandbox -Directory | Where-Object { $_.Name -like 'ungoogled-chromium-*' } | Select-Object -First 1

$installRoot = Join-Path $env:ProgramFiles 'UngoogledChromium'
$dest = Join-Path $installRoot 'bin'
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
Write-Host 'Installing Chromium files...'
if ($build) {
    Move-Item $build.FullName $dest
} else {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item "$sandbox\*" $dest -Recurse -Force
}

Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue

$exe = Join-Path $dest 'chrome.exe'
if (!(Test-Path $exe)) { throw "chrome.exe not found in $dest." }
Write-Host 'Registering Chromium...'
$icon = '"' + $exe + '",0'
$flags = '--no-default-browser-check --extension-mime-request-handling=always-prompt-for-install'

New-Item 'HKLM:\SOFTWARE\Classes\ChromiumHTML\shell\open\command' -Force | Out-Null
New-Item 'HKLM:\SOFTWARE\Classes\ChromiumHTML\DefaultIcon' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Classes\ChromiumHTML' '(Default)' 'Chromium HTML Document'
Set-ItemProperty 'HKLM:\SOFTWARE\Classes\ChromiumHTML' 'AppUserModelId' 'Chromium'
Set-ItemProperty 'HKLM:\SOFTWARE\Classes\ChromiumHTML\DefaultIcon' '(Default)' $icon
Set-ItemProperty 'HKLM:\SOFTWARE\Classes\ChromiumHTML\shell\open\command' '(Default)' ('"' + $exe + '" ' + $flags + ' --single-argument %1')

$app = 'HKLM:\SOFTWARE\Classes\ChromiumHTML\Application'
New-Item $app -Force | Out-Null
Set-ItemProperty $app 'ApplicationName' 'Ungoogled Chromium'
Set-ItemProperty $app 'ApplicationDescription' 'Ungoogled Chromium'
Set-ItemProperty $app 'ApplicationCompany' 'Chromium'
Set-ItemProperty $app 'ApplicationIcon' $icon
Set-ItemProperty $app 'AppUserModelId' 'Chromium'

foreach ($ext in @('.htm', '.html', '.pdf', '.shtml', '.svg', '.xht', '.xhtml', '.webp')) {
    New-Item ("HKLM:\SOFTWARE\Classes\" + $ext + "\OpenWithProgIds") -Force | Out-Null
    Set-ItemProperty ("HKLM:\SOFTWARE\Classes\" + $ext + "\OpenWithProgIds") 'ChromiumHTML' ''
}

$smi = 'HKLM:\SOFTWARE\Clients\StartMenuInternet\Chromium'
New-Item "$smi\DefaultIcon" -Force | Out-Null
New-Item "$smi\shell\open\command" -Force | Out-Null
Set-ItemProperty $smi '(Default)' 'Chromium'
Set-ItemProperty "$smi\DefaultIcon" '(Default)' $icon
Set-ItemProperty "$smi\shell\open\command" '(Default)' ('"' + $exe + '"')

$cap = "$smi\Capabilities"
New-Item "$cap\FileAssociations" -Force | Out-Null
New-Item "$cap\URLAssociations" -Force | Out-Null
New-Item "$cap\Startmenu" -Force | Out-Null
Set-ItemProperty $cap 'ApplicationName' 'Ungoogled Chromium'
Set-ItemProperty $cap 'ApplicationDescription' 'Ungoogled Chromium'
Set-ItemProperty $cap 'ApplicationIcon' $icon
foreach ($ext in @('.htm', '.html', '.pdf', '.shtml', '.svg', '.xht', '.xhtml', '.webp')) {
    Set-ItemProperty "$cap\FileAssociations" $ext 'ChromiumHTML'
}
foreach ($proto in @('http', 'https')) {
    Set-ItemProperty "$cap\URLAssociations" $proto 'ChromiumHTML'
}
Set-ItemProperty "$cap\Startmenu" 'StartMenuInternet' 'Chromium'

New-Item 'HKLM:\SOFTWARE\RegisteredApplications' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' 'Chromium' 'SOFTWARE\Clients\StartMenuInternet\Chromium\Capabilities'

New-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' '(Default)' $exe
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' 'Path' $dest

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Chromium.lnk")
$lnk.TargetPath = $exe
$lnk.Arguments = $flags
$lnk.WorkingDirectory = $dest
$lnk.IconLocation = ($exe + ', 0')
$lnk.Save()

$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Chromium.lnk'
$lnk = $ws.CreateShortcut($desktopLnk)
$lnk.TargetPath = $exe
$lnk.Arguments = $flags
$lnk.WorkingDirectory = $dest
$lnk.IconLocation = ($exe + ', 0')
$lnk.Save()

$uninstallScriptPath = Join-Path $installRoot 'uninstall.ps1'
@'
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Remove-Item 'HKLM:\SOFTWARE\Classes\ChromiumHTML' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Clients\StartMenuInternet\Chromium' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -Recurse -Force -ErrorAction SilentlyContinue
Remove-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' 'Chromium' -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Chromium' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Policies\Chromium' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Chromium.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Chromium.lnk') -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process cmd.exe -ArgumentList ('/c timeout /t 2 /nobreak >nul & rd /s /q "' + $root + '"') -WindowStyle Hidden
'@ | Set-Content -Path $uninstallScriptPath -Encoding UTF8

$uninstallKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Chromium'
New-Item $uninstallKey -Force | Out-Null
$version = (Get-Item $exe).VersionInfo.ProductVersion
$sizeKb = [math]::Round(((Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum / 1KB))
Set-ItemProperty $uninstallKey 'DisplayName' 'Ungoogled Chromium'
Set-ItemProperty $uninstallKey 'DisplayVersion' $version
Set-ItemProperty $uninstallKey 'Publisher' 'The Chromium Authors'
Set-ItemProperty $uninstallKey 'InstallLocation' $dest
Set-ItemProperty $uninstallKey 'DisplayIcon' $icon
Set-ItemProperty $uninstallKey 'UninstallString' ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $uninstallScriptPath + '"')
Set-ItemProperty $uninstallKey 'EstimatedSize' $sizeKb -Type DWord
Set-ItemProperty $uninstallKey 'NoModify' 1 -Type DWord
Set-ItemProperty $uninstallKey 'NoRepair' 1 -Type DWord

$policy = 'HKLM:\SOFTWARE\Policies\Chromium'
New-Item $policy -Force | Out-Null
Set-ItemProperty $policy 'DefaultSearchProviderEnabled' 1 -Type DWord
Set-ItemProperty $policy 'DefaultSearchProviderName' 'DuckDuckGo'
Set-ItemProperty $policy 'DefaultSearchProviderSearchURL' 'https://duckduckgo.com/?q={searchTerms}'
Set-ItemProperty $policy 'DefaultSearchProviderKeyword' 'duckduckgo.com'
Set-ItemProperty $policy 'DefaultSearchProviderSuggestURL' 'https://duckduckgo.com/ac/?q={searchTerms}&type=list'
Set-ItemProperty $policy 'HttpsOnlyModeEnabled' 1 -Type DWord
New-Item "$policy\ExtensionInstallForcelist" -Force | Out-Null
Set-ItemProperty "$policy\ExtensionInstallForcelist" '1' 'ecbibdikgcogagiklehmjddmlkipfjbc;https://clients2.google.com/service/update2/crx'
Write-Host 'Chromium installed successfully.'
