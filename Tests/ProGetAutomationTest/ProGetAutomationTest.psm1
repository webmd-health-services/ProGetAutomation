
$apiKey = 'HKgaAKWjjgB9YRrTbTpHzw=='
$credential = New-Credential -UserName 'Admin' -Password 'Admin'

$pgNotInstalledMsg = 'It looks like ProGet isn''t installed. Please run init.ps1 to install and configure a local ProGet instance so we can run automated tests against it.'
$svcRoot = Get-ItemProperty -Path 'hklm:\SOFTWARE\Inedo\ProGet' -Name 'ServicePath' | Select-Object -ExpandProperty 'ServicePath'
if( -not $svcRoot )
{
    throw $pgNotInstalledMsg
}

$svcConfig = [xml](Get-Content -Path (Join-Path -Path $svcRoot -ChildPath 'ProGet.Service.exe.config' -Resolve) -Raw)
if( -not $svcConfig )
{
    throw $pgNotInstalledMsg
}

$uri = ('http://{0}:82/' -f $env:COMPUTERNAME)
$connString = $svcConfig.SelectSingleNode("//add[@key = 'InedoLib.DbConnectionString']").Value
$connString

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
        $result = $cmd.ExecuteNonQuery();
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

# ProGet does not respond correctly to Native API calls upon installation. Initial calls are instead returned the complete HTML of the ProGet login screen.
# This code ensures that ProGet is awake and functioning correctly for unit testing during the build process and future API calls
$ProGetSession = New-ProGetTestSession
$maxWakeAttempts = 600
$numAttempts = 0
$pauseDuration = 1
$readyToGo = $false
do
{
    Write-Verbose -Message ('Making attempt {0,3} to see if ProGet is activated.' -f $numAttempts) -Verbose

    New-ProGetFeed -Session $ProGetSession -FeedName 'ProGetAutomationTest' -FeedType 'ProGet' -ErrorAction Ignore
    $feed = Invoke-ProGetNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeeds' -Parameter @{ IncludeInactive_Indicator = $true }
    if( $feed )
    {
        $readyToGo = $true
        break
    }

    Start-Sleep -Seconds $pauseDuration
    $numAttempts++
}
while(($numAttempts++ -lt $maxWakeAttempts))

if( -not $readyToGo )
{
    throw 'The ProGet Native API is not responding. Testing cannot begin until ProGet is accepting API calls'
}

Export-ModuleMember -Function '*'
