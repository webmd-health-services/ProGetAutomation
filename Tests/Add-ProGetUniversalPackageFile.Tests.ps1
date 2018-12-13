
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve)
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PSModules\Glob' -Resolve) -Force

$package = $null

function GivenFile
{
    param(
        [string[]]
        $Path,

        $Content
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $TestDrive.FullName -ChildPath $pathItem

        $parentDir = $fullPath | Split-Path
        if( -not (Test-Path -Path $parentDir -PathType Container) )
        {
            New-Item -Path $parentDir -ItemType 'Directory'
        }

        if( -not (Test-Path -Path $fullPath -PathType Leaf) )
        {
            New-Item -Path $fullPath -ItemType 'File'
        }

        if( $Content )
        {
            [IO.File]::WriteAllText($fullPath,$Content)
        }
    }
}

function Init
{
    $script:package = $null
}

function ThenPackageContains
{
    param(
        [string[]]
        $EntryName,

        $ExpectedContent
    )

    [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($package.FullName)
    try
    {
        It ('shouldn''t have duplicate entries') {
            $file.Entries | Group-Object -Property 'FullName' | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty 'Group' | Should -HaveCount 0
        }

        It ('should add files to ZIP') {
            foreach( $entryNameItem in $EntryName )
            {
                [IO.Compression.ZipArchiveEntry]$entry = $file.GetEntry(('package\{0}' -f $entryNameItem))
                $entry | Should -Not -BeNullOrEmpty
                if( $ExpectedContent )
                {
                    $reader = New-Object 'IO.StreamReader' ($entry.Open())
                    try
                    {
                        $content = $reader.ReadToEnd()
                        $content | Should -Be $ExpectedContent
                    }
                    finally
                    {
                        $reader.Close()
                    }
                }
            }
        }
    }
    finally
    {
        $file.Dispose()
    }
}

function ThenPackageEmpty
{
    [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($package.FullName)
    try
    {
        It ('should not add any files to ZIP') {
            $file.Entries | Should -BeNullOrEmpty
        }
    }
    finally
    {
        $file.Dispose()
    }    
}

function ThenPackageNotContains
{
    param(
        [string[]]
        $Entry
    )

    [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($package.FullName)
    try
    {
        It ('should not add files to ZIP') {
            foreach( $entryName in $Entry )
            {
                $file.GetEntry($entryName) | Should -BeNullOrEmpty
                $file.GetEntry(('package\{0}' -f $entryName)) | Should -BeNullOrEmpty
            }
        }
    }
    finally
    {
        $file.Dispose()
    }
}

function ThenError
{
    param(
        $Matches
    )

    It ('should write an error') {
        $Global:Error | Should -Match $Matches
    }
}

function WhenAddingFiles
{
    [CmdletBinding()]
    param(
        [string[]]
        $Path,

        [Switch]
        $Force,

        $AtPackageRoot,

        [Switch]
        $NoPipeline,

        [Switch]
        $NoBasePath,

        [string]
        $AtBasePath
    )

    $packagePath = Join-Path -Path $TestDrive.FullName -ChildPath 'package.upack.zip'
    if( -not (Test-Path -Path $packagePath -PathType Leaf) )
    {
        $script:package = New-ProGetUniversalPackage -OutFile $packagePath -Version '0.0.0' -Name 'ProGetAutomation'
    }

    $params = @{
                    PackagePath = $package.FullName;
                }
    if( $AtBasePath )
    {
        $params['BasePath'] = $AtBasePath
    }
    else
    {
        $params['BasePath'] = $TestDrive.FullName
    }

    if( $AtPackageRoot )
    {
        $params['PackageParentPath'] = $AtPackageRoot
    }

    if( $Force )
    {
        $params['Force'] = $true
    }

    $Global:Error.Clear()
    if( $NoPipeline )
    {
        Push-Location -Path $TestDrive.FullName
        try
        {
            foreach( $item in $Path )
            {
                Add-ProGetUniversalPackageFile @params -InputObject $item
            }
        }
        finally
        {
            Pop-Location
        }
    }
    else
    {
        Find-GlobFile -Path $TestDrive.FullName -Include $Path | Add-ProGetUniversalPackageFile @params
    }
}

Describe 'Add-ProGetUniversalPackageFile' {
    Init
    GivenFile 'one.cs','one.aspx','one.js','one.txt'
    WhenAddingFiles '*.aspx','*.js'
    ThenPackageContains 'one.aspx','one.js'
    ThenPackageNotContains 'one.cs','one.txt'
}

Describe 'Add-ProGetUniversalPackageFile.when file already exists' {
    Init
    GivenFile 'one.cs' 'first'
    WhenAddingFiles '*.cs'
    GivenFile 'one.cs' 'second'
    WhenAddingFiles '*.cs' -ErrorAction SilentlyContinue
    ThenPackageContains 'one.cs' 'first'
}

Describe 'Add-ProGetUniversalPackageFile.when file already exists and forcing overwrite' {
    Init
    GivenFile 'one.cs' 'first'
    WhenAddingFiles '*.cs'
    GivenFile 'one.cs' 'second'
    WhenAddingFiles '*.cs' -Force
    ThenPackageContains 'one.cs' 'second'
}

Describe 'Add-ProGetUniversalPackageFile.when adding package root' {
    Init
    GivenFile 'one.cs'
    WhenAddingFiles '*.cs' -AtPackageRoot 'package'
    ThenPackageContains 'package\one.cs'
    ThenPackageNotContains 'one.cs'
}

Describe 'Add-ProGetUniversalPackageFile.when passing path instead of file objects' {
    Init
    GivenFile 'one.cs','two.cs'
    WhenAddingFiles '*.cs' -NoPipeline
    ThenPackageContains 'one.cs','two.cs'
}

Describe 'Add-ProGetUniversalPackageFile.when passing a directory' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs'
    WhenAddingFiles (Join-Path -Path $TestDrive.FullName -ChildPath 'dir1') -NoPipeline
    ThenPackageContains 'dir1\one.cs','dir1\two.cs'
}

Describe 'Add-ProGetUniversalPackageFile.when giving an item a new root name' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs'
    $root = Join-Path -Path $TestDrive.FullName -ChildPath 'dir1'
    WhenAddingFiles $root -AtBasePath $root -AtPackageRoot 'dir2' -NoPipeline
    ThenPackageContains 'dir2\one.cs','dir2\two.cs'
}
