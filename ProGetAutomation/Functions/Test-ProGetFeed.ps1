
function Test-ProGetFeed
{
    <#
    .SYNOPSIS
    Checks if a feed exists in a ProGet instance.

    .DESCRIPTION
    The `Test-ProGetFeed` function tests if a feed exists in ProGet instance. Pass the session to your ProGet instance
    to the `Session` parameter (use `New-ProGetSession` to create a session).  Pass the name of the feed to the `Name`
    parameter. Pass the type of the feed to the `Type` parameter. If the feed exists, the function returns `true`.
    Otherwise, it returns `false`.

    Uses the `Feeds_GetFeed` endpoint in ProGet's native API.

    .EXAMPLE
    Test-ProGetFeed -Session $ProGetSession -Name 'Apps' -Type 'ProGet'

    Demonstrates how to call `Test-ProGetFeed`. In this case, a value of `$true` will be returned if a Universal package
     feed named 'Apps' exists. Otherwise, `$false`
    #>
    [CmdletBinding()]
    param(
        # The session includes ProGet's URI and the API key. Use `New-ProGetSession` to create session objects
        [Parameter(Mandatory)]
        [pscustomobject] $Session,

        # The feed name indicates the name of the package feed that will be created.
        [Parameter(Mandatory)]
        [Alias('FeedName')]
        [String] $Name
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $feed = Get-ProGetFeed -Session $Session -Name $Name -ErrorAction Ignore
    return $null -ne $feed
}
