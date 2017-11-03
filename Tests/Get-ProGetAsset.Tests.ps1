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
        Add-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory -AssetName $file -fileName $file
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
    $script:asset = Get-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory -AssetName $name -ErrorAction SilentlyContinue
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
            $asset | Where-Object {$_.name -match $file } 
        }
    }

}

function ThenContentShouldBeReturned
{
    param(
        [string]
        $WithContent
    )
    it ('should return content that matches ''{0}''' -f $WithContent){
        $asset | Should -Match $WithContent 
    }
}

function ThenNoErrorShouldBeThrown
{
    It 'should not throw an error' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function ThenErrorShouldBeThrown
{
    param(
        [string]
        $ExpectedError
    )
    It ('should write an error that matches ''{0}''' -f $ExpectedError) {
        $Global:Error | Where-Object { $_ -match $ExpectedError } | Should -not -BeNullOrEmpty
    }
}

function cleanup
{
    $script:asset = Get-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory
    foreach($file in $asset)
    {
        Remove-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory -AssetName $file.name
    }
    $script:asset = $null
}
Describe 'Get-ProGetAsset.when list of assets is returned'{
    GivenSession
    GivenAssets -name 'foo','bar'
    WhenAssetIsRequested
    ThenListShouldBeReturned -name 'foo','bar'
    ThenNoErrorShouldBeThrown
    cleanup
}

Describe 'Get-ProGetAsset.when single asset is returned'{
    GivenSession
    GivenAssets -name 'foo.txt' -withContent 'test content'
    WhenAssetIsRequested -name 'foo.txt'
    ThenContentShouldBeReturned -withContent 'test content'
    ThenNoErrorShouldBeThrown
    cleanup
}

Describe 'Get-ProGetAsset.when asset is requested but does not exist'{
    GivenSession
    GivenAssets -name 'foo' -withContent 'test content'
    WhenAssetIsRequested -Name 'bar'
    ThenErrorShouldBeThrown -ExpectedError 'The specified asset was not found.'
    cleanup
}
