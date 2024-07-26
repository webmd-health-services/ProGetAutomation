
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:testNum = 0
    $script:testDirPath = $null

    function GivenSession
    {
        $script:session = New-ProGetTestSession
        $script:baseDirectory = (split-path -Path $script:testDirPath -leaf)
        $feed = Test-ProGetFeed -Session $session -Name $baseDirectory
        if( !$feed )
        {
            New-ProGetFeed -Session $session -Name $baseDirectory -Type 'Asset'
        }
    }

    function GivenAssets
    {
        param(
            [string[]]
            $Name,
            [string]
            $WithContent = 'test'
        )

        foreach($file in $Name)
        {
            New-Item -Path (Join-Path -Path $script:testDirPath -ChildPath $file) -Type 'file' -value $WithContent -Force
            Set-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $file -FilePath (Join-Path -Path $script:testDirPath -ChildPath $file)
        }
    }

    function WhenAssetIsRequested
    {
        param(
            [string]
            $Filter,
            [string]
            $Subdirectory
        )
        $Global:Error.Clear()
        $script:assets = Get-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Subdirectory -Filter $Filter -ErrorAction SilentlyContinue
    }

    function ThenListShouldBeReturned
    {
        param(
            [string[]]
            $Name
        )

        foreach($asset in $assets) { $Name | Where-Object { $_ -contains $asset.Name } | Should -not -BeNullOrEmpty }
        foreach($item in $Name) { $assets | Where-Object { $_.name -contains $item} | Should -not -BeNullOrEmpty }
    }

    function ThenListShouldBeEmpty
    {
        $assets | Should -BeNullOrEmpty
    }
    function ThenNoErrorShouldBeThrown
    {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Get-ProGetAsset' {
    BeforeEach {
        $script:testDirPath = Join-Path -Path $TestDrive -ChildPath ($script:testNum++)
        New-Item -Path $script:testDirPath -ItemType Directory
    }

    It 'when list of assets is returned'{
        GivenSession
        GivenAssets -name 'foo','bar' -directory
        WhenAssetIsRequested
        ThenListShouldBeReturned -name 'foo','bar'
        ThenNoErrorShouldBeThrown
    }

    It 'when using wildcard'{
        GivenSession
        GivenAssets -name 'foo','foobar','notfbar'
        WhenAssetIsRequested -filter '*foo*'
        ThenListShouldBeReturned -name 'foo','foobar'
        ThenNoErrorShouldBeThrown
    }

    It 'when single asset is returned'{
        GivenSession
        GivenAssets -name 'foo.txt' -WithContent 'test'
        WhenAssetIsRequested -filter 'foo.txt'
        ThenListShouldBeReturned -name 'foo.txt'
        ThenNoErrorShouldBeThrown
    }

    It 'when asset is requested but does not exist'{
        GivenSession
        GivenAssets -name 'foo' -withContent 'test content'
        WhenAssetIsRequested -filter 'fubu'
        ThenNoErrorShouldBeThrown
        ThenListShouldBeEmpty
    }

    It 'when list of assets is returned from a subdirectory'{
        GivenSession
        GivenAssets -name 'world/world.txt','world/hello.txt' -Directory 'hello'
        WhenAssetIsRequested -subdirectory 'world'
        ThenListShouldBeReturned -name 'world.txt','hello.txt'
        ThenNoErrorShouldBeThrown
    }

    It 'when list of assets is returned from a subdirectory with backslashes'{
        GivenSession
        GivenAssets -name '\world\world.txt','\world\hello.txt' -Directory '\hello\'
        WhenAssetIsRequested -subdirectory 'world'
        ThenListShouldBeReturned -name 'world.txt','hello.txt'
        ThenNoErrorShouldBeThrown
    }
}
