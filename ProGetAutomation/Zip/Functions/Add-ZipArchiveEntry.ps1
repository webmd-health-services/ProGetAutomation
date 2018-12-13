
function Add-ZipArchiveEntry
{
    <#
    .SYNOPSIS
    Adds files to a ZIP archive.

    .DESCRIPTION
    The `Add-ZipArchiveEntry` function adds files to a ZIP archive. The archive must exist. Use the `New-ZipArchive` function to create a new ZIP file. Pipe file or directory objects that you want to add to the pipeline. You may also pass paths directly to the `InputObject` parameter. Relative paths are resolved from the current directory. If you pass a directory or path to a directory, the entire directory and all its sub-directories/files are added to the archive.
    
    Files are added to the ZIP archive using their full paths, minus the drive/qualifier. For example, if you add 'C:\Projects\Zip', all items will be added to the ZIP archive at `Projects\Zip`.

    You can change the base path `Add-ZipArchiveEntry` uses when adding items with the `BasePath` parameter. This parameter tells `Add-ZipArchiveEntry` the part of the source path to ignore/remove when adding it to the archive. For example, if you added an item at `C:\Projects\powershell-zip\Zip` with a `BasePath` of `C:\Projects\powershell-zip`, the item will be added to the archive at `Zip` (instead of `Projects\powershell-zip\Zip`).

    If you want to add the item to a custom parent directory in the archive, pass the parent path you want to the `EntryParentPath` parameter. For example, if you passed `package`, everything would be added in a `package` directory.

    You can control the compression level of items getting added with the `CompressionLevel` parameter. The default is `Optimal`. Other options are `Fastest` (larger files, compresses faster) and `None`.

    If your ZIP archive will be used by tools that don't support UTF8-encoded entry names, pass the encoding to use for entry names to the `EntryNameEncoding` parameter. The default is `UTF8`.

    This function uses the native .NET `System.IO.Compression` namespace/classes to do its work.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' -File | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip'

    Demonstrates how to pipe the files you want to add to your ZIP into `Add-ZipArchiveEntry`. In this case, all the files in the `C:\Projects\Zip` directory (but none of its sub-directories) will be added. Items in the ZIP file will begin with `Projects\Zip`.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' -File | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -BasePath 'C:\Projects\Zip'

    Demonstrates how to control the paths of files in the ZIP archive. In this case, files will *not* start with `Projects\Zip`. `Add-ZipArchiveEntry` removes the `BasePath` from the start of each file's path when determining its path in the ZIP file.

    .EXAMPLE
    Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -InputObject 'Zip' -BasePath (Get-Location).Path

    Demonstrates how to pass a path to add that directory/file to a ZIP file. In this example, the contents of the `Zip` directory in the current directory will be added to the ZIP file. Because the `BasePath` parameter is used, the files in the file will begin with `Zip` instead of the full path to the Zip directory.

    .EXAMPLE
    Get-Item -Path '.\Zip' | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -BasePath (Get-Location).Path -EntryParentPath 'package'

    Demonstrates how to customize the directory in the ZIP file files will be added at. In this case, all the files under the `Zip` directory will be put in a `packages` directory, e.g. `packages\Zip`.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -BasePath 'C:\Projects\Zip' -EntryParentPath 'Zip2'

    Demonstrates how to give a directory a different name when adding it to the zip file. In this case, we're adding all the items in `C:\Projects\Zip`. Because the `BasePath` parameter is also set to `C:\Projects\Zip`, normally all the files/directories in `C:\Projects\Zip` would be in the root of the ZIP file, but because the `EntryParentPath` parameter is set to `Zip2`, all the files/directories will be put in a `Zip2` directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        # The path to the ZIP file. Files will be added to this ZIP archive.
        $ZipArchivePath,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [Alias('Path')]
        [string]
        # The files/directories to add to the archive. Normally, you would pipe file/directory objects to `Add-ZipArchiveEntry`. You may also pass any object that has a `FullName` or `Path property. You may also pass the path as a string.
        #
        # If you pass a directory object or path to a directory, all files in that directory and all its sub-directories will be added to the archive.
        $InputObject,

        [string]
        # By default, items are added to the ZIP archive using their full paths (minus any drives/qualifiers). The `BasePath` parameter controls what portion of the source file's path is removed when determining its name in the ZIP archive.
        $BasePath,

        [string]
        # A parent path to add to each file in the ZIP archive. If you pass 'package' to this parameter, and you're adding an item at 'file.txt', the file will be added to the archive as `package\file.txt`.
        $EntryParentPath,

        [IO.Compression.CompressionLevel]
        # The compression level of the ZIP file. The default is `Optimal`. Pass `Fastest` to compress faster but have a larger file. Pass `None` to not compress at all.
        $CompressionLevel = [IO.Compression.CompressionLevel]::Optimal,

        [Text.Encoding]
        # The encoding to use for file names in the ZIP file. The default is UTF8 encoding. You usually only need to change this if your ZIP file will be used by a tool that doesn't handle UTF8 encoding.
        $EntryNameEncoding = [Text.Encoding]::UTF8,

        [Switch]
        # By default, if a file already exists in the ZIP file, you'll get an error. Use this switch to replace any existing entries.
        $Force
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        [IO.Compression.ZipArchive]$zipFile = [IO.Compression.ZipFile]::Open($ZipArchivePath, [IO.Compression.ZipArchiveMode]::Update, $EntryNameEncoding)

        if( $BasePath )
        {
            $basePathRegex = '^{0}{1}?' -f [regex]::Escape($BasePath),[regex]::Escape([IO.Path]::DirectorySeparatorChar)
        }
    }

    process
    {
        $filePaths = $InputObject |
                        Resolve-Path |
                        Select-Object -ExpandProperty 'ProviderPath' |
                        ForEach-Object {
                            if( (Test-Path -Path $_ -PathType Container) )
                            {
                                Get-ChildItem -Path $_ -Recurse -File | Select-Object -ExpandProperty 'FullName'
                            }
                            else
                            {
                                $_
                            }
                        }

        foreach( $filePath in $filePaths )
        {
            $fileEntryName = $filePath | Split-Path -NoQualifier
            $fileEntryName = $fileEntryName.TrimStart([IO.Path]::DirectorySeparatorChar)
            if( $BasePath )
            {
                $fileEntryName = $filePath -replace $basePathRegex,''
            }

            if( $EntryParentPath )
            {
                $fileEntryName = Join-Path -Path $EntryParentPath -ChildPath $fileEntryName
            }
            $entry = $zipFile.GetEntry($fileEntryName)
            if( $entry )
            {
                if( $Force )
                {
                    $entry.Delete()
                }
                else
                {
                    Write-Error -Message ('Unable to add file "{0}" to ZIP archive "{1}": the archive already has a file named "{2}". To overwrite existing entries, use the -Force switch.' -f $filePath,$ZipArchivePath,$fileEntryName)
                    continue
                }
            }
            $entry = $zipFile.CreateEntry($fileEntryName,$CompressionLevel)
            $stream = $entry.Open()
            try
            {
                $writer = New-Object 'IO.StreamWriter' ($stream)
                try
                {
                    [byte[]]$bytes = [IO.File]::ReadAllBytes($filePath)
                    $writer.Write($bytes,0,$bytes.Count)
                }
                finally
                {
                    $writer.Close()
                    $writer.Dispose()
                }
            }
            finally
            {
                $stream.Close()
                $stream.Dispose()
            }
        }
    }

    end
    {
        $zipFile.Dispose()
    }
}