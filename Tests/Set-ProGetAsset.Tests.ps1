
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:testDir = $null
    $script:testNum = 1
    $script:fileName = $null
    $script:assetName = $null
    $script:feedName = $PSCommandPath | Split-Path -Leaf
    $script:directory = $null
    $script:filePath = $null
    $script:valueContent = $null

    $script:session = New-ProGetTestSession
    Get-ProGetFeed -Session $session -Name $script:feedName -ErrorAction Ignore |
        Remove-ProGetFeed -Session $session -Force
    New-ProGetFeed -Session $session -Name $script:feedName -Type 'Asset'

    function GivenFile
    {
        param(
            [String] $Path,

            [String] $WithContent
        )

        $script:filePath = Join-Path -Path $script:testDir -ChildPath $Path
        New-Item -Path $script:filePath -ItemType 'File' -Force

        if ($WithContent)
        {
            [IO.File]::WriteAllText($filePath, $WithContent)
        }
    }

    function WhenAssetIsPublished
    {
        [CmdletBinding()]
        param(
            [hashtable] $WithArgs = @{}
        )

        if (-not $WithArgs.ContainsKey('DirectoryName'))
        {
            $WithArgs['DirectoryName'] = $script:feedName
        }

        Push-Location $script:testDir
        try
        {
            Set-ProGetAsset -Session $script:session @WithArgs
        }
        finally
        {
            Pop-Location
        }
    }

    function ThenAsset
    {
        param(
            [switch] $Not,

            [switch] $Exists,

            [String] $InFolder = '',

            [String] $WithContent = ''
        )

        $asset = $null
        try
        {
            $asset =
                Get-ProGetAsset -Session $script:session `
                                -DirectoryName $script:feedName `
                                -Path $InFolder `
                                -ErrorAction Ignore |
                Where-Object 'name' -eq $script:assetName
        }
        catch
        {
            # Throws 404 in PowerShell if asset does not exist.
        }

        if ($Not)
        {
            $asset | Should -BeNullOrEmpty
        }
        else
        {
            $path = $script:assetName
            if ($InFolder)
            {
                $path = Join-Path -Path $InFolder -ChildPath $path
            }

            $asset | Should -Not -BeNullOrEmpty
            $assetContents =
                Get-ProGetAssetContent -Session $session -DirectoryName $script:feedName -Path $path
            $assetContents | Should -Be $WithContent
        }
    }

    function ThenError
    {
        [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
        param(
            [String] $Matches,

            [switch] $IsEmpty
        )

        if ($IsEmpty)
        {
            $Global:Error | Should -BeNullOrEmpty
        }

        if ($Matches)
        {
            $Global:Error | Should -Match $Matches
        }
    }
}

Describe 'Set-ProGetAsset' {
    BeforeEach {
        $Global:Error.Clear()

        $script:testDir = Join-Path -Path $TestDrive -ChildPath $script:testNum
        New-Item -Path $script:testDir -ItemType Directory

        $script:fileName = $null
        $script:assetName = "asset$($script:testNum).txt"
        $script:directory = $null
        $script:filePath = $null
        $script:valueContent = $null
}

    AfterEach {
        $script:testNum += 1
    }

    It 'should upload empty asset' {
        GivenFile $script:assetName
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = $script:assetName }
        ThenAsset -Exists
        ThenError -IsEmpty
    }

    It 'should upload asset' {
        $content = ((New-Guid).ToString('N') + [Environment]::NewLine) * 20
        GivenFile $script:assetName -WithContent $content
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = $script:assetName }
        ThenAsset -Exists -WithContent $content
        ThenError -IsEmpty
    }

    It 'should upload assets in chunks' {
        $content = ((New-Guid).ToString('N') + [Environment]::NewLine) * 20
        GivenFile $script:assetName -WithContent $content
        WhenAssetIsPublished -WithArgs @{
            FilePath = $script:assetName;
            MaxRequestSize = (New-Guid).ToString('N').Length;
            Path = $script:assetName;
        }
        ThenAsset -Exists -WithContent $content
        ThenError -IsEmpty
    }

    It 'should upload to subfolder' {
        GivenFile $script:assetName
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = "subdir1/$($script:assetName)" }
        ThenAsset -Exists -InFolder 'subdir1'
        ThenError -IsEmpty
    }

    It 'should handle backslashes in asset path' {
        GivenFile $script:assetName
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = "\subdir2\$($script:assetName)" }
        ThenAsset -Exists -InFolder 'subdir2'
        ThenError -IsEmpty
    }

    It 'should require asset directory to exist' {
        GivenFile $script:assetName
        WhenAssetIsPublished -ErrorAction SilentlyContinue -WithArgs @{
            DirectoryName = 'badDir';
            FilePath = $script:assetName;
            Path = $script:assetName
        }
        ThenAsset -Not -Exists -InDirectory 'badDir'
        ThenError -Matches '.badDir. because that asset directory does not exist'
    }

    It 'should allow relative file paths' {
        GivenFile "dir/$($script:assetName)"
        WhenAssetIsPublished -WithArgs @{ FilePath = "dir/$($script:assetName)" ; Path = $script:assetName }
        ThenAsset -Exists
        ThenError -IsEmpty
    }

    It 'should validate file exists' {
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = $script:assetName } -ErrorAction SilentlyContinue
        ThenAsset -Not -Exists
        ThenError -Matches "$([regex]::Escape($script:assetName))..*that file does not exist"
    }

    It 'should replace existing file' {
        GivenFile $script:assetName -WithContent 'fubarsnafu'
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = $script:assetName }
        ThenAsset -Exists -WithContent 'fubarsnafu'
        GivenFile $script:assetName -WithContent 'snafufubar'
        WhenAssetIsPublished -WithArgs @{ FilePath = $script:assetName ; Path = $script:assetName }
        ThenAsset -Exists -WithContent 'snafufubar'
        ThenError -IsEmpty
    }

    It 'should create asset from string' {
        $content = @{ Test = 'Test'; Test2 = 'Test2' } | ConvertTo-Json | Out-String
        WhenAssetIsPublished -WithArgs @{ Path = $script:assetName ; Content = $content }
        ThenAsset -Exists -WithContent $content
        ThenError -IsEmpty
    }
}