
function New-ZipArchive
{
    <#
    .SYNOPSIS
    Creates a new, empty ZIP archive.

    .DESCRIPTION
    The `New-ZipArchive` function createa a new, empty ZIP archive. Pass the path to the archive to the Path parameter. A new, empty ZIP archive is created at that path. The function returns a `IO.FileInfo` objecy representing the new ZIP archive.

    If `Path` is relative, it is create relative to the current directory. 

    If a file already exists, you'll get an error and nothing will be returned. To delete any existing file and create a new, empty ZIP archive, pass the `Force` switch.

    You can control the compression level of the archive by passing an `IO.Compression.CompressionLevel` value to the `CompressionLevel` parameter. The default is `Optimal`. Other values are `Fastest` and `None`.
    
    By default, entry names are encoded as UTF8 text. If your ZIP archive will be consumed by tools that don't support UTF8, pass the encoding they do support to the `EntryNameEncoding` parameter.

    .EXAMPLE
    New-ZipArchive -Path 'archive.zip'

    Creates a new, empty ZIP file named `archive.zip` in the current directory.

    .EXAMPLE
    New-ZipArchive Path 'archive.zip' -Force

    Creates a new, empty ZIP file named `archive.zip` in the current directory. If a file named 'archive.zip' already exists in the current directory, it is deleted and a new file created.

    .EXAMPLE
    New-ZipArchive Path 'archive.zip' -CompressionLevel Fastest -Encoding [Text.Encoding]::ASCII

    Creates a new, empty ZIP file using fastest compression and encoding entry names in ASCII.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        # The path to the ZIP archive to create. Should include the file name. The file must not exist.
        $Path,

        [IO.Compression.CompressionLevel]
        $CompressionLevel = [IO.Compression.CompressionLevel]::Optimal,

        [Text.Encoding]
        $EntryNameEncoding = [Text.Encoding]::UTF8,

        [Switch]
        # If the ZIP file already exists, delete it and create a new file.
        $Force
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( -not [IO.Path]::IsPathRooted($Path) )
    {
        $Path = Join-Path -Path (Get-Location) -ChildPath $Path
    }
    $Path = [IO.Path]::GetFullPath($Path)

    if( (Test-Path -Path $Path) )
    {
        if( $Force )
        {
            Remove-Item -Path $Path
        }
        else
        {
            Write-Error -Message ('The file "{0}" already exists. Unable to create a new ZIP archive at that path. Use the -Force switch to overwrite the file.' -f $Path)
            return
        }
    }

    $tempDir = Join-Path -Path $env:TEMP -ChildPath ('{0}.{1}' -f ($Path | Split-Path -Leaf),([IO.Path]::GetRandomFileName()))
    New-Item -Path $tempDir -ItemType 'Directory' | Out-Null
    try
    {
        [IO.Compression.ZipFile]::CreateFromDirectory($tempDir,$Path,$CompressionLevel,$false,$EntryNameEncoding)
        Get-Item -Path $Path
    }
    finally
    {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Ignore
    }
}
