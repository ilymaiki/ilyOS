$ErrorActionPreference = 'Continue'

foreach ($process in @('MSTeams', 'ms-teams', 'msteamsautostarter', 'Teams')) {
    Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
}

$packages = Get-AppxPackage -AllUsers -Name '*MSTeams*' -ErrorAction SilentlyContinue

foreach ($package in $packages) {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
            Write-Output "Removed package $($package.PackageFullName)."
            break
        } catch {
            Write-Output "Attempt $attempt failed for $($package.PackageFullName): $($_.Exception.Message)"
            Start-Sleep -Seconds 3
        }
    }
}

Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like '*MSTeams*' } |
    ForEach-Object {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop
            Write-Output "Deprovisioned $($_.PackageName)."
        } catch {
            Write-Output "Could not deprovision $($_.PackageName): $($_.Exception.Message)"
        }
    }

$pending = @()

foreach ($pattern in @('C:\Program Files\WindowsApps\MSTeams_*')) {
    foreach ($folder in (Get-Item -Path $pattern -Force -ErrorAction SilentlyContinue)) {
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $folder.FullName)) { break }
            Start-Sleep -Seconds 3
        }

        if (Test-Path $folder.FullName) {
            Write-Output "Locked leftovers scheduled for deletion at reboot: $($folder.FullName)"

            $files = Get-ChildItem -Path $folder.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
            $dirs = Get-ChildItem -Path $folder.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending

            foreach ($item in @($files + $dirs + $folder)) {
                $pending += "\??\$($item.FullName)"
                $pending += ''
            }
        }
    }
}

foreach ($user in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
    foreach ($folder in (Get-Item -Path "$($user.FullName)\AppData\Local\Packages\MSTeams_*" -Force -ErrorAction SilentlyContinue)) {
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $folder.FullName)) { break }
            Start-Sleep -Seconds 3
        }

        if (Test-Path $folder.FullName) {
            Write-Output "Locked leftovers scheduled for deletion at reboot: $($folder.FullName)"

            $files = Get-ChildItem -Path $folder.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
            $dirs = Get-ChildItem -Path $folder.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending

            foreach ($item in @($files + $dirs + $folder)) {
                $pending += "\??\$($item.FullName)"
                $pending += ''
            }
        }
    }
}

if ($pending.Count -gt 0) {
    $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $existing = (Get-ItemProperty -Path $key -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    $value = @($existing | Where-Object { $_ }) + $pending
    Set-ItemProperty -Path $key -Name PendingFileRenameOperations -Value $value -Type MultiString
    Write-Output "Scheduled $($pending.Count / 2) items for deletion at reboot."
} else {
    Write-Output 'Microsoft Teams fully removed, no pending deletions.'
}
