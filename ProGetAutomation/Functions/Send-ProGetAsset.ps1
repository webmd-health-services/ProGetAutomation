function Send-ProGetAsset
{
    <#
    .SYNOPSIS
    Uploads file to a ProGet asset directory. ***This is an internal ProGetAutomation function. Use `Set-ProGetAsset`
    instead.

    .DESCRIPTION
    The `Send-ProGetAsset` function is an internal ProGetAutomation function. You should be using `Set-ProGetAsset`
    instead.

    The `Send-ProGetAsset` function uploads a file to a ProGet asset directory. The file can be any size. ProGet has
    undocumented capabilities to upload files in parts instead of the whole file and this function uses those
    undocumented features.

    Pass the session to ProGet to the `Session` parameter. Pass the path to the asset to the `AssetPath` parameter, e.g.
    `/endpoints/DIRECTORY_NAME/content/PATH_TO_FILE`. Pass the path to the source file to upload to the `FilePath`
    parameter. Pass the size, in bytes, of each part to the `MaxRequestSize` parameter.

    The default max request content size in IIS is 30 MB/28.6 MiB and in Apache is 1 GB.

    This function is adapted from https://gist.github.com/inedo-builds/cbee07725b3e227b0b566d028d4d3d07.

    .EXAMPLE
    Send-ProGetAsset -Session $Session -AssetPath '/endpoints/Installer/content/PowerShell/PowerShell-7.3.3.exe` -FilePath ~\Downloads\PowerShell-7.3.3.exe -MaxRequestSize 5mb

    Demonstrates how to use `Send-ProGetAsset`. In this example, the "~\Downloads\PowerShell-7.3.3.exe" file will be
    uploaded to the "Installers" asset directory at "Powershell/PowerShell-7.3.3.exe"
    #>
    [CmdletBinding()]
    param(
        # The session to ProGet. Use `New-ProGetSession` to create a session object.
        [Parameter(Mandatory)]
        [Object] $Session,

        # The asset's path. This is the path to the asset upload endpoint and is usually
        # `/endpoints/DIR_NAME/content/ASSET_PATH`.
        [Parameter(Mandatory)]
        [String] $AssetPath,

        # Path to the local file to upload.
        [Parameter(Mandatory)]
        [String] $FilePath,

        # The size of each part/request to upload to ProGet.
        [Parameter(Mandatory)]
        [UInt32] $MaxRequestSize
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $headers = Get-ProGetRequestHeader -Session $Session
    $id = (New-Guid).ToString('N')

    function New-ProGetMultipartUploadRequest
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [Uri] $BaseUrl,

            [Parameter(Mandatory, ParameterSetName='Part')]
            [UInt32] $Index,

            [Parameter(Mandatory, ParameterSetName='Part')]
            [UInt64] $Offset,

            [Parameter(Mandatory, ParameterSetName='Part')]
            [UInt64] $TotalSize,

            [Parameter(Mandatory, ParameterSetName='Part')]
            [UInt32] $PartSize,

            [Parameter(Mandatory, ParameterSetName='Part')]
            [UInt32] $TotalParts,

            [Parameter(Mandatory, ParameterSetName='Complete')]
            [switch] $Complete
        )

        $reqUrl = "$($BaseUrl)?id=$($id)"
        $contentLength = 0
        if ($Complete)
        {
            $reqUrl = "$($reqUrl)&multipart=complete"
        }
        else
        {
            $reqUrl = "$($reqUrl)&multipart=upload" +
                                "&index=$($Index)" +
                                "&offset=$($Offset)" +
                                "&totalSize=$($TotalSize)" +
                                "&partSize=$($PartSize)" +
                                "&totalParts=$($TotalParts)"
            $contentLength = $PartSize
        }

        $req = [System.Net.WebRequest]::CreateHttp($reqUrl)

        foreach ($headerName in $headers.Keys)
        {
            $req.Headers[$headerName] = $headers[$headerName]
        }

        $req.Method = 'POST'
        $req.ContentLength = $contentLength
        $req.AllowWriteStreamBuffering = $false

        Write-Verbose "POST $($reqUrl)"
        foreach ($headerName in $req.Headers.AllKeys)
        {
            $headerValue = $req.Headers[$headerName]
            if ($headerName -eq 'Authorization')
            {
                $headerValue = "Basic $('*' * ($headerValue.Length - 7))"
            }
            Write-Debug "     $($headerName): $($headerValue)"
        }
        Write-Debug ''

        return $req
    }

    # Adapted from https://gist.github.com/inedo-builds/cbee07725b3e227b0b566d028d4d3d07
    $FilePath = Resolve-Path -Path $FilePath | Select-Object -ExpandProperty 'ProviderPath'
    if (-not $FilePath)
    {
        return
    }

    $fileInfo = Get-Item -Path $FilePath
    if ($fileInfo.Length -eq 0)
    {
        return
    }

    $baseUrl = "$($Session.Url.ToString().TrimEnd('/'))/$($AssetPath.TrimStart('/'))"
    $activity = "Uploading ""$($FilePath | Resolve-Path -Relative)"" to $($baseUrl)."
    $remainder = [UInt64]0
    [UInt64]$totalBytesRead = 0

    $lastWriteProgress = [Diagnostics.Stopwatch]::StartNew()
    $writeProgressEvery = [TimeSpan]::New(0, 0, 0, 0, 100)

    $fileStream = [IO.FileStream]::New($FilePath,
                                       [IO.FileMode]::Open,
                                       [IO.FileAccess]::Read,
                                       [IO.FileShare]::Read,
                                       4096,
                                       [IO.FileOptions]::SequentialScan)

    try
    {
        $fileLength = $fileStream.Length
        $totalParts = [Math]::DivRem([long]$fileLength, [long]$MaxRequestSize, [ref]$remainder)
        if ($remainder -ne 0)
        {
            $totalParts++
        }

        for($index = 0 ; $index -lt $totalParts ; $index++)
        {
            $offset = $index * $MaxRequestSize
            $chunkSize = $MaxRequestSize
            if($index -eq ($totalParts - 1))
            {
                $chunkSize = $fileLength - $offset
            }

            $req = New-ProGetMultipartUploadRequest -BaseUrl $baseUrl `
                                                    -Index $index `
                                                    -Offset $offset `
                                                    -TotalSize $fileLength `
                                                    -PartSize $chunkSize `
                                                    -TotalParts $totalParts

            Write-Debug "[chunk $($index + 1) of $($totalParts); bytes $($offset) - $($offset + $chunkSize)]"
            $reqStream = $req.GetRequestStream()
            try
            {
                $buffer = [Array]::CreateInstance([System.Byte], 32767)
                if ($index -eq 0 -or $lastWriteProgress.Elapsed -gt $writeProgressEvery)
                {
                    $percentComplete = $totalBytesRead / $fileLength * 100
                    $status = "Uploading chunk $($index + 1) of $($totalParts)"
                    Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete
                    $lastWriteProgress.Restart()
                }

                $totalChunkBytesRead = 0
                while ($true)
                {
                    $bytesRead = $fileStream.Read($buffer, 0, [Math]::Min($chunkSize - $totalChunkBytesRead, $buffer.Length))

                    if($bytesRead -eq 0)
                    {
                        break
                    }

                    $reqStream.Write($buffer, 0, $bytesRead)

                    $totalBytesRead += $bytesRead
                    $totalChunkBytesRead += $bytesRead
                    if($totalChunkBytesRead -ge $chunkSize)
                    {
                        break
                    }
                }
            }
            finally
            {
                if ($null -ne $reqStream)
                {
                    $reqStream.Dispose()
                }
            }

            $response = $null
            try
            {
                $response = $req.GetResponse()
            }
            finally
            {
                if($null -ne $response)
                {
                    $response.Dispose()
                }
            }
        }

        Write-Progress -Activity $activity -Status "Completing upload." -PercentComplete 100

        $req = New-ProGetMultipartUploadRequest -BaseUrl $baseUrl -Complete
        $response = $null
        try
        {
            $response = $req.GetResponse()
        }
        finally
        {
            if ($null -ne $response)
            {
                $response.Dispose()
            }
        }
    }
    finally
    {
        Write-Progress -Activity $activity -Completed
        if ($null -ne $fileStream)
        {
            $fileStream.Dispose()
        }
    }
}
