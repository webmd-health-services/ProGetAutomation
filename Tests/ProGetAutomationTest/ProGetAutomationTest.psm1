
$repoRoot = Join-Path -Path $PSScriptRoot -ChildPath '../..' -Resolve
$apiKeyFilePath = Join-Path -Path $repoRoot -ChildPath 'test_api_key.txt' -Resolve
$apiKey = Get-Content -Path $apiKeyFilePath -Raw
$credential = New-Object 'pscredential' ('Admin',(ConvertTo-SecureString 'Admin' -AsPlainText -Force))
[uri] $uri = 'http://localhost:8624/'

try
{
    Invoke-WebRequest -Uri $uri | Write-Debug
}
catch
{
    $msg = 'It looks like ProGet isn''t installed. Please run init.ps1 to install and configure a local ProGet ' +
           'instance so we can run automated tests against it.'
    Write-Error -Message $msg -ErrorAction 'Stop'
}

function New-ProGetTestSession
{
    [CmdletBinding()]
    param(
        [switch] $ExcludeCredential,

        [switch] $ExcludeApiKey
    )

    $authArgs = @{
        Credential = $credential;
        ApiKey = $apiKey;
    }

    if ($ExcludeCredential)
    {
        $authArgs.Remove('Credential')
    }

    if ($ExcludeApiKey)
    {
        $authArgs.Remove('ApiKey')
    }

    return New-ProGetSession -Url $uri @authArgs
}

function Assert-ProGetActivated
{
    [CmdletBinding()]
    param(
    )

    # Activate ProGet. Otherwise, it takes ProGet 30 minutes to activate itself.
    $loginUri = [Uri]::New($uri,'/log-in')
    $result = Invoke-WebRequest -Uri $loginUri -SessionVariable 'activationWebSession' -UseBasicParsing

    $body = [Text.StringBuilder]::New()

    foreach( $field in $result.InputFields )
    {
        $body.Append($field.name)
        $body.Append('=')
        if( $field | Get-Member 'value' )
        {
            $body.Append([uri]::EscapeDataString($field.value))
        }
        else
        {
            # Default initial credentials are Admin/Admin'.
            $body.Append('Admin')
        }
        $body.Append('&')
    }

    if( $result.rawcontent -match 'id="proget-login-button" name="([^"]+)"' )
    {
        $body.Append('__AhTrigger=')
        $body.Append([uri]::EscapeDataString($Matches[1]))
        $body.Append('&__AhEvent=click')
    }

    Write-Debug $body.ToSTring()

    Invoke-WebRequest -Method Post -Uri $loginUri -Body $body.ToString() -WebSession $activationWebSession
    try
    {
        $activateUri = New-Object 'Uri' $uri,'/administration/licensing/activate'
        Invoke-WebRequest -Uri $activateUri -WebSession $activationWebSession

        $tasksUri = [Uri]::New($uri, '/administration/security/tasks')
        $result = Invoke-WebRequest -Uri $tasksUri -WebSession $activationWebSession

        # Now, disable Anonymous admin access, if it's enabled (i.e. the "Remove Anonymous Access" button is on the page).
        if( $result.RawContent -match 'onclick="[^"]+privilegeId&quot;:(\d+)[^"]+" data-url="([^"]+/RemovePrivilege)"[^>]*>*\bRemove Anonymous Access\b.*<' )
        {
            $antiCsrfInput = $result.InputFields | Where-Object 'name' -EQ 'AHAntiCsrfToken'
            $headers = @{ $antiCsrfInput.name = $antiCsrfInput.value }
            $disableUri = [Uri]::New($uri, $Matches[2])
            $body = "privilegeId=$($Matches[1])"
            Invoke-WebRequest -Uri $disableUri -Method 'Post' -Body $body -Headers $headers -WebSession $activationWebSession
        }
    }
    finally
    {
        Invoke-WebRequest -Uri ([Uri]::New($uri, '/log-out')) -WebSession $activationWebSession
    }

    # ProGet does not respond correctly to Native API calls upon installation. Initial calls are instead returned the
    # complete HTML of the ProGet login screen. This code ensures that ProGet is awake and functioning correctly for unit
    # testing during the build process and future API calls
    $ProGetSession = New-ProGetTestSession
    $maxWakeAttempts = 1800
    $numAttempts = 0
    $pauseDuration = 1
    $readyToGo = $false
    do
    {
        if( $numAttempts -gt 0 )
        {
            $msg = 'Making attempt {0,3} to see if ProGet is activated.' -f $numAttempts
            Write-Information -Message $msg -InformationAction 'Continue'
        }

        New-ProGetFeed -Session $ProGetSession -Name 'IsProGetActive' -Type 'Universal' -ErrorAction Ignore
        Invoke-WebRequest -UseBasicParsing -Uri (New-Object 'Uri' ($uri,'/log-in?ReturnUrl=%2F')) -ErrorAction Ignore | Out-Null
        $feed = Get-ProGetFeed -Session $ProgetSession -Name 'IsProGetActive'
        if( $feed -and ($feed | Select-Object -First 1 | Get-Member -Name 'name') )
        {
            $readyToGo = $true
            break
        }

        Start-Sleep -Seconds $pauseDuration
    }
    while(($numAttempts++ -lt $maxWakeAttempts))

    if( -not $readyToGo )
    {
        throw 'The ProGet Native API is not responding. Testing cannot begin until ProGet is accepting API calls'
    }
}

Export-ModuleMember -Function '*'
