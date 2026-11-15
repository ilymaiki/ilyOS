$ErrorActionPreference = 'Continue'

Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue

function Invoke-OneDriveSetup {
    param([string]$Path, [string]$Arguments, [string]$Label)

    if (-not (Test-Path $Path)) { return }
    try {
        $proc = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru
        if ($proc.WaitForExit(90000)) {
            Write-Output "Finished installer: $Label (exit code $($proc.ExitCode))."
        } else {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Output "Installer timed out and was killed: $Label."
        }
    } catch {
        Write-Output "Could not run installer $Label : $($_.Exception.Message)"
    }
}

Invoke-OneDriveSetup -Path "$env:WINDIR\System32\OneDriveSetup.exe" -Arguments '/uninstallall' -Label 'machine-wide (System32)'
Invoke-OneDriveSetup -Path "$env:WINDIR\SysWOW64\OneDriveSetup.exe" -Arguments '/uninstallall' -Label 'machine-wide (SysWOW64)'

foreach ($user in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
    Invoke-OneDriveSetup -Path (Join-Path $user.FullName 'AppData\Local\Microsoft\OneDrive\OneDriveSetup.exe') -Arguments '/uninstall' -Label "per-user ($($user.Name))"
}

foreach ($process in @('OneDrive', 'OneDriveSetup', 'OneDriveStandaloneUpdater', 'FileCoAuth')) {
    Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
}

foreach ($user in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
    foreach ($path in @(
        "$($user.FullName)\AppData\Local\Microsoft\OneDrive",
        "$($user.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk",
        "$($user.FullName)\AppData\Local\Microsoft\Windows\Application Shortcuts\Microsoft.OneDrive",
        "$($user.FullName)\OneDrive"
    )) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Output "Removed $path"
        }
    }
}

foreach ($path in @('C:\Program Files\Microsoft OneDrive', 'C:\Program Files (x86)\Microsoft OneDrive', 'C:\ProgramData\Microsoft OneDrive')) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Removed $path"
    }
}

Get-ScheduledTask -TaskName 'OneDrive*' -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

foreach ($sid in (Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue)) {
    if ($sid.PSChildName -match '^S-1-5-21-') {
        Remove-Item -Path "Registry::HKEY_USERS\$($sid.PSChildName)\Software\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_USERS\$($sid.PSChildName)\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_USERS\$($sid.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "Registry::HKEY_USERS\$($sid.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Run" -Name 'OneDrive' -ErrorAction SilentlyContinue
    }
}

Remove-Item 'HKLM:\SOFTWARE\Microsoft\OneDrive' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\OneDrive' -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OneDrive removal finished.'
