& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $script:baseDirectory = (split-path -Path $TestDrive.FullName -leaf)
    $feed = Test-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
    if( !$feed )
    {
        New-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
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
        New-Item -Path (Join-Path -Path $TestDrive.FullName -ChildPath $file) -Type 'file' -value $WithContent -Force 
        Set-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $file -FilePath (Join-Path -Path $TestDrive.FullName -ChildPath $file)
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
    write-host $assets
}

function ThenListShouldBeReturned
{
    param(
        [string[]]
        $Name
    )
        it ('should return a list that matches ''{0}''' -f ($Name -join ''', ''')){
            foreach($asset in $assets) { $Name | Where-Object { $_ -contains $asset.Name } | Should -not -BeNullOrEmpty }
            foreach($item in $Name) { $assets | Where-Object { $_.name -contains $item} | Should -not -BeNullOrEmpty }
        }
}

function ThenListShouldBeEmpty
{
    it 'should return a list that is empty' {
        $assets | Should -BeNullOrEmpty
    }
}
function ThenNoErrorShouldBeThrown
{
    It 'should not throw an error' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Get-ProGetAsset.when list of assets is returned'{
    GivenSession
    GivenAssets -name 'foo','bar' -directory
    WhenAssetIsRequested
    ThenListShouldBeReturned -name 'foo','bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when using wildcard'{
    GivenSession
    GivenAssets -name 'foo','foobar','notfbar'
    WhenAssetIsRequested -filter '*foo*'
    ThenListShouldBeReturned -name 'foo','foobar'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when single asset is returned'{
    GivenSession
    GivenAssets -name 'foo.txt' -WithContent 'test'
    WhenAssetIsRequested -filter 'foo.txt'
    ThenListShouldBeReturned -name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when asset is requested but does not exist'{
    GivenSession
    GivenAssets -name 'foo' -withContent 'test content'
    WhenAssetIsRequested -filter 'fubu'
    ThenNoErrorShouldBeThrown
    ThenListShouldBeEmpty
}

Describe 'Get-ProGetAsset.when list of assets is returned from a subdirectory'{
    GivenSession
    GivenAssets -name 'world/world.txt','world/hello.txt' -Directory 'hello'
    WhenAssetIsRequested -subdirectory 'world'
    ThenListShouldBeReturned -name 'world.txt','hello.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when list of assets is returned from a subdirectory with backslashes'{
    GivenSession
    GivenAssets -name '\world\world.txt','\world\hello.txt' -Directory '\hello\'
    WhenAssetIsRequested -subdirectory 'world'
    ThenListShouldBeReturned -name 'world.txt','hello.txt'
    ThenNoErrorShouldBeThrown
}
