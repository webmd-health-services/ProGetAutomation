
function Get-ProGetAssetContent
{
    <#
    .SYNOPSIS
    Gets the content of an asset in an asset directory.

    .DESCRIPTION
    The `Get-ProGetAssetContent` function gets an asset's content from ProGet. Pass the name of the root asset directory to the `DirectoryName` parameter. Pass the path to the asset to the `Path` parameter. If the URL to an asset directory in ProGet is `https://proget.example.com/assets/versions/subdirectory/file`, the directory parameter is the first directory after `assets/` (in this example `versions`). The `Path` parameter would be the rest of the url in this case `subdirectory/file`. 

    If an asset doesn't exist, an error will be written and nothing is returned.

    Pass a ProGet session object to the `$Session` parameter. This object controls what instance of ProGet to use and what credentials and/or API keys to use. Use the `New-ProGetSession` function to create session objects.

    .Example
    Get-ProGetAssetContent -Session $session -DirectoryName 'versions' -Path 'subdirectory/file.json'
        
    Demonstrates how to get the contents of an asset. In this case, the `subdirectory/file.json` asset's contents in the `versions` asset directory is returned.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        # The name of the asset's asset directory.
        $DirectoryName,        

        [string]
        # The path to the file in the asset directory, without the asset directory's name.
        $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $uri = '/endpoints/{0}/content/{1}' -f $DirectoryName,$Path

    return Invoke-ProGetRestMethod -Session $Session -Path $uri -Method Get -Raw
}
