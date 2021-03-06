
$apiKey = 'HKgaAKWjjgB9YRrTbTpHzw=='
$credential = New-Object 'pscredential' ('Admin',(ConvertTo-SecureString 'Admin' -AsPlainText -Force))

$pgNotInstalledMsg = 'It looks like ProGet isn''t installed. Please run init.ps1 to install and configure a local ProGet instance so we can run automated tests against it.'
$svcRoot = Get-ItemProperty -Path 'hklm:\SOFTWARE\Inedo\ProGet' -Name 'ServicePath' | Select-Object -ExpandProperty 'ServicePath'
if( -not $svcRoot )
{
    throw $pgNotInstalledMsg
}

$uri = ('http://{0}:8624/' -f [Environment]::MachineName)

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

# Activate ProGet. Otherwise, it takes ProGet 30 minutes to activate itself.
$loginUri = New-Object 'Uri' $uri,'/log-in'
Invoke-WebRequest -Uri $loginUri -SessionVariable 'progetSession'

$loginBody = '.ASPXAUTH=uninclused&ah0%7Eah0%7Eah0%7Eah3%7Eah1%7Eah1=Admin&ah0%7Eah0%7Eah0%7Eah3%7Eah2%7Eah1=Admin&ah0%7Eah0%7Eah0%7Eah3%7Eah3%7Eah0=click&__AhTrigger=null'
Invoke-WebRequest -Method Post -Uri $loginUri -Body $loginBody -WebSession $progetSession
$activateUri = New-Object 'Uri' $uri,'/administration/licensing/activate'
Invoke-WebRequest -Uri $activateUri -WebSession $progetSession

# ProGet does not respond correctly to Native API calls upon installation. Initial calls are instead returned the complete HTML of the ProGet login screen.
# This code ensures that ProGet is awake and functioning correctly for unit testing during the build process and future API calls
$ProGetSession = New-ProGetTestSession
$maxWakeAttempts = 1800
$numAttempts = 0
$pauseDuration = 1
$readyToGo = $false
do
{
    Write-Verbose -Message ('Making attempt {0,3} to see if ProGet is activated.' -f $numAttempts) -Verbose

    New-ProGetFeed -Session $ProGetSession -Name 'ProGetAutomationTest' -Type 'ProGet' -ErrorAction Ignore
    Invoke-WebRequest -UseBasicParsing -Uri (New-Object 'Uri' ($uri,'/log-in?ReturnUrl=%2F')) -ErrorAction Ignore | Out-Null
    $feed = Get-ProGetFeed -Session $progetSession -Force
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
