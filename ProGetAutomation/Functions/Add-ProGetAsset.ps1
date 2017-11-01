function Add-ProGetAsset
{
    <#
        .SYNOPSIS
        Used to add assets to the proget asset manager. 

        .DESCRIPTION
        This function adds assets to the proget asset manager. A session, asset name and assetDirectory is required. optional parameters may be added via the 'parameter' parameter. 

        .EXAMPLE
        Add-ProGetAsset -Session $session -AssetName $progetAssetName -AssetDirectory 'Versions' -Parameter $Parameter

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
        $fileName
    )
    if( -not (Test-path -Path $FileName) )
    {
        Write-error ('Could Not find file named ''{0}''. please pass in the correct path value' -f $FileName)
    }
    try{
        Invoke-ProGetRestMethod -Session $Session -Path ('/endpoints/{0}/content/{1}' -f $AssetDirectory, $AssetName) -Method Post -infile $fileName
    }
    catch{
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}