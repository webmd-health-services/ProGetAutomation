& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)


function Init
{
    $script:fileName = $Null
    $script:progetAssetName = $Null
    $script:proGetAssetDirectory = 'versions'
    $script:directory = $Null
    $script:filePath = $Null
}

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
    $script:proGetAssetName = $Name
    New-Item -Path (Join-Path -Path $TestDrive.FullName -ChildPath $FilePath) -ItemType 'File' -Force
    $script:proGetAssetDirectory = $directory
    $script:filePath = (Join-Path -Path $TestDrive.FullName -ChildPath $FilePath)
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
    $script:proGetAssetName = $Name
    $script:proGetAssetDirectory = $directory
    $script:filePath = $FilePath

}
function GivenSubDirectory
{
    param(
        [string]
        $Name
    )
    $script:directory = $Name
    New-Item -Path (Join-Path -Path $TestDrive.FullName -ChildPath $Name) -ItemType 'Directory' -Force
}
function GivenAssetThatDoesntExist
{
    param(
        [string]
        $Name
    )
    $script:proGetAssetName = $Name
    $script:proGetAssetDirectory = $null
}

function WhenAssetIsUploaded
{
    $Global:Error.Clear()
    Set-ProGetAsset -Session $session -Name $proGetAssetName -Directory $proGetAssetDirectory -Path $filePath -ErrorAction SilentlyContinue
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
        Get-ProGetAsset -session $session -Directory $proGetAssetDirectory | Where-Object { $_.name -match $name } | should -not -BeNullOrEmpty
    }
}

function ThenAssetShouldNotExist
{
    param(
        [string]
        $Name
    )
    it ('should not contain the file {0}' -f $Name) {
        Get-ProGetAsset -session $session -Directory $proGetAssetDirectory | Where-Object { $_.name -match $name } | Should -BeNullOrEmpty
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

Describe 'Set-ProGetAsset.when Asset is uploaded correctly'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when exact path is given'{
    Init
    GivenSession
    GivenSubDirectory -Name 'dir'
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'dir/foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when Asset exists but proget directory does not exist'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'newdir' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenErrorShouldBeThrown -ExpectedError 'Asset Directory ''newDir'' does not exist, please create one using New-ProGetFeed with Name'
}

Describe 'Set-ProGetAsset.when file does not exist'{
    Init
    GivenSession
    GivenAssetWithoutFile -Name 'fubu.txt' -directory 'versions' -FilePath 'fubu.txt'
    WhenAssetIsUploaded
    ThenAssetShouldNotExist -Name 'fubu.txt' -directory 'versions'
    ThenErrorShouldBeThrown -ExpectedError 'Could Not find file named ''fubu.txt''. please pass in the correct path value'
}

Describe 'Set-ProGetAsset.when Asset already exists'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -directory 'versions' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

$assets = Get-ProGetAsset -Session $session -Directory $proGetAssetDirectory
foreach($asset in $assets)
{
    Remove-ProGetAsset -Session $session -Directory $proGetAssetDirectory -Name $asset.name
}