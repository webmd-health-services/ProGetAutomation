
function Add-ZipArchiveEntry
{
    <#
    .SYNOPSIS
    Adds files and directories to a ZIP archive.

    .DESCRIPTION
    The `Add-ZipArchiveEntry` function adds files and directories to a ZIP archive. The archive must exist. Use the `New-ZipArchive` function to create a new ZIP file. Pipe file or directory objects that you want to add to the pipeline. You may also pass paths directly to the `InputObject` parameter (wildcards are **NOT** supported). Relative paths are resolved from the current directory. If you pass a directory or path to a directory, the entire directory and all its sub-directories/files are added to the archive.

    Files are added to the ZIP archive using their names. They are always added to the root of the archive. For example, if you added `C:\Projects\Zip\Zip\Zip.psd1` to an archive, it would get added at `Zip.psd1`.

    Directories are added into a directory in the root of the archive with the source directory's name. For example, if you add 'C:\Projects\Zip', all items will be added to the ZIP archive at `Zip`.

    You can change the name an item will have in the archive with the `EntryName` parameter. Path separators are allowed, so you can put any item into any directory.

    If you don't want to add an entire directory to the archive, but instead only want a filtered set of files from that directory, pipe the filtered list of files to `Add-ZipArchiveEntry` and use the `BasePath` parameter to specify the base path of the incoming files. `Add-ZipArchiveEntry` removes the base path from each file and uses the remaining path as the file's name in the archive.

    If you want to change an item's parent directory structure in the archive, pass the parent path you want to the `EntryParentPath` parameter. For example, if you passed `package` as the `EntryParentPath`, every item added will be put in a `package` directory in the archive.

    You can control the compression level of items getting added with the `CompressionLevel` parameter. The default is `Optimal`. Other options are `Fastest` (larger files, compresses faster) and `None`.

    If your ZIP archive will be used by tools that don't support UTF8-encoded entry names, pass the encoding to use for entry names to the `EntryNameEncoding` parameter. The default is `UTF8`.

    This function uses the native .NET `System.IO.Compression` namespace/classes to do its work.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip'

    Demonstrates how to pipe the files you want to add to your ZIP into `Add-ZipArchiveEntry`. In this case, all the files and directories in the  `C:\Projects\Zip` directory are added to the archive in the root.

    .EXAMPLE
    Get-ChildItem -Path 'C:\Projects\Zip' -Filter '*.ps1' -Recurse | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -BasePath 'C:\Projects\Zip'

    This is like the previous example, but instead of adding every file under `C:\Projects\Zip`, we're only adding files with a `.ps1` extension. Since we're piping all the files to the `Add-ZipArchiveEntry` function, we need to pass the base path of our search to the `BasePath` parameter. Otherwise, every file would get added to the root. Instead, the `BasePath` is removed from every file's path and the remaining path is used as the item's path in the archive.

    .EXAMPLE
    Get-Item -Path '.\Zip' | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -EntryParentPath 'package'

    Demonstrates how to customize the directory in the ZIP file files will be added at. In this case, all the files under the `Zip` directory will be put in a `packages` directory, e.g. `packages\Zip`.

    .EXAMPLE
    Get-ChildItem 'C:\Projects\Zip' | Add-ZipArchiveEntry -ZipArchivePath 'zip.zip' -EntryName 'package\ZipModule'

    Demonstrates how to change the name of an item. In this case, the `C:\Projects\Zip` directory will be added to the archive with a path of `package\ZipModule` instead of `Zip`.
    #>
    [CmdletBinding(DefaultParameterSetName='ItemName')]
    param(
        [Parameter(Mandatory)]
        [string]
        # The path to the ZIP file. Files will be added to this ZIP archive.
        $ZipArchivePath,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [Alias('Path')]
        [string[]]
        # The files/directories to add to the archive. Normally, you would pipe file/directory objects to `Add-ZipArchiveEntry`. You may also pass any object that has a `FullName` or `Path property. You may also pass the path as a string.
        #
        # If you pass a directory object or path to a directory, all files in that directory and all its sub-directories will be added to the archive.
        $InputObject,

        [Parameter(ParameterSetName='BasePath')]
        [string]
        # When determining a file's path/name in the ZIP archive, the value of this parameter is removed from the beginning of each file's path. Use this parameter if you are piping in a filtered list of files from a directory instead of the directory itself.
        $BasePath,

        [Parameter(ParameterSetName='ItemName')]
        [ValidatePattern('^[^\\/]')]
        [ValidatePattern('[^\\/]$')]
        [string]
        # By default, items are added to the ZIP archive using their name. You can change the name with this parameter. For example, if you added file `Zip.psd1` and passed `NewZip.psd1` as the value to the parameter, the file would get added as `NewZip.psd1`.
        $EntryName,

        [ValidatePattern('^[^\\/]')]
        [string]
        # A parent path to add to each file in the ZIP archive. If you pass 'package' to this parameter, and you're adding an item named 'file.txt', the file will be added to the archive as `package\file.txt`.
        $EntryParentPath,

        [IO.Compression.CompressionLevel]
        # The compression level of the ZIP file. The default is `Optimal`. Pass `Fastest` to compress faster but have a larger file. Pass `None` to not compress at all.
        $CompressionLevel = [IO.Compression.CompressionLevel]::Optimal,

        [Text.Encoding]
        # The encoding to use for file names in the ZIP file. The default is UTF8 encoding. You usually only need to change this if your ZIP file will be used by a tool that doesn't handle UTF8 encoding.
        $EntryNameEncoding = [Text.Encoding]::UTF8,

        [Switch]
        # By default, if a file already exists in the ZIP file, you'll get an error. Use this switch to replace any existing entries.
        $Force,

        [switch]
        # Suppress progress messages while adding files to the ZIP archive.
        $Quiet
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $directorySeparators = @( [IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar )
        $directorySeparatorsRegex = $directorySeparators | ForEach-Object { [regex]::Escape($_) }
        $directorySeparatorsRegex = '({0})?' -f ($directorySeparatorsRegex -join '|')

        if( $BasePath )
        {
            $BasePath = $BasePath.TrimEnd($directorySeparators)
            $basePathRegex = '^{0}{1}' -f [regex]::Escape($BasePath),$directorySeparatorsRegex
        }

        $entries = @{}
    }

    process
    {
        $filePaths =
            $InputObject |
            ForEach-Object {
                $path = Resolve-Path -LiteralPath $_ -ErrorAction Ignore
                if( -not $path )
                {
                    $errorSuffix = ''
                    if( $_ -match '\*|\?|\[.*\]' )
                    {
                        $errorSuffix = ' Wildcard expressions are not supported.'
                    }

                    Write-Error -Message ('Cannot find path "{0}" because it does not exist.{1}' -f $_, $errorSuffix) -ErrorAction $ErrorActionPreference
                    return
                }
                $path | Select-Object -ExpandProperty 'ProviderPath'
            }

        foreach( $filePath in $filePaths )
        {
            if( $BasePath )
            {
                $baseEntryName = $filePath -replace $basePathRegex,''
                if( $baseEntryName -eq $filePath )
                {
                    Write-Error -Message ('Path "{0}" is not in base path "{1}". When using the BasePath parameter, all items passed in must be under that path.' -f $filePath,$BasePath)
                    continue
                }
            }
            else
            {
                $baseEntryName = $filePath | Split-Path -Leaf
                if( $EntryName )
                {
                    $baseEntryName = $EntryName
                }
            }

            $baseEntryName = $baseEntryName.TrimStart($directorySeparators)

            if( $EntryParentPath )
            {
                $baseEntryName = Join-Path -Path $EntryParentPath -ChildPath $baseEntryName
            }

            # Add the file.
            if( (Test-Path -LiteralPath $filePath -PathType Leaf) )
            {
                $entries[$baseEntryName] = $filePath
                continue
            }

            # Now, handle directories
            $dirEntryBasePathRegex = '^{0}{1}' -f [regex]::Escape($filePath),$directorySeparatorsRegex
            foreach( $filePath in (Get-ChildItem -LiteralPath $filePath -Recurse -File | Select-Object -ExpandProperty 'FullName') )
            {
                $fileEntryName = $filePath -replace $dirEntryBasePathRegex,''
                if( $baseEntryName )
                {
                    $fileEntryName = Join-Path -Path $baseEntryName -ChildPath $fileEntryName
                }
                $entries[$fileEntryName] = $filePath
            }
        }
    }

    end
    {
        $activity = 'Compressing files into ZIP archive {0}' -f $ZipArchivePath
        $writeProgress = [Environment]::UserInteractive -and -not $Quiet
        if( $writeProgress )
        {
            Write-Progress -Activity $activity
        }

        $bufferSize = 4kb
        [byte[]]$buffer = New-Object 'byte[]' ($bufferSize)
        [IO.Compression.ZipArchive]$zipFile = [IO.Compression.ZipFile]::Open($ZipArchivePath, [IO.Compression.ZipArchiveMode]::Update, $EntryNameEncoding)

        $timer = New-Object 'Timers.Timer' 100
        $timer |
            Add-Member -Name 'ProcessedCount' -Value 0 -MemberType NoteProperty -PassThru |
            Add-Member -MemberType NoteProperty -Name 'Activity' -Value $activity -PassThru |
            Add-Member -MemberType NoteProperty -Name 'FilePath' -Value '' -PassThru|
            Add-Member -MemberType NoteProperty -Name 'EntryName' -Value '' -PassThru |
            Add-Member -MemberType NoteProperty -Name 'TotalCount' -Value $entries.Count

        if( $writeProgress )
        {
            # Write-Progress is *expensive*. Only do it if the user is interactive and only every 1/10th of a second.
            Register-ObjectEvent -InputObject $timer -EventName 'Elapsed' -Action {
                param(
                    $Timer,
                    $EventArgs
                )
                Write-Progress -Activity $Timer.Activity -Status $Timer.FilePath -CurrentOperation $Timer.EntryName -PercentComplete (($Timer.ProcessedCount/$Timer.TotalCount) * 100)
            } | Out-Null
            $timer.Enabled = $true
            $timer.Start()
        }

        try
        {
            foreach( $entryName in $entries.Keys )
            {
                $timer.FilePath = $filePath = $entries[$entryName]
                $timer.ProcessedCount += 1
                $timer.EntryName = $entryName

                Write-Debug -Message ('{0} -> {1}' -f $FilePath,$EntryName)
                $entry = $zipFile.GetEntry($EntryName)
                if( $entry )
                {
                    if( $Force )
                    {
                        $entry.Delete()
                    }
                    else
                    {
                        Write-Error -Message ('Unable to add file "{0}" to ZIP archive "{1}": the archive already has a file named "{2}".' -f $FilePath,$ZipArchivePath,$EntryName)
                        continue
                    }
                }

                $entry = $zipFile.CreateEntry($EntryName,$CompressionLevel)
                $entry.LastWriteTime = (Get-Item -LiteralPath $filePath).LastWriteTime
                $stream = $entry.Open()
                try
                {
                    $writer = New-Object 'IO.BinaryWriter' ($stream)
                    try
                    {
                        [Array]::Clear($buffer,0,$bufferSize)
                        $fileReader = New-Object 'IO.FileStream' ($filePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read,$bufferSize,[IO.FileOptions]::SequentialScan)
                        try
                        {
                            while( $true )
                            {
                                [int]$bytesRead = $fileReader.Read($buffer, 0, $bufferSize)
                                if( -not $bytesRead )
                                {
                                    break
                                }
                                $writer.Write($buffer,0,$bytesRead)
                            }
                        }
                        finally
                        {
                            $fileReader.Close()
                            $fileREader.Dispose()
                        }
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
        finally
        {
            $timer.Stop()
            $timer.Dispose()
            $zipFile.Dispose()
            if( $writeProgress )
            {
                Write-Progress -Activity $activity -Status 'Writing File' -PercentComplete 99
                Write-Progress -Activity $activity -Completed
            }
        }
    }
}
