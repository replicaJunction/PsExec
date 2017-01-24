function Invoke-PsExec {
    [CmdletBinding(DefaultParameterSetName = 'Command')]
    param(
        [Parameter(ParameterSetName = 'Command',
                   Mandatory = $true,
                   Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String] $Command,

        [Parameter(ParameterSetName = 'PSScriptFile',
                   Mandatory = $true)]
        [String] $ScriptFile,

        [Parameter(Mandatory = $false,
                   Position = 1,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true,
                   ValueFromRemainingArguments = $true)]
        [String[]] $ComputerName = $env:COMPUTERNAME,

        # Working directory to use on the remote system
        [String] $WorkingDirectory,

        # Copy file to remote system (-c). Note that if this is specified, a full path in the Command paramer will be interpreted by PSExec as a local path (to a file that should be copied) rather than a path on the remote device.
        [Parameter(Mandatory = $false)]
        [Switch] $Copy,

        # Allow the process to interact with the logged-in user (note that this can prevent console output from being returned correctly)
        [Parameter(Mandatory = $false)]
        [Switch] $Interactive,

        # Invoke the command as the SYSTEM account
        [Parameter(Mandatory = $false)]
        [Switch] $System,

        # Load the user's profile
        [Parameter(Mandatory = $false)]
        [Switch] $LoadProfile,

        # Wait for the process to complete
        [Parameter(Mandatory = $false)]
        [Switch] $Wait,

        # Credentials to use for the remote command. Recent versions of PSExec will encrypt credentials sent over the network.
        [Parameter(Mandatory = $false)]
        [pscredential] $Credential,

        # Seconds to wait for PSExec before timing out. Default is 1800 (30 minutes).
        [Parameter(Mandatory = $false)]
        [Int] $TimeoutSeconds = 1800,

        # Path to PSExec.exe
        [Parameter(Mandatory = $false)]
        [ValidateScript({(Test-Path $_)})]
        [String] $PsExecPath
    )

    begin {
        $oldDebugPreference = $null
        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            if ($DebugPreference -eq 'Inquire') {
                $oldDebugPreference = $DebugPreference
                $DebugPreference = 'Continue'
            }
        }

        if (-not $PsExecPath) {
            $PsExecPath = Get-Command -Name 'psexec' -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty Definition -ErrorAction SilentlyContinue

            if ([String]::IsNullOrEmpty($PsExecPath)) {
                Write-Debug "[Invoke-PsExec] PSExec.exe was not found. Throwing exception."
                throw "Unable to locate PSExec.exe. Place this file in the working directory [$PWD] or in the PATH variable, or specify it via the -PsExecPath parameter."
            }
            Write-Debug "[Invoke-PsExec] Using PSExec at path $PsExecPath"
        }

        # Type name of the object that gets output
        $outputType = 'PsExec.Result'

        # ProcessStartInfo uses ms instead of seconds
        $timeoutMilliseconds = $TimeoutSeconds * 1000

        $args = New-Object -TypeName System.Text.StringBuilder -ArgumentList '-accepteula '

        # [void] $args.Append("-accepteula \\{0}") # Computer name will go here
        if ($ComputerName) {
            [void] $args.Append('\\{0} ')
        }

        # Timeout after 30 seconds. This shouldn't be an issue since we're already using Test-Connection, but it's a good safeguard.
        # Also note the space at the end. This leads into the switch statement below.
        [void] $args.Append('-n 30 ')

        if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            Write-Debug "[Invoke-PsExec] Adding credentials for $($Credential.UserName)"
            [void] $args.AppendFormat('-u {0} -p {1} ', $Credential.UserName, $Credential.GetNetworkCredential().Password)
        }
        if ($WorkingDirectory) {
            [void] $args.Append("-w ""$WorkingDirectory"" ")
        }
        if ($Copy) {
            [void] $args.Append('-c -f ')
        }
        if (-not $Wait) {
            [void] $args.Append('-d ')
        }
        if (-not $LoadProfile) {
            [void] $args.Append('-e ')
        }
        if ($Interactive) {
            [void] $args.Append('-i ')
        }
        if ($System) {
            [void] $args.Append('-s ')
        }


        switch ($PSCmdlet.ParameterSetName) {
            'Command' {
                if (-not $Copy) {
                    # cmd /s causes the interpreter to ignore the first and last pair of quotes, then treat everything else literally.
                    # This allows the user to specify whatever quotes he needs without worrying about escaping them.
                    
                    # References:
                    # http://stackoverflow.com/questions/355988/how-do-i-deal-with-quote-characters-when-using-cmd-exe
                    # http://stackoverflow.com/questions/9866962/what-is-cmd-s-for
                    
                    [void] $args.Append("cmd /s /c `" $Command `"")
                }
                else {
                    # If we're copying the file, we can't use the cmd /c prefix, because PsExec expects the file path provided to be a path to a local file
                    [void] $args.Append("$Command")
                }
            }
            'PSScriptFile' {
                $remoteTempFilename = 'psexecTemp.ps1'
                # Apparently we need to pipe some data into STDIN in order to get PSExec to exit properly
                # More details here: http://www.leeholmes.com/blog/2007/10/02/using-powershell-and-psexec-to-invoke-expressions-on-remote-computers/
                [void] $args.Append("cmd /c `"echo . | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $env:SystemRoot\$remoteTempFilename`"")
            }
            default {
                Write-Warning "Invoke-PsExec error: Unhandled parameter set name $($PSCmdlet.ParameterSetName)"
            }
        }

        $psExecArguments = $args.ToString()
    }

    process {
        foreach ($c in $ComputerName) {

            $fixedComputerName = $null

            if ($c -eq $env:COMPUTERNAME) {
                # Remove computer name argument for running on localhost
                $thisArgs = $psExecArguments.Replace(' \\{0}', '')
            }
            else {
                # Check for FQDN or CN. Apparently, PSExec returns output differently between the two, but you can "trick" it into redirecting normally if you add a dot (.) to the end of a CN.
                #
                # See this question for details: http://superuser.com/a/1038787
                if ($c -notmatch '\.') {
                    $fixedComputerName = "$c."
                }
                else {
                    $fixedComputerName = $c
                }
                Write-Debug "[Invoke-PsExec] Processing computer name: [$fixedComputerName]"
                $thisArgs = $psExecArguments.Replace('{0}', $fixedComputerName)
            }

            if (-not $Credential) {
                $thisArgsClean = $thisArgs
            }
            else {
                # Clean password from displayed output
                $thisArgsClean = $thisArgs -replace '(\s+)\-p\s+\S+\s', "$($Matches[1])-p <password>$($Matches[1])"
            }

            if ($PSVersionTable.PSVersion.Major -gt 2) {
                $props = [PSCustomObject] @{
                    PSTypeName    = $outputType
                    ComputerName  = $c
                    CommandLine   = "$PsExecPath $thisArgsClean"
                    Ping          = $false
                    Success       = $false
                    ExitCode      = -1
                    StandardOut   = ""
                    StandardError = ""
                }
                $useV2 = $false
            }
            else {
                $props = @{
                    ComputerName  = $c
                    CommandLine   = "$PsExecPath $thisArgsClean"
                    Ping          = $false
                    Success       = $false
                    ExitCode      = -1
                    StandardOut   = ""
                    StandardError = ""
                }
                $useV2 = $true
            }

            if ((-not $fixedComputerName) -or (Test-Connection -ComputerName $fixedComputerName -BufferSize 16 -Count 2 -Quiet)) {
                $props.Ping = $true
                Write-Debug "[Invoke-PsExec] Arguments for PSExec on this computer: [$thisArgs]"

                if ($PSCmdlet.ParameterSetName -eq 'PSScriptFile') {
                    $remoteScriptFile = Join-Path -Path "\\$c\admin`$" -ChildPath $remoteTempFilename
                    Write-Debug "[Invoke-PsExec] Copying script file to path [$remoteScriptFile]"
                    Copy-Item -Path $ScriptFile -Destination $remoteScriptFile -Force
                }

                # We're using System.Diagnostics.Process instead of Start-Process due to the way Start-Process handles output redirection. (Spoilers: It doesn't.)
                $pInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
                # $pInfo.FileName = 'cmd.exe'
                $pInfo.FileName = $PsExecPath
                $pInfo.RedirectStandardOutput = $true
                $pInfo.RedirectStandardError = $true
                $pInfo.UseShellExecute = $false
                # $pInfo.Arguments = "/c $PsExecPath $thisArgs"
                $pInfo.Arguments = $thisArgs

                $p = New-Object -TypeName System.Diagnostics.Process
                $p.StartInfo = $pInfo

                # Write-Verbose "Invoking PSExec on computer $c"
                Write-Debug "[Invoke-PsExec] Starting PSExec"
                try {
                    [void] $p.Start()

                    $stdOut = $p.StandardOutput.ReadToEndAsync()
                    $stdErr = $p.StandardError.ReadToEndAsync()

                    $hasExited = $p.WaitForExit($timeoutMilliseconds)
                    if (-not $hasExited) {
                        Write-Debug "[Invoke-PsExec] PsExec did not terminate in [$TimeoutSeconds] seconds; forcibly closing process"
                        $p.Kill()
                    }
                    # [void] $stdOut.Wait()
                    # [void] $stdErr.Wait()

                    $exitCode = $p.ExitCode
                    Write-Debug "PSExec exited with code $exitCode"
                    $props.ExitCode = $exitCode

                    if ($p.ExitCode -eq 0) {
                        $props.Success = $true
                    }

                    $props.StandardOut = "$($stdOut.Result)".Trim()
                    $props.StandardError = "$($stdErr.Result)".Trim()
                }
                catch {
                    Write-Verbose "PSExec encountered an exception: $_"
                    $props.StandardError = "$_"
                }
                finally {
                    if ($PSCmdlet.ParameterSetName -eq 'PSScriptFile') {
                        Write-Debug "[Invoke-PSExec] Removing temporary script file"
                        Remove-Item -Path $remoteScriptFile -Force
                    }
                }
            }
            else {
                Write-Verbose "Unable to connect to computer [$fixedComputerName]"
            }

            if (-not $useV2) {
                # If we're in v3 or greater, $props is already a custom object.
                Write-Output $props
            }
            else {
                # Otherwise, we need to create an object out of it.
                $obj = New-Object -TypeName PSCustomObject -Property $props
                $obj.PSTypeNames.Insert(0, $outputType)
                Write-Output $obj
            }
        }
    }

    end {
        if ($oldDebugPreference) {
            $DebugPreference = $oldDebugPreference
        }
    }
}
