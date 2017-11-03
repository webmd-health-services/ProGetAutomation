function Get-ProGetAsset
{
    <#
        .SYNOPSIS
        Used to Get assets to the proget asset manager. 

        .DESCRIPTION
        This function gets assets to the proget asset manager. A session and assetDirectory is required. 
        An optional assetname may be added to get the content of the file. 
        If no asset name is added the function will return a list of all files in the asset directory

        .EXAMPLE
        # returns contents of assetName if file is found, otherwise returns 404
        Get-ProGetAsset -Session $session -AssetName $progetAssetName -AssetDirectory 'Versions'
        
        .Example
        # returns list of files in the assetDirectory
        Get-ProGetAsset -Session $session -AssetDirectory 'Versions'

    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        $AssetDirectory,        

        [string]
        $AssetName
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    if( $AssetName ){
        $path = '/endpoints/{0}/content/{1}' -f $AssetDirectory, $AssetName
    }
    else{
        $path = '/endpoints/{0}/dir' -f $AssetDirectory
    }
    try{
        return Invoke-ProGetRestMethod -Session $Session -Path $path -Method Get
    }
    catch{
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}