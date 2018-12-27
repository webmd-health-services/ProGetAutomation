& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $script:baseDirectory = (split-path -Path $TestDrive.FullName -leaf)
    $feed = Test-ProGetFeed -Session $session -Name $baseDirectory -Type 'Asset'
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
        New-Item -Path (Join-Path -Path $TestDrive.FullName -ChildPath $file) -Type 'file' -value $WithContent -Force 
        Set-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $file -FilePath (Join-Path -Path $TestDrive.FullName -ChildPath $file)
    }
}

function WhenAssetIsRemoved
{
    param(
        [string]
        $Filter,
        [string]
        $Subdirectory
    )
    $Global:Error.Clear()
    Remove-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Subdirectory -Filter $Filter -ErrorAction SilentlyContinue
}

function ThenNoErrorShouldBeThrown
{
    It 'should not throw an error' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function ThenAssetShouldExist
{
    param(
        [string[]]
        $Name,
        [string]
        $directory
    )
    foreach($file in $Name)
    {
        it ('should contain the file {0}' -f $file) {
            Get-ProGetAsset -session $session -DirectoryName $baseDirectory -Path $directory | Where-Object { $_.name -match $file } | should -not -BeNullOrEmpty
        }
    }
}

function ThenAssetShouldNotExist
{
    param(
        [string[]]
        $Name,
        [string]
        $directory
    )
    foreach($file in $Name)
    {
        it ('should not contain the file {0}' -f $file) {
            Get-ProGetAsset -session $session -DirectoryName $baseDirectory -Path $directory | Where-Object { $_.name -match $file } | should -BeNullOrEmpty
        }
    }
}
Describe 'Remove-ProGetAsset.When Asset is removed successfully'{
    GivenSession
    GivenAssets -Name 'foo','bar'
    WhenAssetIsRemoved -filter 'foo'
    ThenAssetShouldNotExist -Name 'foo'
    ThenAssetShouldExist -Name 'bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When Asset is removed from a subdirectory successfully'{
    GivenSession
    GivenAssets -Name 'bar/foo'
    WhenAssetIsRemoved -filter 'foo' -Subdirectory 'bar'
    ThenAssetShouldNotExist -Name 'foo' -directory 'bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When multiple Assets are removed successfully'{
    GivenSession
    GivenAssets -Name 'foo','bar'
    WhenAssetIsRemoved
    ThenAssetShouldNotExist -Name 'foo','bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When filtered assets are removed successfully'{
    GivenSession
    GivenAssets -Name 'foo','bar','foobar'
    WhenAssetIsRemoved -Filter 'foo*'
    ThenAssetShouldNotExist -Name 'foo','foobar'
    ThenAssetShouldExist -Name 'bar'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When Asset does not exist' {
    GivenSession
    GivenAssets -Name 'foo'
    WhenAssetIsRemoved -Filter 'bar'
    ThenAssetShouldNotExist -Name 'bar'
    ThenAssetShouldExist -Name 'foo'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When Asset is removed removed twice'{
    GivenSession
    GivenAssets -Name 'foo'
    WhenAssetIsRemoved -Filter 'foo'
    WhenAssetIsRemoved -Filter 'foo'
    ThenAssetShouldNotExist -Name 'foo'
    ThenNoErrorShouldBeThrown
}

