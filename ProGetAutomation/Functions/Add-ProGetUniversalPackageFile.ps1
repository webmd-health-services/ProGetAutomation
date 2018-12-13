
function Add-ProGetUniversalPackageFile
{
    <#
    .SYNOPSIS
    Adds files to a ProGet universal package.

    .DESCRIPTION
    The `Add-ProGetUniversalPackageFile` function adds files to a upack file (use `New-ProGetUniversalPackage` to create a upack file). All files are added under the `package` directory in the package, per the upack specification.

    Pass the path to the upack file to the `PackagePath` parameter. Pipe file/directory objects to add to the package to the function. Pass the base path of the files to the `BasePath` parameter. The value of the base path parameter is removed from the file/directory paths when they are added to the package.

    If you want a file/directory to have a custom parent path in the upack file, pass that parent path to the `PackageParentPath` parameter.

    You can control the compression level of items added to the upack file with the `CompressionLevel` parameter. The default level is `Optimal`. Other compression levels are `Fastest` (larger file, compressed faster) or `None` (no compression).

    The upack file can't contain duplicate files. If you try to add a duplicate file, you'll get an error. To overwrite existing files, use the `-Force` switch.

    This function uses the `Zip` module's `Add-ProGetUniversalPackageFile` function to add files to the upack file.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\ProGetAutomation' -File | Add-ProGetUniversalPackageFile -PackagePath 'ProGetAutomation.upack' -BasePath 'C:\Projects\ProGetAutomation'

    Demonstrates how to add files to a upack file. In this case, files will *not* start with `Projects\ProGetAutomation`. `Add-ProGetUniversalPackageFile` removes the `BasePath` from the start of each file's path when determining its path in the upack file. All the files under `C:\Projects\ProGetAutomation' will be added to the `package` directory in the package.

    .EXAMPLE
    Add-ProGetUniversalPackageFile -PackagePath 'ProGetAutomation.upack' -InputObject 'ProGetAutomation' -BasePath (Get-Location).Path

    Demonstrates how to pass a path to add that directory/file to a upack file. In this example, the contents of the `ProGetAutomation` directory in the current directory will be added to the upack file.

    .EXAMPLE
    Get-Item -Path '.\ProGetAutomation' | Add-ProGetUniversalPackageFile -PackagePath 'ProGetAutomation.upack' -BasePath (Get-Location).Path -PackageParentPath 'ModuleRoot'

    Demonstrates how to customize the directory in the package files will be added to. In this case, all the files under the `ProGetAutomation` directory will be put in a `package\ModuleRoot` directory in the package.
    #>
    [CmdletBinding()]
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
        # If you pass a directory object or path to a directory, all files in that directory and all its sub-directories will be added to the upack file.
        #
        # All files are added to the `packages` directory in the upack file.
        $InputObject,

        [Parameter(Mandatory)]
        [string]
        # The `BasePath` parameter controls what portion of the source file's path is removed when determining its name in the upack archive.
        $BasePath,

        [string]
        # A parent path to add to each file in the upack file. Use this to put files/directories into specific places in the package.
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

        $parentPath = 'package'
        if( $PackageParentPath )
        {
            $parentPath = Join-Path -Path $parentPath -ChildPath $PackageParentPath
        }
    }

    process
    {
        $InputObject | Add-ProGetUniversalPackageFile -PackagePath $PackagePath -BasePath $BasePath -CompressionLevel $CompressionLevel -EntryParentPath $parentPath -Force:$Force
    }
}