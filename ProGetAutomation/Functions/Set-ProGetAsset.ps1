function Set-ProGetAsset
{
    <#
    .SYNOPSIS
    Adds and updates assets to the ProGet asset manager. 

    .DESCRIPTION
    The `Set-ProGetAsset` adds assets to a ProGet session. A DirectoryName and Path are required. Either a FilePath or Body must be provided.

    A root directory needs to be created in ProGet using the `New-ProGetFeed` function with Type `Asset`.
        
    * DirectoryName - the root asset directory where the asset is currently located or will be created.
    * Path - the filepath, relative to the root asset directory, where the asset is currently located or will be created.
    * FilePath - the filepath, relative to the current working directory, of the file that will be published as an asset.
    * Value - the content that will be published as an asset.

    .EXAMPLE
    Set-ProGetAsset -Session $session -DirectoryName 'assetDirectory'-Path 'subdir/exampleAsset.txt' -FilePath 'path/to/file.txt'

    Example of publishing a file located at `path/to/file.txt` to ProGet in the `assetDirectory/subdir` folder. If `assetDirectory` is not created it will throw an error. If subdir is not created it will create the folder.
        
    .EXAMPLE
    Set-ProGetAsset -Session $session -Directory 'assetDirectory' -Path 'exampleAsset.txt' -Value $bodyContent

    Example of publishing content contained in the $bodyContent variable to ProGet in the `assetDirectory` folder.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        # The name of a valid root asset directory in ProGet. If no root directories exist, use the `New-ProGetFeed` with parameter `-Type 'Asset'` to create a new asset directory.
        $DirectoryName,

        [Parameter(Mandatory = $true)]
        [string]
        # The path where the asset will be published. Any directories that do not exist will be created automatically.
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByFile')]
        [string]
        # The relative path of a file to be published as an asset.
        $FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByContent')]
        [string]
        # The content to be published as an asset.
        $Content
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $contentParam = @{ }
    switch( $PSCmdlet.ParameterSetName )
    {
        'ByFile' {
            if( !(Test-Path -Path $FilePath) )
            {
                Write-Error ('Could not find file named ''{0}''. Please pass in a valid file path.' -f $FilePath)
                return
            }

            $contentParam['Infile'] = $FilePath
        }
        'ByContent' {
            $contentParam['Body'] = $Content
        }
    }

    Invoke-ProGetRestMethod -Session $Session -Path ('/endpoints/{0}/content/{1}' -f $DirectoryName, $Path) -Method Post @contentParam
}
