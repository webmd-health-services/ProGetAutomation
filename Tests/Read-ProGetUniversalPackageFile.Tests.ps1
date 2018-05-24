
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$result = $null
$session = New-ProGetTestSession
$feedName = $PSCommandPath | Split-Path -Leaf
$content = $null

function GivenPackage
{
    param(
        $Name,
        $Version,
        $Content
    )

    $packageRoot = $TestDrive.FullName
    foreach( $filename in $Content.Keys )
    {
        $filePath = Join-Path -Path $packageRoot -ChildPath $filename
        [IO.File]::WriteAllText( $filePath, $Content[$filename] )
    }

    & (Join-Path -Path $PSScriptRoot -ChildPath 'upack.exe' -Resolve) 'pack' $TestDrive.FullName ('--targetDirectory={0}' -f $TestDrive.FullName) --name=$Name --version=$Version --title=$Name ('--description=ProGetAutomation test package for {0}' -f ($PSCommandPath | Split-Path -Leaf))
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath (Join-Path -Path $TestDrive.FullName -ChildPath ('{0}-{1}.upack' -f $Name,$Version))
}

function Init
{
    $script:content = $null
    $script:result = $null

    Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_GetFeed' -Parameter @{ 'Feed_Name' = $feedName } |
        Where-Object { $_ } |
        ForEach-Object { Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_DeleteFeed' -Parameter @{ 'Feed_Id' = $_.Feed_Id } }
    New-ProGetFeed -Session $session -FeedName $feedName -FeedType ProGet
}

function ThenContentIs
{
    param(
        $ExpectedContent
    )

    It ('should read file content') {
        $content | Should -Be $ExpectedContent
    }
}

function WhenReadingFile
{
    param(
        $PackageName,
        $Path,
        $Version
    )

    $optionalParams = @{ }
    if( $Version )
    {
        $optionalParams['Version'] = $Version
    }

    $script:content = Read-ProGetUniversalPackageFile -Session $session -FeedName $feedName -Name $PackageName @optionalParams -Path $Path
}

Describe 'Read-ProGetUniversalPackageFile.when getting file from specific version of a package' {
    Init
    GivenPackage 'MyPackage' '1.0.0' @{ 'file' = 'content' }
    WhenReadingFile 'MyPackage' 'package/file' '1.0.0'
    ThenContentIs 'content'
}

Describe 'Read-ProGetUniversalPackageFile.when getting file from latest version of a package' {
    Init
    GivenPackage 'MyPackage' '1.0.0' @{ 'file' = '1.0.0' }
    GivenPackage 'MyPackage' '1.0.1' @{ 'file' = '1.0.1' }
    WhenReadingFile 'MyPackage' 'package/file'
    ThenContentIs '1.0.1'
}

Describe 'Read-ProGetUniversalPackageFile.when reading upack.json' {
    Init
    GivenPackage 'MyPackage' '1.0.1' @{ 'file' = '1.0.1' }
    WhenReadingFile 'MyPackage' 'upack.json'
    ThenContentIs '{
  "name": "MyPackage",
  "version": "1.0.1",
  "title": "MyPackage",
  "description": "ProGetAutomation test package for Read-ProGetUniversalPackageFile.Tests.ps1"
}'
}
