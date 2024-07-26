
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:testDirPath = $null
    $script:testNum = 0
    $script:package = $null

    function GivenFile
    {
        param(
            [string[]]
            $Path,

            $Content
        )

        foreach( $pathItem in $Path )
        {
            $fullPath = Join-Path -Path $script:testDirPath -ChildPath $pathItem

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

    function ThenPackageContains
    {
        param(
            [string[]]
            $EntryName,

            $ExpectedContent
        )

        [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($script:package.FullName)
        try
        {
            $file.Entries | Group-Object -Property 'FullName' | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty 'Group' | Should -HaveCount 0

            foreach( $entryNameItem in $EntryName )
            {
                $entryNameItem = $entryNameItem -replace '\\','/'
                [IO.Compression.ZipArchiveEntry]$entry = $file.GetEntry(('package/{0}' -f $entryNameItem))
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
        finally
        {
            $file.Dispose()
        }
    }

    function ThenPackageEmpty
    {
        [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($script:package.FullName)
        try
        {
            $file.Entries | Should -BeNullOrEmpty
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

        [IO.Compression.ZipArchive]$file = [IO.Compression.ZipFile]::OpenRead($script:package.FullName)
        try
        {
            foreach( $entryName in $Entry )
            {
                $file.GetEntry($entryName) | Should -BeNullOrEmpty
                $file.GetEntry(('package\{0}' -f $entryName)) | Should -BeNullOrEmpty
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

        $Global:Error | Should -Match $Matches
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
            $Quiet,

            [switch]
            $NonPipeline
        )

        $packagePath = Join-Path -Path $script:testDirPath -ChildPath 'package.upack.zip'
        if( -not (Test-Path -Path $packagePath -PathType Leaf) )
        {
            $script:package = New-ProGetUniversalPackage -OutFile $packagePath -Version '0.0.0' -Name 'ProGetAutomation'
        }

        $params = @{
            PackagePath = $script:package.FullName
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

        $pathsToPackage =
            $Path |
            ForEach-Object { Join-Path -Path $script:testDirPath -ChildPath $_ } |
            ForEach-Object {
                if( $AsString )
                {
                    $_
                }
                else
                {
                    Get-Item -Path $_
                }
            }

        if( $NonPipeline )
        {
            Add-ProGetUniversalPackageFile -InputObject $pathsToPackage @params
        }
        else
        {
            $pathsToPackage | Add-ProGetUniversalPackageFile @params
        }
    }
}

Describe 'Add-ProGetUniversalPackageFile' {
    BeforeEach {
        $script:package = $null
        $script:testDirPath = Join-Path -Path $TestDrive -ChildPath ($script:testNum++)
        New-Item -Path $script:testDirPath -ItemType Directory
    }

    It 'packages files' {
        GivenFile 'one.cs','one.aspx','one.js','one.txt'
        WhenAddingFiles '*.aspx','*.js'
        ThenPackageContains 'one.aspx','one.js'
        ThenPackageNotContains 'one.cs','one.txt'
    }

    It 'when package already contains file' {
        GivenFile 'one.cs' 'first'
        WhenAddingFiles '*.cs'
        GivenFile 'one.cs' 'second'
        WhenAddingFiles '*.cs' -ErrorAction SilentlyContinue
        ThenPackageContains 'one.cs' 'first'
    }

    It 'when file already exists and forcing overwrite' {
        GivenFile 'one.cs' 'first'
        WhenAddingFiles '*.cs'
        GivenFile 'one.cs' 'second'
        WhenAddingFiles '*.cs' -Force
        ThenPackageContains 'one.cs' 'second'
    }

    It 'when adding package root' {
        GivenFile 'one.cs'
        WhenAddingFiles '*.cs' -AtPackageRoot 'package'
        ThenPackageContains 'package\one.cs'
        ThenPackageNotContains 'one.cs'
    }

    It 'when passing path instead of file objects' {
        GivenFile 'one.cs','two.cs'
        WhenAddingFiles 'one.cs', 'two.cs' -AsString
        ThenPackageContains 'one.cs','two.cs'
    }

    It 'when changing name' {
        GivenFile 'one.cs'
        WhenAddingFiles 'one.cs' -WithName 'cs.one'
        ThenPackageContains 'cs.one'
        ThenPackageNotContains 'one.cs'
    }

    It 'when passing a directory' {
        GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
        WhenAddingFiles 'dir1'
        ThenPackageContains 'dir1\one.cs','dir1\two.cs','dir1\three\four.cs'
    }

    It 'when customizing a directory name' {
        GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
        WhenAddingFiles 'dir1' -WithName '1dir'
        ThenPackageContains '1dir\one.cs','1dir\two.cs','1dir\three\four.cs'
        ThenPackageNotContains 'dir1\one.cs','dir1\two.cs','dir1\three\four.cs'
    }

    It 'when passing a directory with a custom base path' {
        GivenFile 'dir1\one.cs','dir1\two.cs', 'dir1\three\four.cs'
        WhenAddingFiles 'dir1' -WithBasePath (Join-Path -Path $script:testDirPath -ChildPath 'dir1')
        ThenPackageContains 'one.cs','two.cs','three\four.cs'
    }

    It 'when piping filtered list of files' {
        GivenFile 'dir1\another\one.cs','dir1\another\two.cs'
        $root = Join-Path -Path $script:testDirPath -ChildPath 'dir1'
        WhenAddingFiles 'dir1\another\one.cs','dir1\another\two.cs' -AtPackageRoot 'dir2' -WithBasePath $root
        ThenPackageContains 'dir2\another\one.cs','dir2\another\two.cs'
    }

    It 'when giving a direcotry a new root name' {
        GivenFile 'dir1\one.cs','dir1\two.cs'
        WhenAddingFiles 'dir1\*.cs' -AtPackageRoot 'dir2'
        ThenPackageContains 'dir2\one.cs','dir2\two.cs'
    }

    It 'when base path doesn''t match files' {
        GivenFile 'one.cs'
        WhenAddingFiles 'one.cs' -WithBasePath 'C:\Windows\System32' -ErrorAction SilentlyContinue
        ThenError -Matches 'is\ not\ in'
    }

    It 'when given Quiet switch' {
        Mock -CommandName 'Add-ZipArchiveEntry' -ModuleName 'ProGetAutomation'
        GivenFile 'one.cs'
        WhenAddingFiles 'one.cs' -Quiet

        Assert-MockCalled -CommandName 'Add-ZipArchiveEntry' `
                          -ModuleName 'ProGetAutomation' `
                          -ParameterFilter { $Quiet.IsPresent }
    }

    It 'when passes files directly, in a non-pipeline manner' {
        GivenFile 'one.cs', 'two.cs'
        WhenAddingFiles 'one.cs', 'two.cs' -NonPipeline
        ThenPackageContains 'one.cs', 'two.cs'
    }
}