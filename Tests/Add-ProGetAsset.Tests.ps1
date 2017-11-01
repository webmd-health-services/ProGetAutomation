& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

function GivenSession {
    $uri = 'http://localhost:82/'
    $uName = 'Admin'
    $PWord = 'Admin'
    $credential = New-Credential -UserName $uName -Password $PWord
    $script:session = New-ProGetSession -Uri $uri -Credential $credential
    #$script:session = New-ProGetTestSession
}
function GivenAsset {
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
function GivenSubDirectory {
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
    it ('should not contain the file {0}' -f $Name){
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
    if( $filePath ){
        Remove-Item -Path $filePath -Force
    }
    if( $directory ){
        Remove-Item -Path $directory -Recurse -force
    }
    Remove-ProGetAsset -Session $session -AssetDirectory $script:progetAssetDirectory -AssetName $script:progetAssetName
    $script:fileName = $Null
    $script:progetAssetName = $Null
    $script:progetAssetDirectory = $Null
    $script:directory = $null
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
    GivenAsset -Name 'foo.txt' -directory 'baddir' -FilePath 'foo.txt'
    WhenAssetIsUploaded
    ThenAssetShouldNotExist -Name 'foo.txt' -directory 'baddir'
    ThenErrorShouldBeThrown -ExpectedError 'The remote server returned an error'
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
