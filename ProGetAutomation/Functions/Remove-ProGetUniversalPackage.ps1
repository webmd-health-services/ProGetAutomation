
function Remove-ProGetUniversalPackage 
{
    <#
    .SYNOPSIS
    Removes a package from a ProGet universal feed.

    .DESCRIPTION
    The `Remove-ProGetUniversalPackage` function removes a package from a ProGet universal feed. Pass the session to the ProGet instance from which the package should get deleted to the `Session` parmeter (use `New-ProGetSession` to create a session). Pass the feed from which the package should get deleted to the `FeedName` parameter. Pass the name of the package to the `Name` parameter. Pass the package version to delete to the `Version` parameter. If the package is in a group, pass the group name to the `GroupName` parameter.

    If the package doesn't exist, you'll get an error.

    This function uses ProGet's [universal feed API](https://inedo.com/support/documentation/upack/feed-api/endpoints).

    .EXAMPLE
    Remove-ProGetUniversalPackage -Session $session -FeeName 'PowerShell' -Name 'ProGetAutomation' -Version '0.7.0'

    Demonstrates how to delete a specific package version. In this case, package `ProGetAutomation` version `0.7.0` is deleted from the `PowerShell` feed.

    .EXAMPLE
    Remove-ProGetUniversalPackage -Session $session -FeeName 'PowerShell' -Name 'ProGetAutomation' -Version '0.7.0' -GroupName 'Modules'

    Demonstrates how to delete a specific package version when a package is in a group. In this case, package `ProGetAutomation` version `0.7.0` in the `Modules` group is deleted from the `PowerShell` feed.    
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object]
        # A session to the ProGet instance from which the package should get deleted. Use `New-ProGetSession` to create a session.
        $Session,

        [Parameter(Mandatory)]
        [string]
        # The name of the feed from which the package should be deleted.
        $FeedName,

        [Parameter(Mandatory)]
        [string]
        # The name of the package to delete.
        $Name,

        [Parameter(Mandatory)]
        [string]
        # The specific package version to delete.
        $Version,

        [string]
        # The package's group.
        $GroupName
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $groupStem = ''
    if( $GroupName )
    {
        $groupStem = '{0}/' -f [uri]::EscapeDataString($GroupName)
    }

    $path = '/upack/{0}/delete/{1}{2}/{3}' -f [uri]::EscapeDataString($FeedName),$groupStem,[uri]::EscapeDataString($Name),[uri]::EscapeDataString($Version)
    Invoke-ProGetRestMethod -Session $Session -Path $path -Method Delete

}
