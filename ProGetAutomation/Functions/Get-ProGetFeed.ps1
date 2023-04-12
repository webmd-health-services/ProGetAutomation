
function Get-ProGetFeed
{
    <#
    .SYNOPSIS
    Gets the feeds in a ProGet instance.

    .DESCRIPTION
    The `Get-ProGetFeed` function gets all the feeds from a ProGet instance. Pass the session to the ProGet instance to
     the `Session` parameter. Use `New-ProGetSession` to create a session. By default, only active feeds are returned.
     Use the `-Force` switch to also return inactive feeds.

    To get a specific feed, pass its name to the `Name` parameter. If the feed by that name doesn't exist, nothing is
    returned and no errors are written.

    This function uses the [Feed Management API](https://docs.inedo.com/docs/proget-reference-api-feed-management).

    .EXAMPLE
    Get-ProGetFeed -Session $session

    Demonstrates how to get all the feeds in a ProGet instance.

    .EXAMPLE
    Get-ProGetFeed -Session $session -Name PowerShell

    Demonstrates how to get a specific feed. In this case, the `PowerShell` feed is returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Session,

        # By default, all feeds are returned. Use this parameter to return a specific feed using its name.
        [String] $Name
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $path = "/api/management/feeds/list"
    if ($Name)
    {
        $path = "/api/management/feeds/get/$([Uri]::EscapeDataString($Name))"
    }
    Invoke-ProGetRestMethod -Session $Session -Path $path | Add-PSTypeName -Feed
}
