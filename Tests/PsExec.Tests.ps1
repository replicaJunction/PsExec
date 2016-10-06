if (-not $PSScriptRoot) {
    # Define this variable for PS 2.0
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

if (-not $env:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot\..
}

# Refresh the module before running these tests
Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
Write-Host "Attempting to import module [$env:BHPSModuleManifest]" -ForegroundColor Cyan
Import-Module $env:BHPSModuleManifest -Force
# Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

if (Get-Module $env:BHProjectName) {

}

InModuleScope 'PsExec' {
    $PSVersion = $PSVersionTable.PSVersion.Major

    Describe "$ENV:BHProjectName PS$PSVersion" {
        Context 'Basic Behavior' {
            Set-StrictMode -Version latest
            $module = Get-Module $env:BHProjectName

            It 'Module loads successfully' {
                $module.Name | Should Pe $env:BHProjectName
            }

            It 'Module contains functions' {
                $moodule.ExportedFunctions.Keys -contains 'Invoke-PsExec' | Should Be $True
            }
        }
    }
}
