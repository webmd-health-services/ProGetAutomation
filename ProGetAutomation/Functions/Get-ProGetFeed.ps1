
function Get-ProGetFeed
{
    <#
    .SYNOPSIS
    Determines whether the specified package feed exists in a Proget instance.

    .DESCRIPTION
    The `Get-ProGetFeed` function will return `$true` if the requested package feed already exists. The function utilizes ProGet's native API and uses the API key of a `ProGetSession` instead of the preferred PSCredential authentication.

    .EXAMPLE
    Get-ProGetFeed -ProGetSession $ProGetSession -FeedName 'Apps' -FeedType 'ProGet' (valid feed types include Bower, Chocolatey, NuGet, Docker, PowerShell, npm, etc. - check here for a full list - https://inedo.com/support/documentation/proget/feed-types/universal)

    Demonstrates how to call `Get-ProGetFeed`. In this case, a value of `$true` will be returned if a Universal package feed named 'Apps' exists. Otherwise, `$false`
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

    $feedExists = Invoke-PGNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeed' -Parameter $Parameters
    if($feedExists)
    {
        return $true
    }
    return $false
}