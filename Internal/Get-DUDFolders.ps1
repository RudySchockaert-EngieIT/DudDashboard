function Get-DUDFolders() {
    # Stylesheets

    $Output = @{
        Pages       = @()
        Stylesheets = @()
        Theme       = & "$($Cache:dud.Paths.Root)\src\Theme.ps1"
        Scripts     = @()
    }

    $Functions = Get-ChildItem -Path "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Functions" -Filter '*.ps1' -Recurse
    $Functions | ForEach-Object { . $_.FullName }
    $FunctionsNames = $Functions | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) }


    Get-ChildItem "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Pages\*.ps1" -Recurse | Sort-Object FullName | ForEach-Object { $Output.Pages += (& $_.FullName) }

    $ScriptsPath = "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Scripts"
    $ScriptsPath | Copy-Item -Destination "$($Cache:dud.Paths.Root)\client"  -Recurse -Force

    $ScriptsPath = Get-ChildItem "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Scripts\*.*" | Sort-Object FullName
    $ScriptsPath.Name | ForEach-Object { $Output.Scripts += "/scripts/$_" }


    $StylesPath = "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Styles"
    $StylesPath | Copy-Item -Destination "$($Cache:dud.Paths.Root)\client"  -Container -Recurse -Force

    $StylesPath = Get-ChildItem "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Styles\*.*" | Sort-Object FullName
    $StylesPath.Name | ForEach-Object { $Output.Stylesheets += "/Styles/$_" }
    return $Output
}


