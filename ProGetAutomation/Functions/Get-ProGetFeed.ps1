
function Get-ProGetFeed
{
    <#
    .SYNOPSIS
    Gets the feeds in a ProGet instance.

    .DESCRIPTION
    The `Get-ProGetFeed` function gets all the feeds from a ProGet instance. Pass the session to the ProGet instance to the `Session` parameter. Use `New-ProGetSession` to create a session. By default, only active feeds are returned. Use the `-Force` switch to also return inactive feeds.

    To get a specific feed, pass its name to the `Name` parameter. If the feed by that name doesn't exist, nothing is returned and no errors are written. 

    This function uses the `Feeds_GetFeed` and `Feeds_GetFeeds` endpoints in ProGet's [native API](https://inedo.com/support/documentation/proget/reference/api/native).

    .EXAMPLE
    Get-ProGetFeed -Session $session

    Demonstrates how to get all the feeds in a ProGet instance.

    .EXAMPLE
    Get-ProGetFeed -Session $session -Name PowerShell

    Demonstrates how to get a specific feed. In this case, the `PowerShell` feed is returned.
    #>
    [CmdletBinding(DefaultParameterSetName='AllFeeds')]
    param(
        [Parameter(Mandatory)]
        [object]
        $Session,

        [Parameter(Mandatory,ParameterSetName='SpecificFeed')]
        [string]
        # By default, all feeds are returned. Use this parameter to return a specific feed.
        $Name,

        [Parameter(ParameterSetName='AllFeeds')]
        [Switch]
        # By default, only active feeds are returned. Use this witch to return inactive feeds, too.
        $Force
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $parameter = @{ 
                    'IncludeInactive_Indicator' = $Force.IsPresent;
                 }

    $methodName = 'Feeds_GetFeeds'
    if( $Name )
    {
        $methodName = 'Feeds_GetFeed'
        $parameter = @{ 
                        'Feed_Name' = $Name ;
                    }
    }

    Invoke-ProGetNativeApiMethod -Session $Session -Name $methodName -Parameter $parameter |
        Where-Object { $_ } |
        Add-PSTypeName -NativeFeed
}
