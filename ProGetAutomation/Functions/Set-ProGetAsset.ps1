function Set-ProGetAsset
{
    <#
        .SYNOPSIS
        Adds and updates assets to the ProGet asset manager. 

        .DESCRIPTION
        The `Set-ProGetAsset` adds assets to ProGet A session, assetName, assetDirectory and Path is required. 
        A root directory needs to be created in ProGet using the `New-ProGetFeed` function with Type `Asset`.
        
        The Name parameter is the name you wish the asset to be named in ProGet. 
        The Directory parameter is the directory you wish the asset to be located in.
        The Path parameter is the path to the file located on your machine. 

        .EXAMPLE
        Set-ProGetAsset -Session $session -Name 'exampleAsset' -Directory 'versions' -Path 'path/to/file.txt'

        Example of adding an asset to ProGet if versions is not created it will throw an error.
        
        .EXAMPLE
        Set-ProGetAsset -Session $session -Name 'exampleAsset' -Directory 'versions/subfolder' -Path 'path/to/file.txt'

        Example of adding an asset to ProGet if subfolder are not created it will create the directory, but not the versions directory.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,
        
        [Parameter(Mandatory = $true)]
        [string]
        # The name of a valid path to the directory to upload the desired asset in ProGet. If no root directories exist, use the `New-ProGetFeed` with parameter `-Type 'Asset'` to create a new directory in the ProGet assets page. Any subdirectories will be created automatically.
        $Directory,        
        
        [Parameter(Mandatory = $true)]
        [string]
        # Desired name of the asset that will be uploaded.
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        # The Relative Path of the file to be uploaded. 
        $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    $topDirectory = (($Directory -split '\\') -split '/')[0] 
    if($topDirectory.Length -ne $Directory.Length)
    {
        $Name = Join-Path -Path $Directory.Substring($topDirectory.Length+1) -ChildPath $Name
    }
    $feedExists = Test-ProGetFeed -Session $session -FeedName $topDirectory -FeedType 'Asset'
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
        Invoke-ProGetRestMethod -Session $Session -Path ('/endpoints/{0}/content/{1}' -f $topDirectory, $Name) -Method Post -Infile $Path
    }
    catch
    {
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}
