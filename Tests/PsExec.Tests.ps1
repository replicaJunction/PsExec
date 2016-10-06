if (-not $PSScriptRoot) {
    # Define this variable for PS 2.0
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

if (-not $ENV:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot\..
}

# Refresh the module before running these tests
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope 'PsExec' {
    $PSVersion = $PSVersionTable.PSVersion.Major

    Describe "$ENV:BHProjectName PS$PSVersion" {
        Context 'Basic Behavior' {
            Set-StrictMode -Version latest
            $Module = Get-Module $ENV:BHProjectName

            It 'Module loads successfully' {
                $Module.Name | Should Pe $ENV:BHProjectName
            }

            It 'Module contains functions' {
                $Module.ExportedFunctions.Keys -contains 'Invoke-PsExec' | Should Be $True
            }
        }
    }
}