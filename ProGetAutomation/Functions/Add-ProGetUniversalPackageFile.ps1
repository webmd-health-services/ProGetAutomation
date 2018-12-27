
function Add-ProGetUniversalPackageFile
{
    <#
    .SYNOPSIS
    Adds files and directories to a ProGet universal package.

    .DESCRIPTION
    The `Add-ProGetUniversalPackageFile` function adds files and directories to a upack file (use `New-ProGetUniversalPackage` to create a upack file). All items are added under the `package` directory in the package, per the upack specification.

    Files are added to the package using their names. They are always added to the `package` directory in the package. For example, if you added `C:\Projects\Zip\Zip\Zip.psd1` to the package, it would get added at `package\Zip.psd1`.
    
    Directories are added into a directory in the `package` directory. The directory in the package will use the name of the source directory. For example, if you add 'C:\Projects\Zip', all items will be added to the package at `package\Zip`.

    You can change the name an item will have in the package with the `PackageItemName` parameter. Path separators are allowed, so you can put any item into any directory in the package.

    If you don't want to add an entire directory to the package, but instead want a filtered set of files from that directory, pipe the filtered list of files to `Add-ProGetUniversalPackageFile` and use the `BasePath` parameter to specify the base path of the incoming files. `Add-ProGetUniversalPackageFile` removes the base path from each file and uses the remaining path as the file's name in the package.

    If you want to change an item's parent directory structure in the package, pass the parent path you want to the `PackageParentPath` parameter. For example, if you passed `tools` as the `PackageParentPath`, every item added will be put in a `package\tools` directory in the package.

    You can control the compression level of items getting added with the `CompressionLevel` parameter. The default is `Optimal`. Other options are `Fastest` (larger files, compresses faster) and `None`.

    This function uses the `Zip` PowerShell module, which uses the native .NET `System.IO.Compression` namespace/classes to do its work.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' | Add-ProGetUniversalPackageFile -PackagePath 'zip.upack'

    Demonstrates how to pipe the files you want to add to your package into `Add-ProGetUniversalPackageFile`. In this case, all the files and directories in the  `C:\Projects\Zip` directory are added to the package to the `package` directory.

    .EXAMPLE
    Get-ChildItem -Path 'C:\Projects\Zip' -Filter '*.ps1' -Recurse | Add-ProGetUniversalPackageFile -PackagePath 'zip.upack' -BasePath 'C:\Projects\Zip'

    This is like the previous example, but instead of adding every file under `C:\Projects\Zip`, we're only adding files with a `.ps1` extension. Since we're piping all the files to the `Add-ProGetUniversalPackageFile` function, we need to pass the base path of our search to the `BasePath` parameter. Otherwise, every file would get added to the `package` directory without preserving their directory structure. Instead, the `BasePath` is removed from every file's path and the remaining path is used as the item's path in the package.

    .EXAMPLE
    Get-Item -Path '.\Zip' | Add-ProGetUniversalPackageFile -PackagePath 'zip.upack' -PackageParentPath 'tools'

    Demonstrates how to customize the directory in the package files will be added at. In this case, the `.\Zip` directory will be put in a `package\tools` directory, e.g. `package\tools\Zip`.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' | Add-ProGetUniversalPackageFile -PackagePath 'zip.upack' -EntryName 'tools\ZipModule'

    Demonstrates how to change the name of an item. In this case, the `C:\Projects\Zip` directory will be added to the package with a path of `package\tools\ZipModule` instead of `package\Zip`.
    #>
    [CmdletBinding(DefaultParameterSetName='ItemName')]
    param(
        [Parameter(Mandatory)]
        [string]
        # The path to the upack file. The files will be added to this package.
        $PackagePath,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [Alias('Path')]
        [string]
        # The files/directories to add to the upack file. Normally, you would pipe file/directory objects to `Add-ProGetUniversalPackageFile`. You may also pass any object that has a `FullName` or `Path property. You may also pass the path as a string.
        #
        # If you pass a directory object or path to a directory, that directory and all its sub-directories will be added to the upack file.
        #
        # All files/directories are added to the `packages` directory in the upack file.
        $InputObject,

        [Parameter(ParameterSetName='BasePath')]
        [string]
        # When determining a file's path/name in the package, the value of this parameter is removed from the beginning of each file's path. Use this parameter if you are piping in a filtered list of files from a directory instead of the directory itself.
        $BasePath,

        [Parameter(ParameterSetName='ItemName')]
        [ValidatePattern('^[^\\/]')]
        [ValidatePattern('[^\\/]$')]
        [string]
        # By default, items are added to the package using their name. You can change the name with this parameter. For example, if you added file `Zip.psd1` and passed `NewZip.psd1` as the value to the parameter, the file would get added to the package as `NewZip.psd1`.
        $PackageItemName,

        [ValidatePattern('^[^\\/]')]
        [string]
        $PackageParentPath,

        [IO.Compression.CompressionLevel]
        # The compression level of the upack file. The default is `Optimal`. Pass `Fastest` to compress faster but have a larger file. Pass `None` to not compress at all.
        $CompressionLevel = [IO.Compression.CompressionLevel]::Optimal,

        [Switch]
        # By default, if a file already exists in the upack file, you'll get an error. Use this switch to replace any existing files.
        $Force
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Write-Debug -Message ('ProGetAutomation\Add-ProGetUniversalPackageFile BEGIN')

        $parentPath = 'package'
        if( $PackageParentPath )
        {
            $parentPath = Join-Path -Path $parentPath -ChildPath $PackageParentPath
        }

        $params = @{ }
        if( $BasePath )
        {
            $params['BasePath'] = $BasePath
        }

        if( $PackageItemName )
        {
            $params['EntryName'] = $PackageItemName
        }
        
        if( $Force )
        {
            $params['Force'] = $true
        }

        $items = New-Object 'Collections.Generic.List[string]'
    }

    process
    {
        $items.Add($InputObject)
    }
    
    end
    {
        $items | Add-ZipArchiveEntry -ZipArchivePath $PackagePath -EntryParentPath $parentPath -CompressionLevel $CompressionLevel @params
        Write-Debug -Message ('ProGetAutomation\Add-ProGetUniversalPackageFile END')
    }
}
