
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve)

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

        $WithBasePath,

        $WithName,

        [Switch]
        $AsString,

        [switch]
        $Quiet
    )

    $packagePath = Join-Path -Path $TestDrive.FullName -ChildPath 'package.upack.zip'
    if( -not (Test-Path -Path $packagePath -PathType Leaf) )
    {
        $script:package = New-ProGetUniversalPackage -OutFile $packagePath -Version '0.0.0' -Name 'ProGetAutomation'
    }

    $params = @{
        PackagePath = $package.FullName
        Quiet = $Quiet
    }

    if( $AtPackageRoot )
    {
        $params['PackageParentPath'] = $AtPackageRoot
    }

    if( $Force )
    {
        $params['Force'] = $true
    }

    if( $WithBasePath )
    {
        $params['BasePath'] = $WithBasePath
    }

    if( $WithName )
    {
        $params['PackageItemName'] = $WithName
    }

    $Global:Error.Clear()

    $Path |
        ForEach-Object { Join-Path -Path $TestDrive.FullName -ChildPath $_ } |
        ForEach-Object {
            if( $AsString )
            {
                $_
            }
            else
            {
                Get-Item -Path $_
            }
        } |
        Add-ProGetUniversalPackageFile @params
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
    WhenAddingFiles '*.cs' -AsString
    ThenPackageContains 'one.cs','two.cs'
}

Describe 'Add-ZipArchiveEntry.when changing name' {
    Init
    GivenFile 'one.cs'
    WhenAddingFiles 'one.cs' -WithName 'cs.one'
    ThenPackageContains 'cs.one'
    ThenPackageNotContains 'one.cs'
}

Describe 'Add-ZipArchiveEntry.when passing a directory' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
    WhenAddingFiles 'dir1'
    ThenPackageContains 'dir1\one.cs','dir1\two.cs','dir1\three\four.cs'
}

Describe 'Add-ZipArchiveEntry.when customizing a directory name' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
    WhenAddingFiles 'dir1' -WithName '1dir'
    ThenPackageContains '1dir\one.cs','1dir\two.cs','1dir\three\four.cs'
    ThenPackageNotContains 'dir1\one.cs','dir1\two.cs','dir1\three\four.cs'
}

Describe 'Add-ZipArchiveEntry.when passing a directory with a custom base path' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
    WhenAddingFiles 'dir1' -WithBasePath (Join-Path -Path $TestDrive.FullName -ChildPath 'dir1')
    ThenPackageContains 'one.cs','two.cs','three\four.cs'
}

Describe 'Add-ZipArchiveEntry.when piping filtered list of files' {
    Init
    GivenFile 'dir1\another\one.cs','dir1\another\two.cs'
    $root = Join-Path -Path $TestDrive.FullName -ChildPath 'dir1'
    WhenAddingFiles 'dir1\another\one.cs','dir1\another\two.cs' -AtPackageRoot 'dir2' -WithBasePath $root
    ThenPackageContains 'dir2\another\one.cs','dir2\another\two.cs'
}

Describe 'Add-ZipArchiveEntry.when giving a direcotry a new root name' {
    Init
    GivenFile 'dir1\one.cs','dir1\two.cs'
    WhenAddingFiles 'dir1\*.cs' -AtPackageRoot 'dir2'
    ThenPackageContains 'dir2\one.cs','dir2\two.cs'
}
Describe 'Add-ZipArchiveEntry.when base path doesn''t match files' {
    Init
    GivenFile 'one.cs'
    WhenAddingFiles 'one.cs' -WithBasePath 'C:\Windows\System32' -ErrorAction SilentlyContinue
    ThenError -Matches 'is\ not\ in'
}

Describe 'Add-ZipArchiveEntry.when given Quiet switch' {
    Init
    Mock -CommandName 'Add-ZipArchiveEntry' -ModuleName 'ProGetAutomation'
    GivenFile 'one.cs'
    WhenAddingFiles 'one.cs' -Quiet

    It 'should call Add-ZipArchiveEntry with Quiet switch' {
        Assert-MockCalled -CommandName 'Add-ZipArchiveEntry' -ModuleName 'ProGetAutomation' -ParameterFilter { $Quiet.IsPresent }
    }
}
