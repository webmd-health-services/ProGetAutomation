
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:testDir = $null
    $script:testNum = 1
    $script:fileName = $null
    $script:progetAssetName = $null
    $script:feedName = $null
    $script:directory = $null
    $script:filePath = $null
    $script:valueContent = $null

    function GivenSession
    {
        $script:session = New-ProGetTestSession
        $feed = Test-ProGetFeed -Session $session -Name $script:feedName -Type 'Asset'
        if( !$feed )
        {
            New-ProGetFeed -Session $session -Name $script:feedName -Type 'Asset'
        }
    }

    function GivenAssetName
    {
        param(
            [string]
            $Name
        )

        $script:proGetAssetName = $Name
    }

    function GivenAssetDirectory
    {
        param(
            [string]
            $RootDirectory
        )

        $script:feedName = $RootDirectory
    }

    function GivenSourceFilePath
    {
        param(
            [String] $Path,

            [switch] $WhereFileDoesNotExist
        )

        $script:filePath = Join-Path -Path $script:testDir -ChildPath $Path

        if (-not $WhereFileDoesNotExist)
        {
            New-Item -Path $script:filePath -ItemType 'File' -Force
        }
    }

    function GivenSourceContent
    {
        param(
            [string] $Content
        )

        $script:content = $Content
    }

    function WhenAssetIsPublished
    {
        [CmdletBinding()]
        param(
        )

        $params = @{ }
        if( $script:filePath )
        {
            $params['FilePath'] = $script:filePath
        }
        else
        {
            $params['Content'] = $script:content
        }

        Set-ProGetAsset -Session $session -Path $proGetAssetName -DirectoryName $script:feedName @params
    }

    function ThenAssetShouldExist
    {
        param(
            [string]
            $Name,
            [string]
            $Directory
        )

        Get-ProGetAsset -Session $session -DirectoryName $script:feedName -Path $Directory |
            Where-Object { $_.name -match $name } |
            Should -Not -BeNullOrEmpty
    }

    function ThenAssetShouldNotExist
    {
        param(
            [string]
            $Name,
            [string]
            $Directory
        )

        Get-ProGetAsset -Session $session -DirectoryName $script:feedName -Path $Directory -ErrorAction Ignore |
            Where-Object { $_.name -match $name } |
            Should -BeNullOrEmpty
    }

    function ThenAssetContentsShouldMatch
    {
        param(
            $Content
        )

        $assetContents = Invoke-ProGetRestMethod -Session $session -Path ('/endpoints/{0}/content/{1}' -f $script:feedName, $progetAssetName) -Method Get

        $assetContents.Test | Should -Be $Content.Test
        $assetContents.Test2 | Should -Be $Content.Test2
    }

    function ThenErrorShouldBeThrown
    {
        param(
            [String] $ExpectedError
        )

        $Global:Error | Should -Match $ExpectedError
    }

    function ThenNoErrorShouldBeThrown
    {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Set-ProGetAsset' {
    BeforeEach {
        $Global:Error.Clear()

        $script:testDir = Join-Path -Path $TestDrive -ChildPath $script:testNum
        New-Item -Path $script:testDir -ItemType Directory

        $script:fileName = $null
        $script:progetAssetName = $null
        $script:feedName = "$($PSCommandPath | Split-Path -Leaf)-$($script:testNum)"
        $script:directory = $null
        $script:filePath = $null
        $script:valueContent = $null
}

    AfterEach {
        $script:testNum += 1
    }

    It 'should upload asset' {
        GivenSession
        GivenAssetName 'foo.txt'
        GivenSourceFilePath 'foo.txt'
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt' -Directory ''
        ThenNoErrorShouldBeThrown
    }

    It 'should upload to subfolder' {
        GivenSession
        GivenAssetName 'subdir/foo.txt'
        GivenSourceFilePath 'foo.txt'
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt' -Directory 'subdir'
        ThenNoErrorShouldBeThrown
    }

    It 'should handle backslashes in asset path' {
        GivenSession
        GivenAssetName '\subdir\foo.txt'
        GivenSourceFilePath 'foo.txt'
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt' -Directory 'subdir'
        ThenNoErrorShouldBeThrown
    }

    It 'should require asset directory to exist' {
        GivenSession
        GivenAssetName 'foo.txt'
        GivenAssetDirectory 'badDir'
        GivenSourceFilePath 'foo.txt'
        WhenAssetIsPublished -ErrorAction SilentlyContinue
        ThenAssetShouldNotExist -Name 'foo.txt' -Directory 'badDir'
        ThenErrorShouldBeThrown -ExpectedError 'There\ is\ no\ feed\ with\ that\ name\ in\ ProGet\.'
    }

    It 'should allow relative file paths' {
        GivenSession
        GivenAssetName 'foo.txt'
        GivenSourceFilePath 'dir/foo.txt'
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt'
        ThenNoErrorShouldBeThrown
    }

    It 'should validate file exists' {
        GivenSession
        GivenAssetName 'fubu.txt'
        GivenSourceFilePath 'fubu.txt' -WhereFileDoesNotExist
        WhenAssetIsPublished -ErrorAction SilentlyContinue
        ThenAssetShouldNotExist -Name 'fubu.txt' -Directory ''
        ThenErrorShouldBeThrown -ExpectedError 'fubu\.txt..*that file does not exist'
    }

    It 'should replace existing file' {
        GivenSession
        GivenAssetName 'foo.txt'
        GivenSourceFilePath 'foo.txt'
        WhenAssetIsPublished
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt'
        ThenNoErrorShouldBeThrown
    }

    It 'should create asset from string' {
        GivenSession
        GivenAssetName 'foo.txt'
        GivenSourceContent (@{ Test = 'Test'; Test2 = 'Test2' } | ConvertTo-Json | Out-String)
        WhenAssetIsPublished
        ThenAssetShouldExist -Name 'foo.txt' -Directory ''
        ThenAssetContentsShouldMatch @{ Test = 'Test'; Test2 = 'Test2' }
        ThenNoErrorShouldBeThrown
    }
}