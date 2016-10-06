if (-not $PSScriptRoot) {
    # Define this variable for PS 2.0
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$ModuleRoot = $PSScriptRoot

$Public  = @( Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue )

# Placeholder for private functions. Currently, the module doesn't use any.
# $Private = @( Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue )
$Private = @()

# Dot-source each file to load them
foreach($file in @($Public + $Private)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($file.FullName): $_"
    }
}

# Export the public functions
Export-ModuleMember -Function ($Public | Select -ExpandProperty Basename)