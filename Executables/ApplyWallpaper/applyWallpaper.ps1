param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath
)

if (-not (Test-Path $ImagePath)) {
    Write-Error "Image path does not exist: $ImagePath"
    exit 1
}

Get-ChildItem -Path 'Registry::HKU' | ForEach-Object {
    [microsoft.win32.registry]::SetValue("$($_.Name)\Control Panel\Desktop", 'WallPaper', $ImagePath, [Microsoft.Win32.RegistryValueKind]::String)
}

$setwallpapersrc = @'
using System.Runtime.InteropServices;

public class IlyOSDesktopWallpaper
{
    public const int SetDesktopWallpaper = 20;
    public const int UpdateIniFile = 0x01;
    public const int SendWinIniChange = 0x02;
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static int SetWallpaper(string path)
    {
        return SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange);
    }
}
'@
if (-not ([System.Management.Automation.PSTypeName]'IlyOSDesktopWallpaper').Type) {
    Add-Type -TypeDefinition $setwallpapersrc
}
$result = [IlyOSDesktopWallpaper]::SetWallpaper($ImagePath)
Write-Output "SetWallpaper returned: $result"

exit 0
