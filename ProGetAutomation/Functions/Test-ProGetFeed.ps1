
function Test-ProGetFeed
{
    <#
    .SYNOPSIS
    Checks if a feed exists in a ProGet instance.

    .DESCRIPTION
    The `Test-ProGetFeed` function tests if a feed exists in ProGet instance. Pass the session to your ProGet instance to the `Session` parameter (use `New-ProGetSession` to create a session).  Pass the name of the feed to the `Name` parameter. Pass the type of the feed to the `Type` parameter. If the feed exists, the function returns `true`. Otherwise, it returns `false`.
    
    Uses the `Feeds_GetFeed` endpoint in ProGet's native API.

    .EXAMPLE
    Test-ProGetFeed -Session $ProGetSession -Name 'Apps' -Type 'ProGet'

    Demonstrates how to call `Test-ProGetFeed`. In this case, a value of `$true` will be returned if a Universal package feed named 'Apps' exists. Otherwise, `$false`
    #>
    [CmdletBinding()]
    param(
        # The session includes ProGet's URI and the API key. Use `New-ProGetSession` to create session objects
        [Parameter(Mandatory)]
        [pscustomobject] $Session,

        # The feed name indicates the name of the package feed that will be created.
        [Parameter(Mandatory)]
        [Alias('FeedName')]
        [String] $Name,

        # The feed type indicates the type of package feed to create.
        # Valid feed types are ('VSIX', 'RubyGems', 'Docker', 'ProGet', 'Maven', 'Bower', 'npm', 'Deployment', 'Chocolatey', 'NuGet', 'PowerShell') - check here for a latest list - https://inedo.com/support/documentation/proget/feed-types/universal
        [Parameter(Mandatory)]
        [Alias('FeedType')]
        [String] $Type
    )

    Set-StrictMode -Version 'Latest'

    if( !$Session.ApiKey)
    {
        Write-Error -Message ('Failed to test for package feed ''{0}/{1}''. This function uses the ProGet Native API, which requires an API key. When you create a ProGet session with `New-ProGetSession`, provide an API key via the `ApiKey` parameter' -f $FeedType, $FeedName)
        return
    }

    if( $Type -eq 'ProGet' )
    {
        $msg = 'ProGet renamed its "ProGet" feed type name to "Universal". Please update the value of ' +
               'New-ProGetFeed''s "Type" parameter from "ProGet" to "Universal".'
        Write-Warning $msg
        $Type = 'Universal'
    }

    $Parameters = @{
                        'Feed_Name' = $Name;
                    }

    $feed = Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_GetFeed' -Parameter $Parameters
    return ($feed -and ($feed | Get-Member -Name 'FeedType_Name') -and $feed.FeedType_Name -eq $Type)
}
