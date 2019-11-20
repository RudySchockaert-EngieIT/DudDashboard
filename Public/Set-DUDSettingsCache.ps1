Function Set-DUDSettingsCache($Path) {
    if ($null -eq $cache:dud) {
        $cache:dud = @{ }

        $Cache:dud.Paths = @{ }
        $Cache:dud.Paths.Root = (Get-location).Path

    }
    $SettingsPath = if ($null -ne $path) { $Path }else { $Cache:dud.Paths.Root }
    try {
        $Cache:dud.Settings = Get-Content "$SettingsPath\appsettings.json" -ErrorAction stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $CurrentError = $_
        $Cache:dud = $null
        throw $CurrentError
    }



    $Cache:dud.Paths = @{
        Root                           = $Cache:dud.Paths.Root
        CurrentDashboardFolderFullPath = ''
        CurrentDashboardFullPath       = ''
        CurrentDashboard               = ''
    }

    $Cache:dud.Paths.CurrentDashboardFolderFullPath = "$($Cache:dud.Paths.Root)\src"
    $Cache:dud.Paths.CurrentDashboardFullPath = "$($Cache:dud.Paths.Root)\src\Root.ps1"


}



