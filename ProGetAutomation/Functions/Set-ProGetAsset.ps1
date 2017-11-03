function Set-ProGetAsset
{
    <#
        .SYNOPSIS
        Adds and Updates assets to the ProGet asset manager. 

        .DESCRIPTION
        The `Set-ProGetAsset` adds assets to ProGet A session, assetName, assetDirectory and Path is required. 
        
        The assetName parameter is the name you wish the asset to be named in ProGet. 
        The assetDirectory parameter is the directory you wish the asset to be located in.
        The Path parameter is the path to the file located on your machine. 

        .EXAMPLE
        Set-ProGetAsset -Session $session -AssetName 'exampleAsset' -AssetDirectory 'versions' -Path 'path/to/file.txt'

        Example of adding an asset to ProGet Asset Manager if versions is not created it will create the directory.
        
        .EXAMPLE
        Set-ProGetAsset -Session $session -AssetName 'exampleAsset' -AssetDirectory 'versions/subfolder' -Path 'path/to/file.txt'

        Example of adding an asset to ProGet Asset Manager if versions or subfolder are not created it will create both directories.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        $Session,
        
        [Parameter(Mandatory = $true)]
        [string]
        $Directory,        
        
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $feedExists = Test-ProGetFeed -Session $session -FeedName $Directory -FeedType 'Asset'
    if( !$feedExists )
    {
        Write-Error('Asset Directory ''{0}'' does not exist, please create one using New-ProGetFeed with Name ''{0}'' and Type ''Asset''' -f $Directory)
    }

    if( -not (Test-path -Path $Path) )
    {
        Write-error ('Could Not find file named ''{0}''. please pass in the correct path value' -f $Path)
    }
    try
    {
        Invoke-ProGetRestMethod -Session $Session -Path ('/endpoints/{0}/content/{1}' -f $Directory, $Name) -Method Post -Infile $Path
    }
    catch
    {
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}
