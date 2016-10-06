function Resolve-Module
{
    [Cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]$Name
    )

    Process
    {
        foreach ($ModuleName in $Name)
        {
            $Module = Get-Module -Name $ModuleName -ListAvailable
            Write-Verbose -Message "Resolving Module $($ModuleName)"

            if ($Module)
            {
                $Version = $Module | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
                $GalleryVersion = Find-Module -Name $ModuleName -Repository PSGallery | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum

                if ($Version -lt $GalleryVersion)
                {

                    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted }

                    Write-Verbose -Message "$($ModuleName) Installed Version [$($Version.tostring())] is outdated. Installing Gallery Version [$($GalleryVersion.tostring())]"

                    Install-Module -Name $ModuleName -Force
                    Import-Module -Name $ModuleName -Force -RequiredVersion $GalleryVersion
                }
                else
                {
                    Write-Verbose -Message "Module Installed, Importing $($ModuleName)"
                    Import-Module -Name $ModuleName -Force -RequiredVersion $Version
                }
            }
            else
            {
                Write-Verbose -Message "$($ModuleName) Missing, installing Module"
                Install-Module -Name $ModuleName -Force
                Import-Module -Name $ModuleName -Force -RequiredVersion $Version
            }
        }
    }
}

# Grab nuget bits, install modules, set build variables, start build.
Write-Host "Setting up package provider" -ForegroundColor Green
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Write-Host "Downloading dependencies" -ForegroundColor Green
Resolve-Module Psake, PSDeploy, Pester, BuildHelpers

# Create environment variables using ramblingcookiemonster's BuildHelpers module.
# This abstracts the AppVeyor stuff out of the build process so this build will also work on TravisCI, Jenkins, etc.
Write-Host "Setting up build environment (BuildHelpers)" -ForegroundColor Green
Set-BuildEnvironment

# Now pass control to PSake
Write-Host "Invokeing PSake" -ForegroundColor Green
Write-Host
Invoke-PSake .\psake.ps1

# Exit with either a 0 (success) or a 1 (failure) so the build environment knows whether it succeeded
exit ( [int]( -not $psake.build_success ) )
