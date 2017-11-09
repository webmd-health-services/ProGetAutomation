function Remove-ProGetAsset
{
    <#
        .SYNOPSIS
        Removes assets from ProGet. 

        .DESCRIPTION
        The `Remove-ProGetAsset` function removes assets from ProGet. The Directory parameter is the relative path from the root directory in ProGet to the asset. The `Name` parameter is the name of the asset located in the directory. If the file does not exist no error will be thrown 

        .EXAMPLE
        Remove-ProGetAsset -Session $session -Name 'myAssetName' -Directory 'versions'

        Removes asset if file is found in the 'versions' directory.

        .Example
        Remove-ProGetAsset -Session $session -Name 'myAssetName' -Directory 'versions/example/subexample'

        Removes asset if file is found in the directory path 'versions/example/subexample'.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        # The name of a valid path to the directory to Remove the desired asset in ProGet. 
        $Directory, 

        [Parameter(Mandatory = $true)]
        [string]
        # Name of the asset in the ProGet assets directory that will be removed. If the file is does not exist no error will be thrown.
        $Name
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    $topDirectory = (($Directory -split '\\') -split '/')[0] 
    if($topDirectory.Length -ne $Directory.Length)
    {
        $Name = Join-Path -Path $Directory.Substring($topDirectory.Length+1) -ChildPath $Name
    }
    $path = '/endpoints/{0}/content/{1}' -f $topDirectory,$Name

    try
    {
        Invoke-ProGetRestMethod -Session $Session -Path $path -Method Delete
    }
    catch
    {
        Write-Error ("ERROR: {0}" -f $Global:Error)
    }
}
