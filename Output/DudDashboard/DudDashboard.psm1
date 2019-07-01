class DUDHotReloadPath {
    [DUDHotReloadPathItem]$Root
    [DUDHotReloadPathItem]$Rules
}
class DUDHotReloadPathItem {
    [String]$Path
    [String]$Filter
    [switch]$Recurse
    [DashboardAction]$Action
    [ScriptBlock]$CustomAction
    [int]$Delay
}
Function Get-DUDEndpoints(){
    $Endpoints = @()
     Get-ChildItem "$($Cache:Paths.CurrentDashboardFolderFullPath)\Endpoints\*.ps1" -Recurse | % {$Endpoints += (& $_.FullName)}
    return $Endpoints
}
function Get-DUDFolders() {
    # Stylesheets
    
    $Output = @{
        Pages       = @()
        Stylesheets = @()
        Theme       = & "$($Cache:Paths.Root)\src\Theme.ps1"
        Scripts     = @()
    }
    
    $Functions = Get-ChildItem -Path "$($cache:Paths.CurrentDashboardFolderFullPath)\Functions" -Filter '*.ps1' -Recurse 
    $Functions | % { . $_.FullName }
    $FunctionsNames = $Functions | % { [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) }


    Get-ChildItem "$($cache:Paths.CurrentDashboardFolderFullPath)\Pages\*.ps1" -Recurse | Sort FullName | % { $Output.Pages += (& $_.FullName) }
  
    $ScriptsPath = "$($cache:Paths.CurrentDashboardFolderFullPath)\Scripts"
    $ScriptsPath | Copy-Item -Destination "$($cache:Paths.Root)\client"  -Recurse -Force
    
    $ScriptsPath = Get-ChildItem "$($cache:Paths.CurrentDashboardFolderFullPath)\Scripts\*.*" | Sort FullName 
    $ScriptsPath.Name | % { $Output.Scripts += "/scripts/$_" }

   
    $StylesPath = "$($cache:Paths.CurrentDashboardFolderFullPath)\Styles"
    $StylesPath | Copy-Item -Destination "$($cache:Paths.Root)\client"  -Container -Recurse -Force

    $StylesPath = Get-ChildItem "$($cache:Paths.CurrentDashboardFolderFullPath)\Styles\*.*" | Sort FullName 
    $StylesPath.Name | % { $Output.Stylesheets += "/Styles/$_" }
    return $Output
}

Function Start-DUDDFilewatcher([DUDHotReloadPath]$Path) {
    $fileSystemWatcher = New-Object -TypeName 'System.IO.FileSystemWatcher' -ArgumentList $Path.Root.Path, $Path.Root.Filter -Property @{
        NotifyFilter = [IO.NotifyFilters]::LastWrite
        EnableRaisingEvents = $true
        IncludeSubdirectories = $Path.Root.Recurse
    }
    
    $WatchAction = {
        try {
            $Global:DashboardActionDelay.Stop()

            
            [DUDHotReloadPathItem]$Private:RuleUsed = $event.MessageData.Root

            Foreach ($Rule in $event.MessageData.Rules) {
                if ($event.SourceEventArgs.FullPath -like $Rule.Path ) {
                    $Private:RuleUsed = $Rule
                    break
                }
            }

            if ($Private:RuleUsed.CustomAction -ne $null) {$Global:DashboardActionRulesQueue+= $Private:RuleUsed}

            $Global:DashboardAction = $Global:DashboardAction -bor $Private:RuleUsed.Action


        }
        catch {
            Write-Host $_.Exception -ForegroundColor Red
        } Finally {
            $Global:DashboardActionDelay.Start()
        }

        Register-ObjectEvent $fileSystemWatcher Changed -SourceIdentifier $Path.Name -Action $WatchAction -MessageData @{ 
            AppPool       = $AppPool
            Rules = $Path
        }
     
}

}

function  New-DUDDashboard {
    [CmdletBinding()]
    Param([Hashtable]$EndpointInit, [Hashtable]$ExtraParameters)

    try {
        $GetSetting = { Param($MySetting, $ParamName) if ($MySetting -ne $null) { $DashboardParams."$ParamName" = $MySetting } }

        $Cache:DUDData = @{ }
        $DashboardParams = @{ }

        $GetSetting.Invoke($Cache:Settings.UDConfig.DashboardTitle, 'Title')
        $GetSetting.Invoke($Cache:LoginPage, 'LoginPage')
        $GetSetting.Invoke($Cache:Footer, 'Footer')
        $GetSetting.Invoke($Cache:Navigation, 'Navigation')
        $GetSetting.Invoke($Cache:Settings.UDConfig.IdleTimeout, 'IdleTimeout')
    
        $Functions = Get-ChildItem -Path "$($cache:Paths.CurrentDashboardFolderFullPath)\Functions" -Filter '*.ps1' -Recurse 
        $Functions | % { . $_.FullName }
        $FunctionsNames = $Functions | % { [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) }

        $DataSourcePath = "$($cache:Paths.CurrentDashboardFolderFullPath)\Data\$($Cache:Settings.UDConfig.DataSource)"
        if (Test-Path -Path $DataSourcePath ) {
            Get-ChildItem -Path $DataSourcePath -Filter '*.ps1' | % { . $_.FullName }
        }

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

        $EI = New-UDEndpointInitialization  -Function $FunctionsNames 
        $Params = Get-DUDFolders
        $Cache:Params = $Params

        $DataSourcePath = "$($cache:Paths.CurrentDashboardFolderFullPath)\Data\$($Cache:Settings.UDConfig.DataSource)"
        if (Test-Path -Path $DataSourcePath ) {
            Get-ChildItem -Path $DataSourcePath -Filter '*.ps1' | % { . $_.FullName }
        }
        
        if ($null -eq $Params) { $Params = @{ } 
        }
        if ($null -eq $ExtraParameters) { $ExtraParameters = @{ }
        }
        
        return  New-UDDashboard @DashboardParams @Params @ExtraParameters -EndpointInitialization $EI 
    
    }
    catch {
        $MyError = $_
        New-UDDashboard -Title 'Error' -Content {
            New-UDCard -Title '' -Text ($MyError | format-list -force | Out-String)
            New-UDCard -Title 'DashboardParams' -Text ($DashboardParams | Out-String)
            New-UDCard -Title 'Params' -Text ($Params | Out-String)
            New-UDCard -Title 'ExtraParameters' -Text ($ExtraParameters | Out-String)
            
        }    
    }
    
  
} #111111


# New-UDFooter

Function New-DUDHotReloaderWatchPath([DUDHotReloadPathItem]$Root,[DUDHotReloadPathItem[]]$Rules) {
    return New-Object -TypeName 'DUDHotReloadPath' -Property @{'Root'=$Root;'Rules'=$Rules}
}
Function New-DUDHotReloaderWatchPathItem($Path,$Filter,[Switch]$Recurse,[DashboardAction]$Action,[Scriptblock]$CustomAction,[int]$Delay) {
    return New-Object -TypeName 'DUDHotReloadPathItem' -Property $PSBoundParameters
}
function Publish-DudDashboard {
    [CmdletBinding()]
    param (
        [Switch]$Force,
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ -PathType Container })]
        [String]
        $Path,
        [ValidateScript( { Test-Path $_ })]
        [String]$License
       
    )
    
    begin {
      
       
    }
      
    
    process {
        $ClientPath = Join-Path -Path $Path -ChildPath 'client'
        $SrcPath = Join-Path -Path $Path -ChildPath 'src'
        if (-not (Test-Path $SrcPath)) { New-Item $SrcPath -ItemType Directory }
 
        $UDModuleLocation = (Get-Module UniversalDashboard -ListAvailable)[0] | Select Path | Split-Path -Parent
        $DUDModuleLocation = (Get-Module DUDDashboard -ListAvailable)[0] | Select Path | Split-Path -Parent
        $RootPath = Split-Path -Path $SrcPath -Parent
        Get-ChildItem $UDModuleLocation | % { Copy-Item -Path $_.FullName -Destination $Path -Container -Recurse -Force:$Force }
        Get-ChildItem "$DUDModuleLocation\Template" -Exclude 'root' | % { Copy-Item -Path $_.FullName -Destination $SrcPath -Container -Recurse -Force:$Force }
        Get-ChildItem "$DUDModuleLocation\Template\root" | % { Copy-Item -Path $_.FullName -Destination $RootPath -Container -Recurse -Force:$Force }
        
        
        $AppSettings = Get-content -Path "$RootPath\AppSettings.json" -Raw | ConvertFrom-Json
        $AppSettings.UDConfig.UpdateToken = New-Guid
        $AppSettings | ConvertTo-Json | Set-Content "$RootPath\AppSettings.json"

       
        #[Void](New-Item -Path "$SrcPath\scripts" -ItemType Directory)
        #[Void](New-Item -Path "$SrcPath\styles" -ItemType Directory)

        # [Void](New-Item -Path "$ClientPath\scripts" -ItemType SymbolicLink -Value "$SrcPath\scripts" -Force:$Force)
        # [Void](New-Item -Path "$ClientPath\styles" -ItemType SymbolicLink -Value "$SrcPath\styles" -Force:$Force)
        
        

        if ($PSBoundParameters.ContainsKey('License')) {
            Copy-Item -Path $License -Destination (Join-Path -Path $Path -ChildPath "net472\")
            Copy-Item -Path $License -Destination (Join-Path -Path $Path -ChildPath "netstandard2.0\")
        }
    


    }



    end {
    }
}

Function Set-DUDSettingsCache($Path) {
    if ($Path -ne $null) {
        $Cache:Settings =  Get-Content "$Path\appsettings.json" | ConvertFrom-Json

    } else {
        $Cache:Settings =  Get-Content "$($Cache:Paths.Root)\appsettings.json" | ConvertFrom-Json    
    }
    
}
function Start-DUDDashboard {
    [CmdletBinding()]
    param (
        [INT]$Port,
        [Switch]$Wait,
        $Parameters
    )
    
    $Cache:Paths = @{ }
    $Cache:Paths.Root = (Get-location).Path

    Set-DUDSettingsCache

    $Cache:Paths = @{
        Root                           = $Cache:Paths.Root
        CurrentDashboardFolderFullPath = ''
        CurrentDashboardFullPath       = ''
        CurrentDashboardFolder         = '' 
        CurrentDashboard               = ''
    }

    if ([String]::IsNullOrWhiteSpace($Cache:Paths.CurrentDashboardFolder)) {
        $Cache:Paths.CurrentDashboardFolderFullPath = "$($Cache:Paths.Root)\src"
    }
    else {
        $Cache:Paths.CurrentDashboardFolderFullPath = "$($Cache:Paths.Root)\src\$($Cache:Paths.CurrentDashboardFolder)"
    }


    $Cache:Paths.CurrentDashboardFullPath = "$($Cache:Paths.Root)\src\Root.ps1"


    $LoginFilePath = "$($Cache:Paths.Root)\src\Login.ps1"
    if (Test-Path -Path $LoginFilePath) {
        $Cache:LoginPage = & $LoginFilePath
    }

    $FooterFilePath = "$($Cache:Paths.Root)\src\Footer.ps1"
    if (Test-Path -Path $FooterFilePath) {
        $Cache:Footer = & $FooterFilePath
    }

    $NavigationFilePath = "$($Cache:Paths.Root)\src\Navigation.ps1"
    if (Test-Path -Path $NavigationFilePath) {
        $Cache:Navigation = & $NavigationFilePath
    }

    $Endpoints = Get-DUDEndpoints

    $Params = Get-DUDFolders
    $Cache:Params = $Params


    $DashboardStartParams = @{ }
    if ([String]::IsNullOrWhiteSpace($cache:Settings.UDConfig.SSLCertificatePath) -eq $false) {
        $DashboardStartParams.Certificate = Get-ChildItem -Path $cache:Settings.UDConfig.SSLCertificatePath
    }
    $GetSetting = { Param($MySetting, $ParamName) if ($MySetting -ne $null) { $DashboardStartParams."$ParamName" = $MySetting } }
    $GetSetting.Invoke($cache:Settings.UDConfig.UpdateToken, 'UpdateToken')
    $GetSetting.Invoke($Cache:Paths.CurrentDashboardFullPath, 'FilePath')
    $GetSetting.Invoke($Cache:Settings.UDConfig.Design, 'Design')
    $DashboardStartParams.Endpoint = $Endpoints

    #New-DUDDashboard
    Write-UDLog -Level Debug -Message "Test message" -LoggerName 'hello'
    Write-UDLog -Level Debug -Message "Test message" 
    Start-UDDashboard @PSBoundParameters @DashboardStartParams 
    
}
function Start-DUDHotReloader {
    param(
        [Parameter(Mandatory = $true)]
        $Root,
        [Parameter(Mandatory)]
        $UpdateToken,
        [Parameter(Mandatory)]
        $Url,
        $AppPool,
        [int]$UpdateDelay = 750,
        [String]$DashboardPath,
        [System.Collections.Generic.List[DUDHotReloadPath]]$AdditionalPaths
    )

    Process {
        $fileInfo = [System.IO.FileInfo]::new($Root)

        $fileSystemWatcher = [System.IO.FileSystemWatcher]::new($fileInfo.DirectoryName, "*.*") 
        $fileSystemWatcher.NotifyFilter = [IO.NotifyFilters]::LastWrite
        $fileSystemWatcher.EnableRaisingEvents = $true
        $fileSystemWatcher.IncludeSubdirectories = $true


        $Global:DashboardAction = [DashboardAction]::Undefined
        $Global:DashboardActionRulesQueue = @()
        $Global:DashboardActionDelay = New-Object -TypeName 'System.Timers.Timer' -Property @{
            AutoReset = $true
            Interval  = $UpdateDelay
        }
     
     
        Register-ObjectEvent $Global:DashboardActionDelay elapsed -SourceIdentifier 'ActionDelay' -Action {
            try {
                $Operation = ""
                $Token = $event.MessageData.UpdateToken
                $Url = $event.MessageData.Url
             
                switch ($Global:DashboardAction) {
                    { $_ -band [DashboardAction]::Restart } {
                        $Operation = 'Apppool recycled'
                        Import-Module WebAdministration
                        Restart-WebAppPool -Name $event.MessageData.AppPool    
                        break
                    }
                    { $_ -band [DashboardAction]::Update } {
                        $Operation = 'Dashboard updated'
                        Update-UDDashboard -Url $Url -UpdateToken $Token -FilePath $event.MessageData.DashboardPath
                    }
                }
                if ($Global:DashboardAction -ne [DashboardAction]::Undefined) {
                    Write-Host "$(get-date) $Operation - $Url " -ForegroundColor Cyan
                }
                 
            }
            catch {
                Write-Host $_.Exception -ForegroundColor Red
            }
            Finally {
                $Global:DashboardAction = [DashboardAction]::Undefined
                $Global:DashboardActionDelay.Stop()
            }            

        } -MessageData @{ 
            Url           = $Url 
            UpdateToken   = $UpdateToken
            DashboardPath = $DashboardPath
            AppPool       = $AppPool
        }


        $WatchAction = {
            try {
                $Global:DashboardActionDelay.Stop()
                $Global:DashboardActionDelay.Start()
                $CanRestart = -not [String]::IsNullOrWhiteSpace($event.MessageData.AppPool)
                $RestartAction = [DashboardAction]::Restart
                if (-not $CanRestart) { $RestartAction = [DashboardAction]::Update }

                $Private:Root = $event.MessageData.Root
            
             
                $Private:Paths = New-Object -TypeName 'System.Collections.Generic.Dictionary[String,DashboardAction]'
                $Private:Paths.Add("$($Private:Root)\Dashboard.ps1", $RestartAction)
                $Private:Paths.Add("$($Private:Root)\AppSettings.json", $RestartAction)
                $Private:Paths.Add("$($Private:Root)\*\Endpoints\*.ps1", $RestartAction)
                $Private:Paths.Add("$($Private:Root)\*\Footer.ps1", $RestartAction)
                $Private:Paths.Add("$($Private:Root)\src\Navigation.ps1", $RestartAction)
                $Private:Paths.Add("$($Private:Root)\*.ps1", [DashboardAction]::Update)
                $Private:Paths.Add("$($Private:Root)\src\*.css", [DashboardAction]::Update)
                $Private:Paths.Add("$($Private:Root)\src\*.js", [DashboardAction]::Update)

                Foreach ($key in $Private:Paths.Keys) {
                    if ($event.SourceEventArgs.FullPath -like $key) {
                        Write-Host $key -ForegroundColor Red
                        $Global:DashboardAction = $Global:DashboardAction -bor $Private:Paths[$key] 
                        break
                    }
                }
             
            }
            catch {
                Write-Host $_.Exception -ForegroundColor Red
            }
      
        }

        Register-ObjectEvent $fileSystemWatcher Changed -SourceIdentifier FileChanged -Action $WatchAction -MessageData @{ 
            Root          = $Root
            EndpointsPath = $EndpointsPath
            AppPool       = $AppPool
        }

    }
}
