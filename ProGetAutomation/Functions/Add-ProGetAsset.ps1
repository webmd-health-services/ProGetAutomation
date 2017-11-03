function Add-ProGetAsset
{
    <#
        .SYNOPSIS
        Used to add assets to the proget asset manager. 

        .DESCRIPTION
        This function adds assets to the proget asset manager. A session, asset name, assetDirectory and filePath is required. 
        The assetName parameter is the name you wish the asset to be named in proget. 
        The assetDirectory parameter is the directory you wish the asset to be located in.
        The FilePath parameter is the path to the file located on your machine. 

        .EXAMPLE
        # example of adding an asset to proGet Asset Manager if versions is not created it will create the directory.
        Add-ProGetAsset -Session $session -AssetName 'exampleAsset' -AssetDirectory 'versions' -FilePath 'path/to/file.txt'

        .EXAMPLE
        # example of adding an asset to proGet Asset Manager if versions or subfolder are not created it will create both directories.
        Add-ProGetAsset -Session $session -AssetName 'exampleAsset' -AssetDirectory 'versions/subfolder' -FilePath 'path/to/file.txt'

    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        $Session,
        
        [Parameter(Mandatory = $true)]
        [string]
        $AssetDirectory,        
        
        [Parameter(Mandatory = $true)]
        [string]
        $AssetName,

        [Parameter(Mandatory = $true)]
        [string]
        $FileName
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $feedExists = Test-ProGetFeed -Session $session -FeedName $AssetDirectory -FeedType 'Asset'
    if( !$feedExists )
    {
        New-ProGetFeed -Session $session -FeedName $AssetDirectory -FeedType 'Asset'
    }

    if( -not (Test-path -Path $FileName) )
    {
        Write-error ('Could Not find file named ''{0}''. please pass in the correct path value' -f $FileName)
    }
    try{
        Invoke-ProGetRestMethod -Session $Session -Path ('/endpoints/{0}/content/{1}' -f $AssetDirectory, $AssetName) -Method Post -Infile $FileName
    }
    catch{
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}
