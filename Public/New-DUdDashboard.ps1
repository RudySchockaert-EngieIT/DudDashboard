﻿
function  New-DUDDashboard {
    [CmdletBinding()]
    Param([Hashtable]$EndpointInit, [Hashtable]$ExtraParameters)

    try {
        $GetSetting = { Param($MySetting, $ParamName) if ($null -ne $MySetting) { $DashboardParams."$ParamName" = $MySetting } }

        if ($null -eq $Cache.dud) {
            $Cache:dud.Data = @{ }
        }
        $DashboardParams = @{ }

        $GetSetting.Invoke($Cache:dud.Settings.UDConfig.DashboardTitle, 'Title')
        $GetSetting.Invoke($Cache:LoginPage, 'LoginPage')
        $GetSetting.Invoke($Cache:Footer, 'Footer')
        $GetSetting.Invoke($Cache:Navigation, 'Navigation')
        $GetSetting.Invoke($Cache:dud.Settings.UDConfig.IdleTimeout, 'IdleTimeout')

        $Functions = Get-ChildItem -Path "$($Cache:dud.Paths.CurrentDashboardFolderFullPath)\Functions" -Filter '*.ps1' -Recurse
        $Functions | ForEach-Object { . $_.FullName }
        $FunctionsNames = $Functions | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) }

        $EIParams = @{ }
        if ($PSBoundParameters.ContainsKey('EndpointInit')) {
            $EIParams = $PSBoundParameters.Item('EndpointInit')

            if ($null -eq $EIParams.Module) { $EIParams.remove('Module') }
            if ($null -eq $EIParams.Function) { $EIParams.remove('Function') }
            if ($null -eq $EIParams.Variable) { $EIParams.remove('Variable') }
        }

        if ($null -ne $FunctionsNames) {
            if ($null -ne $EIParams.Function) {
                $EIParams.function = $EIParams.Function + $FunctionsNames
            }
            else {
                $EIParams.Function = $FunctionsNames
            }

        }

        $EI = New-UDEndpointInitialization  @EIParams
        $Params = Get-DUDFolders
        $Cache:dud.Params = $Params

        if ($null -eq $Params) {
            $Params = @{ }
        }
        if ($null -eq $ExtraParameters) {
            $ExtraParameters = @{ }
        }

        if ($null -ne $Cache:dud.Settings.Authentication -and ($null -eq $Cache:LoginPage -or $Cache:LoginPage.Gettype().name -ne 'LoginPage')) {
            throw 'Login page not found'
        }

        $Dash = New-UDDashboard @DashboardParams @Params @ExtraParameters -EndpointInitialization $EI
        $Dash.Design = $Cache:dud.Settings.UDConfig.Design
        return  $Dash

    }
    catch {
        if ($Cache:dud.Settings.UDConfig.Design -eq $true) {
            $MyError = $_
            New-UDDashboard -Title 'Error' -Content {
                New-UDCard -Title '' -Text ($MyError | format-list -force | Out-String)
                New-UDCard -Title 'DashboardParams' -Text ($DashboardParams | Out-String)
                New-UDCard -Title 'Params' -Text ($Params | Out-String)
                New-UDCard -Title 'ExtraParameters' -Text ($ExtraParameters | Out-String)

            }
        }

    }


} #111111


# New-UDFooter


