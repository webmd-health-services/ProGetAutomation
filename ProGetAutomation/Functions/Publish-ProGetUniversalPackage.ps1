
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

        # The timeout (in seconds) for the upload. The default is 100 seconds.
        [int] $Timeout = 100,

        # Replace the package if it already exists in ProGet.
        [switch] $Force
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

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

    $maxDuration = [TimeSpan]::New(0, 0, $Timeout)

    [HttpClientHandler]$httpClientHandler = $null
    [HttpClient]$httpClient = $null
    [FileStream]$packageStream = $null
    [StreamContent]$streamContent = $null
    [Task[HttpResponseMessage]]$httpResponseMessage = $null
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
        $httpClient.Timeout = $maxDuration
        if ($pgApiKey)
        {
            $httpClient.DefaultRequestHeaders.Add('X-ApiKey', $pgApiKey)
        }

        $packageStream = [FileStream]::New($PackagePath, 'Open', 'Read')
        $streamContent = [StreamContent]::New([Stream]$packageStream)
        $streamContent.Headers.ContentType = [MediaTypeHeaderValue]::New('application/octet-stream')
        $canceller = [CancellationTokenSource]::New()
        $httpResponseMessage =
            $httpClient.PutAsync($pgPackageUploadUrl, [HttpContent]$streamContent, $canceller.Token)
        if( -not $httpResponseMessage.Wait($maxDuration) )
        {
            $canceller.Cancel()
            $maxTries = 1000
            $tryNum = 0
            while( $tryNum -lt $maxTries -and -not $httpResponseMessage.IsCanceled )
            {
                $tryNum += 1
                Start-Sleep -Milliseconds 100
            }
            Write-Error -Message ('Uploading file ''{0}'' to ''{1}'' timed out after {2} second(s). To increase this timeout, set the Timeout parameter to the number of seconds to wait for the upload to complete.' -f $PackagePath,$pgPackageUploadUrl,$Timeout)
            return
        }

        $response = $httpResponseMessage.Result
        if( -not $response.IsSuccessStatusCode )
        {
            Write-Error -Message ('Failed to upload ''{0}'' to ''{1}''. We received the following ''{2} {3}'' response:{4} {4}{5}{4} {4}' -f $PackagePath,$pgPackageUploadUrl,[int]$response.StatusCode,$response.StatusCode,[Environment]::NewLine,$response.Content.ReadAsStringAsync().Result)
            return
        }
    }
    catch
    {
        $ex = $_.Exception
        while( $ex.InnerException )
        {
            $ex = $ex.InnerException
        }

        if( $ex -is [TaskCanceledException] )
        {
            Write-Error -Message ('Uploading file ''{0}'' to ''{1}'' was cancelled. This is usually because the upload took longer than the timeout, which was {2} second(s). Use the Timeout parameter to increase the upload timeout.' -f $PackagePath,$pgPackageUploadUrl,$Timeout)
            return
        }

        Write-Error -Message ('An unknown error occurred uploading ''{0}'' to ''{1}'': {2}' -f $PackagePath,$pgPackageUploadUrl,$_)
        return
    }
    finally
    {
        $disposables = @(
            'httpClientHandler',
            'httpClient',
            'canceller',
            'packageStream',
            'streamContent',
            'httpResponseMessage',
            'response'
        )

        $disposables |
            ForEach-Object { Get-Variable -Name $_ -ValueOnly -ErrorAction Ignore } |
            Where-Object { $_ -ne $null } |
            ForEach-Object { $_.Dispose() }
        $disposables | ForEach-Object { Remove-Variable -Name $_ -Force -ErrorAction Ignore }
    }
}
