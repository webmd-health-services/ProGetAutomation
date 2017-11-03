& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $feed = Test-ProGetFeed -Session $session -FeedName 'versions' -FeedType 'Asset'
    if( !$feed )
    {
        New-ProGetFeed -Session $session -FeedName 'versions' -FeedType 'Asset'
    }
}

function GivenAsset
{
    param(
        [string]
        $Name,
        [string]
        $directory,
        [string]
        $FilePath
    )
    $script:progetAssetName = $Name
    new-item $FilePath -type 'file' -value 'test' -Force
    $script:progetAssetDirectory = $directory
    $script:filePath = $FilePath
}

function GivenAssetWithoutFile
{
    param(
        [string]
        $Name,
        [string]
        $directory,
        [string]
        $FilePath
    )
    $script:progetAssetName = $Name
    $script:progetAssetDirectory = $directory
    $script:filePath = $FilePath

}
function GivenSubDirectory
{
    param(
        [string]
        $Name
    )
    $script:directory = $Name
    New-item -Path $name -type 'directory' -Force
}
function GivenAssetThatDoesntExist
{
    param(
        [string]
        $Name
    )
    $script:progetAssetName = $Name
    $script:progetAssetDirectory = $null
}

function WhenAssetIsUploaded
{
    $Global:Error.Clear()
    Add-ProGetAsset -Session $session -AssetName $progetAssetName -AssetDirectory $progetAssetDirectory -fileName $filePath -ErrorAction SilentlyContinue
}

function ThenDirectoryShouldBeCreated
{
    param(
        [string]
        $name
    )
    it ('should have created a asset directory named ''{0}''' -f $name) {
        Test-ProGetFeed -Session $session -FeedName $name -FeedType 'Asset' | should -be $true
    }
}

function ThenAssetShouldExist
{
    param(
        [string]
        $Name
    )
    it ('should contain the file {0}' -f $Name) {
        Get-ProGetAsset -session $session -AssetDirectory $progetAssetDirectory | Where-Object { $_.name -match $name } | should -not -BeNullOrEmpty
    }
}

function ThenAssetShouldNotExist
{
    param(
        [string]
        $Name
    )
    it ('should not contain the file {0}' -f $Name) {
        Get-ProGetAsset -session $session -AssetDirectory $progetAssetDirectory | Where-Object { $_.name -match $name } | should -BeNullOrEmpty
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

function ThenNoErrorShouldBeThrown
{
    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function cleanup
{
    if( Test-Path -path $filePath )
    {
        Remove-Item -Path $filePath -Force
    }
    if( $directory )
    {
        Remove-Item -Path $directory -Recurse -force
    }
    $assets = Get-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory
    foreach($asset in $assets)
    {
        Remove-ProGetAsset -Session $session -AssetDirectory $progetAssetDirectory -AssetName $asset.name
    }
    $script:fileName = $Null
    $script:progetAssetName = $Null
    $script:progetAssetDirectory = 'versions'
    $script:directory = $Null
    $script:filePath = $Null
}

Describe 'Add-ProGetAsset.when Asset is uploaded correctly'{
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
    cleanup
}

Describe 'Add-ProGetAsset.when exact path is given'{
    GivenSession
    GivenSubDirectory -Name 'dir'
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'dir/foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
    cleanup
}

Describe 'Add-ProGetAsset.when Asset exists but proget directory does not exist'{
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'newdir' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenDirectoryShouldBeCreated -name 'newdir'
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
    cleanup
}

Describe 'Add-ProGetAsset.when file does not exist'{
    GivenSession
    GivenAssetWithoutFile -Name 'foo.txt' -directory 'versions' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldNotExist -Name 'foo.txt' -directory 'versions'
    ThenErrorShouldBeThrown -ExpectedError 'Could Not find file named ''foo.txt''. please pass in the correct path value'
    cleanup
}

Describe 'Add-ProGetAsset.when Asset already exists'{
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
    cleanup
}
