& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$Script:progetAssetDirectory = 'versions'

function GivenSession 
{
    $script:session = New-ProGetTestSession
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


function ThenNoErrorShouldBeThrown
{
    It 'should not throw an error' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function WhenAssetIsRemoved
{
    param(
        [string]
        $name
    )
    $Global:Error.Clear()
    Remove-ProGetAsset -Session $session -AssetName $name -AssetDirectory $progetAssetDirectory -ErrorAction SilentlyContinue
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
Describe 'Remove-ProGetAsset.When Asset is removed successfully'{
    GivenSession
    GivenAssets -Name 'foo'
    WhenAssetIsRemoved -name 'foo'
    ThenAssetShouldNotExist -Name 'foo'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When Asset does not exist' {
    GivenSession
    GivenAssets -Name 'foo'
    WhenAssetIsRemoved -Name 'foo'
    ThenAssetShouldNotExist -Name 'foo'
    ThenNoErrorShouldBeThrown
}

Describe 'Remove-ProGetAsset.When Asset is removed removed twice'{
    GivenSession
    GivenAssets -Name 'foo'
    WhenAssetIsRemoved -Name 'foo'
    WhenAssetIsRemoved -Name 'foo'
    ThenAssetShouldNotExist -Name 'foo'
    ThenNoErrorShouldBeThrown
}
