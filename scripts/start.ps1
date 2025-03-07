<#
.NOTES
    Author         : Chris Titus @christitustech
    Runspace Author: @DeveloperDurp
    GitHub         : https://github.com/ChrisTitusTech
    Version        : #{replaceme}
#>

param (
    [switch]$Debug,
    [string]$Config,
    [switch]$Run
)

#region Initialization and Configuration
# Set DebugPreference early
$DebugPreference = if ($Debug) { "Continue" } else { "SilentlyContinue" }

# Admin elevation check
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Winutil needs Administrator privileges. Relaunching..."
    
    $argList = @('-ExecutionPolicy Bypass -NoProfile -Command') + (
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch]) { "-$($_.Key)" } 
            else { "-$($_.Key) `"$($_.Value)`"" }
        }
    )
    
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } 
                  else { if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" } }
    
    Start-Process $processCmd -ArgumentList $argList -Verb RunAs
    exit
}

# Initialize core variables
$sync = [Hashtable]::Synchronized(@{
    version = "#{replaceme}"
    configs = @{
        applications = @{}
        tweaks = @{}
        feature = @{}
    }
    ProcessRunning = $false
    PSScriptRoot = $PSScriptRoot
})

# Configure logging
$logDir = "$env:LOCALAPPDATA\winutil\logs"
[System.IO.Directory]::CreateDirectory($logDir) | Out-Null
Start-Transcript -Path "$logDir\winutil_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log" -Append

# Set window title
$Host.UI.RawUI.WindowTitle = "$($MyInvocation.MyCommand.Definition) (Admin)"
Clear-Host
#endregion

#region Main Application Code
# Load assemblies
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

# Existing improved code structure
try {
    #region Runspace Initialization
    $CONFIG = @{
        MaxThreads = [int]$env:NUMBER_OF_PROCESSORS
        ChocoPreferencePath = "$env:LOCALAPPDATA\winutil\preferChocolatey.ini"
        DebounceIntervalSeconds = 2
    }

    # Runspace pool creation (from previous improvements)
    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $initialSessionState.Variables.Add((
        New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry(
            'sync', $sync, $null
        )
    ))

    # Add functions to session state
    Get-ChildItem function:\ | Where-Object { $_.Name -imatch 'winutil|Microwin|WPF' } | ForEach-Object {
        $initialSessionState.Commands.Add((
            New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry(
                $_.Name, 
                (Get-Content "function:\$($_.Name)" -Raw
            )
        ))
    }

    $sync.runspace = [runspacefactory]::CreateRunspacePool(
        1,
        $CONFIG.MaxThreads,
        $initialSessionState,
        $Host
    )
    $sync.runspace.Open()
    #endregion

    #region GUI Initialization
    # XAML processing and form creation (from previous improvements)
    [xml]$xaml = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync["Form"] = [Windows.Markup.XamlReader]::Load($reader)
    
    # Find and store all named elements
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $sync[$_.Name] = $sync["Form"].FindName($_.Name)
    }
    #endregion

    #region Parameter Handling
    if ($Config) {
        $PARAM_CONFIG = $Config
        Invoke-WPFImpex -type "import" -Config $PARAM_CONFIG
        
        if ($Run) {
            Write-Host "Automating configured tasks..."
            $PARAM_RUN = $true
            
            # Automated execution flow
            while ($sync.ProcessRunning) { Start-Sleep -Seconds 1 }
            Invoke-WPFtweaksbutton
            
            while ($sync.ProcessRunning) { Start-Sleep -Seconds 1 }
            Invoke-WPFFeatureInstall
            
            while ($sync.ProcessRunning) { Start-Sleep -Seconds 1 }
            Invoke-WPFInstall
        }
    }
    #endregion

    #region Event Handlers and UI Setup
    # Existing improved event handling code
    $sync["Form"].Add_Loaded({
        # Theme handling and other initialization
        Invoke-WinutilThemeChange -init $true
        # Load UI elements
        Invoke-WPFUIElements -configVariable $sync.configs.applications -targetGridName "appspanel" -columncount 5
        Invoke-WPFUIElements -configVariable $sync.configs.tweaks -targetGridName "tweakspanel" -columncount 2
        Invoke-WPFUIElements -configVariable $sync.configs.feature -targetGridName "featurespanel" -columncount 2
    })

    # Add other event handlers from previous improvements
    # ...
    #endregion

    #region Main Execution
    # Show main form
    $sync["Form"].ShowDialog() | Out-Null
    #endregion

}
catch {
    Write-Error "Main execution failed: $_"
    exit 1
}
finally {
    # Cleanup
    if ($sync.runspace) {
        $sync.runspace.Dispose()
        $sync.runspace.Close()
    }
    [System.GC]::Collect()
    Stop-Transcript
}
#endregion

# Include all previous feature implementations (Health Dashboard, Maintenance Tasks, etc.)
# ...