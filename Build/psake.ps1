# In our build environment, anything output to the pipeline gets displayed on-screen.
# This means we don't need to wrap everything in Write-Output...we can be a bit lazy. ^^

# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
        $ProjectRoot = $ENV:BHProjectPath
        if(-not $ProjectRoot)
        {
            $ProjectRoot = $PSScriptRoot
        }

    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    if($ENV:BHCommitMessage -match "!verbose")
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Deploy

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item env:BH*
    "`n"
}

Task Test -Depends Init  {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile"

    # If using AppVeyor, upload test results for viewing directly through the Web interface
    if ($env:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Test {
    $lines

    # BuildHelpers can automatically set FunctionsToExport in the module manifest. This improves module autoloading performance.
    "Defining FunctionsToExport"
    Set-ModuleFunctions

    # BuildHelpers can also update the module version automatically. What a great module!
    "Incrementing module version"
    $version = Get-NextPSGalleryVersion -Name $env:BHProjectName
    Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value $version
}

Task Deploy -Depends Build {
    $lines

    # Check to make sure we should deploy
    if(
        $env:BHBuildSystem -ne 'Unknown' -and
        $env:BHBranchName -eq "master"
    )
    {
        $Params = @{
            Path = $ProjectRoot
            Force = $true
        }

        Invoke-PSDeploy @Verbose @Params
    }
    else
    {
        "Skipping deployment: To deploy, ensure that...`n" +
        "`t* You are in a known build system (Current: $env:BHBuildSystem)`n" +
        "`t* You are committing to the master branch (Current: $env:BHBranchName)"
    }

}