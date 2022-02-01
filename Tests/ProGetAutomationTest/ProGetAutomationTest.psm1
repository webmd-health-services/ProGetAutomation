
$apiKey = 'HKgaAKWjjgB9YRrTbTpHzw=='
$credential = New-Object 'pscredential' ('Admin',(ConvertTo-SecureString 'Admin' -AsPlainText -Force))

$pgNotInstalledMsg = 'It looks like ProGet isn''t installed. Please run init.ps1 to install and configure a local ProGet instance so we can run automated tests against it.'
$svcRoot =
    Get-ItemProperty -Path 'hklm:\SOFTWARE\Inedo\ProGet' -Name 'ServicePath' -ErrorAction Ignore |
    Select-Object -ExpandProperty 'ServicePath'
if( -not $svcRoot )
{
    # If ProGet is installed with the Inedo Hub, there won't be any registry key.
    $svc = Get-CimInstance -ClassName 'Win32_Service' -Filter 'Name="INEDOPROGETSVC"'
    if( -not $svc )
    {
        throw $pgNotInstalledMsg
    }

    $svcRoot = $svc.PathName
    if( $svcRoot -match '"([^"]+)"' )
    {
        $svcRoot = $Matches[1]
        do
        {
            $svcRoot = $svcRoot | Split-Path -Parent
        }
        while( $svcRoot -and -not (Test-Path -Path $svcRoot -PathType Container) )
    }
}

if( -not $svcRoot )
{
    throw $pgNotInstalledMsg
}

[uri]$uri = ('http://{0}:8624/' -f [Environment]::MachineName)

$configFiles = & {
                    Join-Path -Path $svcRoot -ChildPath 'ProGet.Service.exe.config'
                    Join-Path -Path $svcRoot -ChildPath 'App_appsettings.config'
                    Join-Path -Path $env:ProgramData -ChildPath 'Inedo\SharedConfig\ProGet.config'
                } | 
                Where-Object { Test-Path -Path $_ -PathType Leaf }

foreach( $configPath in $configFiles )
{
    $configContent = Get-Content -Raw -Path $configPath 
    $configContent | Write-Debug
    $svcConfig = [xml]$configContent
    if( -not $svcConfig )
    {
        throw $pgNotInstalledMsg
    }

    $connString = $svcConfig.SelectSingleNode("//add[@key = 'InedoLib.DbConnectionString']").Value
    if( $connString )
    {
        break
    }


    $connString = $svcConfig.SelectSingleNode("//ConnectionString").InnerText
    if( $connString )
    {
        break
    }
}

if( -not $connString )
{
    Write-Error -Message ('It looks like ProGet isn''t installed. We can''t find its connection string.') -ErrorAction Stop
}

Write-Debug -Message $connString

$conn = New-Object 'Data.SqlClient.SqlConnection'
$conn.ConnectionString = $connString
$conn.Open()

try
{
    $cmd = New-Object 'Data.SqlClient.SqlCommand'
    $cmd.Connection = $conn
    $cmd.CommandText = '[dbo].[ApiKeys_GetApiKeyByName]'
    $cmd.CommandType = [Data.CommandType]::StoredProcedure
    $cmd.Parameters.AddWithValue('@ApiKey_Text', $apiKey)

    $keyExists = $cmd.ExecuteScalar()
    if( -not $keyExists )
    {
        $apiKeyDescription = 'ProGetAutomation API Key'
        $apiKeyConfig = @'
<Inedo.ProGet.ApiKeys.ApiKey Assembly="ProGetCoreEx">
  <Properties AllowNativeApi="True" AllowPackagePromotionApi="False" />
</Inedo.ProGet.ApiKeys.ApiKey>
'@
        $cmd.Dispose()

        $cmd = New-Object 'Data.SqlClient.SqlCommand'
        $cmd.CommandText = "[dbo].[ApiKeys_CreateOrUpdateApiKey]"
        $cmd.Connection = $conn
        $cmd.CommandType = [Data.CommandType]::StoredProcedure

        $parameters = @{
                            '@ApiKey_Text' = $apiKey;
                            '@ApiKey_Description' = $apiKeyDescription;
                            '@ApiKey_Configuration' = $apiKeyConfig
                        }
        foreach( $name in $parameters.Keys )
        {
            $value = $parameters[$name]
            if( -not $name.StartsWith( '@' ) )
            {
                $name = '@{0}' -f $name
            }
            Write-Verbose ('{0} = {1}' -f $name,$value)
            [void] $cmd.Parameters.AddWithValue( $name, $value )
        }
        [Void]$cmd.ExecuteNonQuery();
    }
}
finally
{
    $conn.Close()
}

function New-ProGetTestSession
{
    return New-ProGetSession -Uri $uri -Credential $credential -ApiKey $apiKey
}

Remove-Variable -Name 'activationWebSession' -ErrorAction Ignore
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

    New-ProGetFeed -Session $ProGetSession -Name 'ProGetAutomationTest' -Type 'Universal' -ErrorAction Ignore
    Invoke-WebRequest -UseBasicParsing -Uri (New-Object 'Uri' ($uri,'/log-in?ReturnUrl=%2F')) -ErrorAction Ignore | Out-Null
    $feed = Get-ProGetFeed -Session $ProgetSession -Force
    if( $feed -and ($feed | Select-Object -First 1 | Get-Member -Name 'Feed_Id') )
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

Export-ModuleMember -Function '*'
