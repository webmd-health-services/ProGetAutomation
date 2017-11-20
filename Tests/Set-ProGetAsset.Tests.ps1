& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)


function Init
{
    $script:fileName = $Null
    $script:progetAssetName = $Null
    $script:baseDirectory = (split-path -Path $TestDrive.FullName -leaf)
    $script:directory = $Null
    $script:filePath = $Null
}

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $feed = Test-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
    if( !$feed )
    {
        New-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
    }
}

function GivenAsset
{
    param(
        [string]
        $Name,
        [string]
        $RootDirectory,
        [string]
        $FilePath
    )
    $script:proGetAssetName = $Name
    New-Item -Path (Join-Path -Path $TestDrive.FullName -ChildPath $FilePath) -ItemType 'File' -Force
    if($RootDirectory)
    {
        $script:baseDirectory = $RootDirectory
    }
    $script:filePath = (Join-Path -Path $TestDrive.FullName -ChildPath $FilePath)
}

function GivenAssetWithoutFile
{
    param(
        [string]
        $Name,
        [string]
        $FilePath
    )
    $script:proGetAssetName = $Name
    $script:filePath = $FilePath

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
    Set-ProGetAsset -Session $session -Path $proGetAssetName -DirectoryName $baseDirectory -FilePath $filePath -ErrorAction SilentlyContinue
}

function ThenAssetShouldExist
{
    param(
        [string]
        $Name,
        [string]
        $directory
    )
    it ('should contain the file {0}' -f $Name) {
        Get-ProGetAsset -session $session -DirectoryName $baseDirectory -Path $directory | Where-Object { $_.name -match $name } | should -not -BeNullOrEmpty
    }
}

function ThenAssetShouldNotExist
{
    param(
        [string]
        $Name,
        [string]
        $directory
    )
    it ('should contain the file {0}' -f $Name) {
        Get-ProGetAsset -session $session -DirectoryName $baseDirectory -Path $directory | Where-Object { $_.name -match $name } | should -BeNullOrEmpty
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
    GivenAsset -Name 'foo.txt' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt' -directory ''
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when Asset is uploaded correctly in subfolder'{
    Init
    GivenSession
    GivenAsset -Name 'subdir/foo.txt' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt' -directory 'subdir'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when Asset is uploaded correctly in subfolder with backslashes'{
    Init
    GivenSession
    GivenAsset -Name '\subdir\foo.txt' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt' -directory 'subdir'
    ThenNoErrorShouldBeThrown
}


Describe 'Set-ProGetAsset.when exact path is given'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -FilePath 'dir/foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when Asset exists but proget directory does not exist'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -RootDirectory 'badDir' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenErrorShouldBeThrown -ExpectedError 'The remote server returned an error:'
}

Describe 'Set-ProGetAsset.when file does not exist'{
    Init
    GivenSession
    GivenAssetWithoutFile -Name 'fubu.txt' -FilePath 'fubu.txt'
    WhenAssetIsUploaded
    ThenAssetShouldNotExist -Name 'fubu.txt' -directory 'versions'
    ThenErrorShouldBeThrown -ExpectedError 'Could Not find file named ''fubu.txt''. please pass in the correct path value'
}

Describe 'Set-ProGetAsset.when Asset already exists'{
    Init
    GivenSession
    GivenAsset -Name 'foo.txt' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    WhenAssetIsUploaded
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}