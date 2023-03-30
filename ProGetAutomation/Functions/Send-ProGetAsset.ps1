function Send-ProGetAsset
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object] $Session,

        [Parameter(Mandatory)]
        [String] $AssetPath,

        [Parameter(Mandatory, ParameterSetName='ByFile')]
        [String] $FilePath,

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
        if($remainder -ne 0)
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
