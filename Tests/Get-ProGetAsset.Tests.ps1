& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$script:progetAssetDirectory = 'versions'

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $feed = Test-ProGetFeed -Session $session -FeedName 'versions' -FeedType 'Asset'
    if( !$feed )
    {
        New-ProGetFeed -Session $session -FeedName 'versions' -FeedType 'Asset'
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
        New-Item -Path $file -Type 'file' -value $WithContent 
        Set-ProGetAsset -Session $session -Directory $progetAssetDirectory -Name $file -Path $file
        Remove-Item -Path $file -Force
    }
}

function WhenAssetIsRequested
{
    param(
        [string]
        $Name
    )
    $Global:Error.Clear()
    $script:asset = Get-ProGetAsset -Session $session -Directory $progetAssetDirectory -Name $name -ErrorAction SilentlyContinue
}

function ThenListShouldBeReturned
{
    param(
        [string[]]
        $Name
    )
    foreach($file in $Name)
    {
        it ('should return a file name that matches ''{0}''' -f $file){
            $asset | Where-Object {$_.name -match $file } | Should -not -BeNullOrEmpty
        }
    }

}

function ThenListShouldBeEmpty
{
    it 'should return a list that is empty' {
        $asset | Should -BeNullOrEmpty
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
    GivenAssets -name 'foo','bar'
    WhenAssetIsRequested
    ThenListShouldBeReturned -name 'foo','bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when using wildcard'{
    GivenSession
    GivenAssets -name 'foo','foobar'
    WhenAssetIsRequested -name 'foo*'
    ThenListShouldBeReturned -name 'foo','foobar'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when single asset is returned'{
    GivenSession
    GivenAssets -name 'foo.txt' -WithContent 'test'
    WhenAssetIsRequested -name 'foo.txt'
    ThenListShouldBeReturned -name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Get-ProGetAsset.when asset is requested but does not exist'{
    GivenSession
    GivenAssets -name 'foo' -withContent 'test content'
    WhenAssetIsRequested -Name 'fubu'
    ThenNoErrorShouldBeThrown
    ThenListShouldBeEmpty
}

$script:asset = Get-ProGetAsset -Session $session -Directory $progetAssetDirectory
foreach($file in $asset)
{
    Remove-ProGetAsset -Session $session -Directory $progetAssetDirectory -Name $file.name
}
