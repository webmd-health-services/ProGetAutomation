function Remove-ProGetAsset
{
    <#
        .SYNOPSIS
        Used to remove assets from the proget asset manager. 

        .DESCRIPTION
        This function removes assets from the proget asset manager. A session, assetName and assetDirectory is required. 

        .EXAMPLE
        # Removes assetName if file is found.
        Remove-ProGetAsset -Session $session -AssetName $progetAssetName -AssetDirectory 'Versions'

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
        $AssetName
    )
    $path = '/endpoints/{0}/content/{1}' -f $AssetDirectory, $AssetName
    try
    {
        Invoke-ProGetRestMethod -Session $Session -Path $path -Method Delete
    }
    catch
    {
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}