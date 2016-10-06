function Get-PsExec {
    [CmdletBinding(ConfirmImpact = 'High',
                   SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true,
                   Position = 0)]
        [String] $OutPath,

        [Switch] $Force
    )

    begin {
        $url = 'https://download.sysinternals.com/files/PSTools.zip'
    }

    process {
        # Shell.Application object wil need this to have a .zip extension in order to recognize it as an archive
        $tempFile = '{0}.zip' -f [System.IO.Path]::GetTempFileName()

        $tempExe = Join-Path -Path $env:TEMP -ChildPath 'PsExec.exe'
        if (Test-Path -Path $tempExe) {
            Remove-Item -Path $tempExe -Force
        }

        $client = New-Object -TypeName 'System.Net.WebClient'
        try {
            Write-Verbose "Dowloading PsTools.zip from URL [$url] to path [$tempFile]"
            $client.DownloadFile($url, $tempFile)
        }
        catch {
            throw "Error downloading PsExec.exe: $_"

        }
        Unblock-File -Path $tempFile

        # PS 2.0 compatibility...newer versions can use System.IO.Compression namespace
        $shell = New-Object -ComObject 'Shell.Application'
        $zipFile = $shell.NameSpace($tempFile)
        foreach ($z in $zipFile.Items()) {
            if ($z.Name -eq 'PsExec.exe') {
                Write-Verbose "Extracting file [$($z.Name)]"
                $shell.NameSpace($env:TEMP).CopyHere($z)

                # CopyHere() is asynchronous, so we may need to wait for it to complete on slower systems. PsExec is usually only about 300 KB, though
                $i = 0
                while (-not (Test-Path -Path $tempExe)) {
                    if ($i -gt 9) {
                        throw "Failed to extract PsExec.exe from path [$tempFile] to path [$tempExe]. These files have not been deleted."
                    }
                    Write-Verbose "Waiting for PsExec.exe to be extracted ($i of 10)..."
                    Start-Sleep -Seconds 3
                    $i++
                }
            }
        }

        if (-not (Test-Path -Path $OutPath)) {
            Write-Verbose "Creating directory [$OutPath]"
            New-Item -Path $OutPath -ItemType Directory -Force | Out-Null
        }

        $outFile = Join-Path -Path $OutPath -ChildPath 'PsExec.exe'
        if ($Force -or (-not (Test-Path -Path $OutFile)) -or $PSCmdlet.ShouldProcess($OutFile, "Overwrite existing file")) {
            Move-Item -Path $tempExe -Destination $OutFile -Force
        }
        else {
            Write-Verbose "The file exists, and the user denied the confirmation prompt. Existing file will not be modified."
        }

        Write-Verbose "Removing temporary files"
        Remove-Item -Path $tempFile -Force
    }
}