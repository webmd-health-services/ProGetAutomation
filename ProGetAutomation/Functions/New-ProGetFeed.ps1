
function New-ProGetFeed
{
    <#
    .SYNOPSIS
    Creates a new ProGet package feed in the specified Proget instance

    .DESCRIPTION
    The `New-ProGetFeed` function will create a new package feed of the specified type to the specified Proget instance. This function utilizes ProGet's native API and uses the API key of a `ProGetSession` instead of the preferred PSCredential authentication.

    .EXAMPLE
    New-ProGetFeed -ProGetSession $ProGetSession -FeedName 'Apps' -FeedType 'ProGet' (valid feed types include Bower, Chocolatey, NuGet, Docker, PowerShell, npm, etc. - check here for a full list - https://inedo.com/support/documentation/proget/feed-types/universal)

    Demonstrates how to call `New-ProGetFeed`. In this case, a new Universal package feed named 'Apps' will be created for the specified ProGet Uri
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [pscustomobject]
        # The session includes ProGet's URI and the API key. Use `New-ProGetSession` to create session objects
        $ProGetSession,

        [Parameter(Mandatory=$true)]
        [string]
        # The feed name indicates the name of the package feed that will be created.
        $FeedName,

        [Parameter(Mandatory=$true)]
        [string]
        # The feed type indicates the type of package feed to create.
        $FeedType
    )

    Set-StrictMode -Version 'Latest'

    $proGetPackageUri = [String]$ProGetSession.Uri
    if (!$ProGetSession.ApiKey)
    {
        throw ('Failed to create new package feed ''{0}/{1}''. ''ProGetSession'' parameter must contain a valid API key for this instance of ProGet.' -f $FeedType, $FeedName)
    }
    $proGetApiKey = $ProGetSession.ApiKey

    $Parameters = @{}
    $Parameters['FeedType_Name'] = $FeedType
    $Parameters['Feed_Name'] = $FeedName

    $feedExists = Get-ProGetFeed -ProGetSession $ProGetSession -FeedName $FeedName -FeedType $FeedType
    if($feedExists)
    {
        throw ('Failed to create new package feed ''{0}/{1}''. The feed name requested is in use and must be unique to this instance. Please try a different feed name.' -f $FeedType, $FeedName)
    }
    $null = Invoke-PGNativeApiMethod -Session $ProGetSession -Name 'Feeds_CreateFeed' -Parameter $Parameters

    Write-Verbose -Message ('Successfully created new package feed ''{0}/{1}'' in ProGet instance ''{2}' -f $FeedType, $FeedName, $proGetPackageUri)
}