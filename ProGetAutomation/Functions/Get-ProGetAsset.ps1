function Get-ProGetAsset
{
    <#
        .SYNOPSIS
        Gets metadata about items in an asset directory.

        .DESCRIPTION
        The `Get-ProGetAsset` function gets metadata from ProGet about assets. Pass the path to an asset directory to the `Directory` parameter. Information about all the files in that asset directory is returned. If the URL to an asset directory in ProGet is `https://proget.example.com/assets/versions/subdirectory/file`, the directory parameter is everything after `assets/` but before the filename `/file`, or `versions/subdirectory`.

        If you also pass a value to the `$Name` parameter, only files that match `$Name` in the directory will be returned. Wildcards are supported.

        Pass a ProGet session object to the `$Session` parameter. This object controls what instance of ProGet to use and what credentials and/or API keys to use. Use the `New-ProGetSession` function to create session objects.

        ##Examples

        #Example 1
        Get-ProGetAsset -Session $session -Name 'myAsset' -Directory 'versions'
        
        Demonstrates how to get metadata about an asset. In this case, information about the `/assets/versions/myAsset` file is returned.

        #Example 2
        Get-ProGetAsset -Session $session -Directory 'versions/subdirectory'
        
        Demonstrates how to get metadata from all files in the `versions/subdirectory` asset directory. If no files found an empty list is returned.

    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        # The name of a valid path to the directory to get metadata of the desired assets in ProGet. 
        $Directory,        

        [string]
        # Name of the asset in the ProGet assets directory that will be retrieved. only file metadata that match `$Name` in the directory will be returned. Wildcards are supported.
        $Name
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    $topDirectory = (($Directory -split '\\') -split '/')[0]
    $subdirectory = ''
    if($topDirectory.Length -ne $Directory.Length)
    {
        $subdirectory = $Directory.Substring($topDirectory.Length+1)
    }
    $path = '/endpoints/{0}/dir/{1}' -f $topDirectory,$subdirectory


    if(!$Name)
    {
        $Name = '*'
    }
    try
    {
        return Invoke-ProGetRestMethod -Session $Session -Path $path -Method Get | Where-Object { $_.Name -like $name }
    }
    catch
    {
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}
