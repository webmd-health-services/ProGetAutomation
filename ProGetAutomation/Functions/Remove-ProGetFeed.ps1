
function Remove-ProGetFeed
{
    <#
    .SYNOPSIS
    Removes a feed from ProGet.

    .DESCRIPTION
    The `Remove-ProGetFeed` function removes a feed from ProGet. Pass the session to the ProGet instance from which to delete the feed to the `Session` parameter (use the `New-ProGetSession` function to create a session. Pass the ID of the feed to the `ID` parameter. You can also pipe feed IDs or feed objects returned by `Get-ProGetFeed`.

    This function uses the `Feeds_DeleteFeed` endpoint in [ProGet's native API](https://inedo.com/support/documentation/proget/reference/api/native).

    .EXAMPLE
    Remove-ProGetFeed -Session $session -ID 4398

    Demonstrates how to delete a feed by passing its ID to the `ID` parameter.

    .EXAMPLE
    $feed | Remove-ProGetFeed -Session $session

    Demonstrates that you can pipe feed objects to `Remove-ProGetFeed` to remove those feeds. Use `Get-ProGetFeed` to get a feed objects.

    .EXAMPLE

    4398 | Remove-ProGetFeed -Session $session

    Demonstrates that you can pipe feed IDs to `Remove-ProGetFeed` to remove those feeds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]
        # The session to the ProGet instance to use.
        $Session,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('Feed_Id')]
        [int]
        # The ID of the feed to remove. You may pipe feed IDs as integers or feed objects returned by the `Get-ProGetFeed` function.
        $ID
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $parameter = @{
                        Feed_Id = $ID
                    }

        Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_DeleteFeed' -Parameter $parameter
    }
}
