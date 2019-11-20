Function Get-DUDEndpoints() {
    $Endpoints = @()
    Get-ChildItem "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Endpoints\*.ps1" -Recurse | ForEach-Object { $Endpoints += (& $_.FullName) }
    return $Endpoints
}
