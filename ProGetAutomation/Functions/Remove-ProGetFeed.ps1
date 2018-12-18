
function Remove-ProGetFeed
{
    <#
    .SYNOPSIS
    Removes a feed from ProGet.

    .DESCRIPTION
    The `Remove-ProGetFeed` function removes a feed from ProGet. All packages in the feed are also deleted. Pass the session to the ProGet instance from which to delete the feed to the `Session` parameter (use the `New-ProGetSession` function to create a session. Pass the ID of the feed to the `ID` parameter. You can also pipe feed IDs or feed objects returned by `Get-ProGetFeed`.

    Since this has the potential to be a disastrous operation (did we mention all the packages in the feed will also get deleted) and can't be undone, you'll be asked to confirm the deletion. If you don't want to be prompted, use the `-Force` switch. This is dangerous.

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
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)]
        [object]
        # The session to the ProGet instance to use.
        $Session,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('Feed_Id')]
        [int]
        # The ID of the feed to remove. You may pipe feed IDs as integers or feed objects returned by the `Get-ProGetFeed` function.
        $ID,

        [Switch]
        # Force the deletion of the feed without prompting for confirmation. This is dangerous. Deleting a feed deletes all its packages.
        $Force
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $feed = Get-ProGetFeed -Session $Session -ID $ID
        if( -not $feed )
        {
            return
        }

        $parameter = @{
                        Feed_Id = $ID
                    }

        $description = 'Are you sure you want to delete {0} feed "{1}" (ID: {2}) and all its packages? THIS ACTION CANNOT BE UNDONE.' -f $feed.FeedType_Name,$feed.Feed_Name,$ID
        if( $Force -or $PSCmdlet.ShouldProcess($description,$description,('Confirm Deletion of {0} Feed "{1}"' -f $feed.FeedType_Name,$feed.Feed_Name)) )
        {
            Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_DeleteFeed' -Parameter $parameter
        }
    }
}
