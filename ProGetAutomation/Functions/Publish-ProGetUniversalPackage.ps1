
function Publish-ProGetUniversalPackage
{
    <#
    .SYNOPSIS
    Publishes a universal package to ProGet.

    .DESCRIPTION
    The `Publish-ProGetUniversalPackage` function will upload a package to the `FeedName` universal feed. It uses .NET's
    `HttpClient` to upload the file.

    .EXAMPLE
    Publish-ProGetUniversalPackage -Session $session -FeedName 'Apps' -PackagePath 'C:\ProGetPackages\TestPackage.upack'

    Demonstrates how to call `Publish-ProGetUniversalPackage`. In this case, the package named 'TestPackage.upack' will
    be published to the 'Apps' feed located at `$Session.Url` using `$Session.Credential` and/or `$Session.ApiKey` to
    authenticate.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The session includes ProGet's URI and the credentials to use when utilizing ProGet's API.
        [Parameter(Mandatory)]
        [pscustomobject] $Session,

        # The feed name indicates the appropriate feed where the package should be published.
        [Parameter(Mandatory)]
        [String] $FeedName,

        # The path to the package that will be published to ProGet.
        [Parameter(Mandatory)]
        [String] $PackagePath,

        # The timeout (in seconds or TimeSpan) for the upload. The default is 100 seconds.
        [Object] $Timeout,

        # Replace the package if it already exists in ProGet.
        [switch] $Force,

        # The number of times to retry the upload. Default is one time.
        [int] $RetryCount = 0,

        # The amount of time to wait between retries of the upload. The default value is 5 seconds.
        [TimeSpan] $RetryInterval = (New-TimeSpan -Seconds 5)
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if (-not $Timeout)
    {
        $Timeout = New-TimeSpan -Seconds 100
    }
    elseif ($Timeout -isnot [TimeSpan])
    {
        $Timeout = New-TimeSpan -Seconds $Timeout
    }

    $pgPackageUploadUrl = [Uri]::New($Session.Url,('/upack/{0}' -f $FeedName))
    $pgCredential = $Session.Credential
    $pgApiKey = $Session.ApiKey

    $PackagePath = Resolve-Path -Path $PackagePath | Select-Object -ExpandProperty 'ProviderPath'
    if( -not $PackagePath )
    {
        Write-Error -Message ('Package ''{0}'' does not exist.' -f $PSBoundParameters['PackagePath'])
        return
    }

    $authMsg = ''
    if( $pgCredential )
    {
        $authMsg = " as user ""$($pgCredential.userName)"""
    }

    if ($pgApiKey)
    {
        $authmsg = "${authMsg} with API key ""$($pgApiKey -replace '^(.{4}).*(.{4})$', '$1********$2')"""
    }

    if( -not $Force )
    {
        $version = $null
        $name = $null
        $group = $null
        $zip = $null
        $foundUpackJson = $true
        $invalidUpackJson = $false
        try
        {
            $zip = [ZipFile]::OpenRead($PackagePath)
            $foundUpackJson = $false
            foreach( $entry in $zip.Entries )
            {
                if($entry.FullName -ne "upack.json" )
                {
                    continue
                }

                $foundUpackJson = $true
                $stream = $entry.Open()
                $stringReader = [StreamReader]::New($stream)
                try
                {
                    $packageJson = $stringReader.ReadToEnd() | ConvertFrom-Json
                    $version = $packageJson.version
                    $name = $packageJson.name
                    if( $packageJson | Get-Member -Name 'group' )
                    {
                        $group = $packageJson.group
                    }
                }
                catch
                {
                    $invalidUpackJson = $true
                }
                finally
                {
                    $stringReader.Close()
                    $stream.Close()
                }
                break
            }
        }
        catch
        {
            Write-Error -Message ('The upack file ''{0}'' isn''t a valid ZIP file.' -f $PackagePath)
            return
        }
        finally
        {
            if( $zip )
            {
                $zip.Dispose()
            }
        }

        if( -not $foundUpackJson )
        {
            Write-Error -Message ('The upack file ''{0}'' is invalid. It must contain a upack.json metadata file. See http://inedo.com/support/documentation/various/universal-packages/universal-feed-api for more information.' -f $PackagePath)
            return
        }

        if( $invalidUpackJson )
        {
            Write-Error -Message (@"
The upack.json metadata file in '$($PackagePath)' is invalid. It must be a valid JSON file with ''version'' and ''name'' properties that have values, e.g.

    {
        ""name"": ""HDARS"",
        ""version": ""1.3.9""
    }

See http://inedo.com/support/documentation/various/universal-packages/universal-feed-api for more information.

"@)
            return
        }

        if( -not $name -or -not $version )
        {
            [string[]]$propertyNames = @( 'name', 'version') | Where-Object { -not (Get-Variable -Name $_ -ValueOnly) }
            $description = 'property doesn''t have a value'
            if( $propertyNames.Count -gt 1 )
            {
                $description = 'properties don''t have values'
            }
            $emptyPropertyNames =  $propertyNames -join ''' and '''

            Write-Error -Message ('The upack.json metadata file in ''{0}'' is invalid. The ''{1}'' {2}. See http://inedo.com/support/documentation/various/universal-packages/universal-feed-api for more information.' -f $PackagePath,$emptyPropertyNames,$description)
            return
        }

        $packageInfo = Get-ProGetUniversalPackage -Session $Session -FeedName $FeedName -GroupName $group -Name $name -ErrorAction Ignore
        if( $packageInfo -and $packageInfo.versions -contains $version )
        {
            Write-Error -Message ('Package {0} {1} already exists in universal ProGet feed ''{2}''.' -f $name,$version,$pgPackageUploadUrl)
            return
        }
    }

    $operationDescription = "Uploading ""${PackagePath}"" to ProGet at ${pgPackageUploadUrl}${authMsg}."
    $shouldProcessCaption = "creating ${PackagePath} package"
    if (-not $PSCmdlet.ShouldProcess($operationDescription, $operationDescription, $shouldProcessCaption))
    {
        return
    }

    Write-Information "[${pgPackageUploadUrl}]  Uploading ""${PackagePath}""."

    $networkCred = $null
    if( $pgCredential )
    {
        $networkCred = $pgCredential.GetNetworkCredential()
    }

    function Format-Timeout
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory, ValueFromPipeline)]
            [TimeSpan] $Timeout
        )

        process
        {
            if ($Timeout.TotalSeconds -le 1)
            {
                return "$($Timeout.TotalMilliseconds.ToString('##0'))ms"
            }

            return "$($Timeout.TotalSeconds.ToString('0.###'))s"
        }
    }

    $durationMsg = $RetryInterval | Format-Timeout
    $timeoutMsg = $Timeout | Format-Timeout

    $tryNum = 0
    while ($tryNum++ -le $RetryCount)
    {
        $lastTry = $tryNum -ge $RetryCount
        $retryMsg = ''
        if (-not $lastTry)
        {
            $retryMsg = " Retrying again in ${durationMsg} (attempt $($tryNum + 1) of ${RetryCount})."
        }

        [HttpClientHandler]$httpClientHandler = $null
        [HttpClient]$httpClient = $null
        [FileStream]$packageStream = $null
        [StreamContent]$streamContent = $null
        [Task[HttpResponseMessage]]$httpResponseTask = $null
        [HttpResponseMessage]$response = $null
        [Threading.CancellationTokenSource]$canceller = $null
        try
        {
            $httpClientHandler = [HttpClientHandler]::New()
            if( $pgCredential )
            {
                $httpClientHandler.UseDefaultCredentials = $false
                $httpClientHandler.Credentials = $networkCred
            }
            $httpClientHandler.PreAuthenticate = $true;

            $httpClient = [HttpClient]::New([HttpMessageHandler]$httpClientHandler)
            $httpClient.Timeout = $Timeout
            if ($pgApiKey)
            {
                $httpClient.DefaultRequestHeaders.Add('X-ApiKey', $pgApiKey)
            }

            $packageStream = [FileStream]::New($PackagePath, 'Open', 'Read')
            $streamContent = [StreamContent]::New([Stream]$packageStream)
            $streamContent.Headers.ContentType = [MediaTypeHeaderValue]::New('application/octet-stream')
            $canceller = [CancellationTokenSource]::New()

            $httpVersion = '1.1'
            if ($httpClient | Get-Member -Name 'DefaultRequestVersion')
            {
                $httpVersion = $httpClient.DefaultRequestVersion
            }
            Write-Verbose "PUT ${pgPackageUploadUrl} HTTP ${httpVersion}"
            foreach ($header in $httpClient.DefaultRequestHeaders)
            {
                $value = $header.Value
                if ($header.Key -eq 'X-ApiKey')
                {
                    $value = '*' * ($value | Select-Object -First 1).Length
                }
                Write-Verbose "$($header.Key): ${value}"
            }
            Write-Verbose ""
            Write-Verbose $PackagePath
            Write-Verbose ""

            $httpResponseTask =
                $httpClient.PutAsync($pgPackageUploadUrl, [HttpContent]$streamContent, $canceller.Token)
            $requestCompleted = $false
            $numErrors = $Global:Error.Count
            try
            {
                $requestCompleted = $httpResponseTask.Wait($Timeout)
            }
            catch
            {
                if ($lastTry)
                {
                    Write-Error -ErrorRecord $_ -ErrorAction $ErrorActionPreference
                }
                else
                {
                    # Only show exceptions/errors from the last request.
                    $numNewErrors = $Global:Error.Count - $numErrors
                    for ($idx = 0 ; $idx -lt $numNewErrors ; ++$idx)
                    {
                        $Global:Error.RemoveAt(0)
                    }
                }
            }

            if (-not $requestCompleted -or $httpResponseTask.IsCanceled)
            {
                $msg = "Failed to upload ""${PackagePath}"" to ""${pgPackageUploadUrl}"", either because the request " +
                       "timed out after ${timeoutMsg} or because of an unknown networking problem.${retryMsg}"
                if ($lastTry)
                {
                    Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                    return
                }

                Write-Verbose -Message $msg
            }
            else
            {
                $response = $httpResponseTask.Result
                if (-not $response.IsSuccessStatusCode)
                {
                    $readContentTask = $response.Content.ReadAsStringAsync()
                    $readContentTask.Wait()
                    $msg = "Failed to upload ""${PackagePath}"" to ""${pgPackageUploadUrl}"": " +
                           "$([int]$response.StatusCode) $($response.StatusCode) $($readContentTask.Result)" +
                           "${retryMsg}"
                    if ($lastTry)
                    {
                        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                        return
                    }
                    Write-Verbose -Message $msg
                }
            }

            if ($lastTry)
            {
                break
            }

            Start-Sleep -Milliseconds $RetryInterval.TotalMilliseconds
        }
        finally
        {
            $disposables = @(
                'httpClientHandler',
                'httpClient',
                'canceller',
                'packageStream',
                'streamContent',
                'httpResponseTask',
                'response'
            )

            $disposables |
                ForEach-Object { Get-Variable -Name $_ -ValueOnly -ErrorAction Ignore } |
                Where-Object { $_ -ne $null } |
                ForEach-Object { $_.Dispose() }
        }
    }
}
