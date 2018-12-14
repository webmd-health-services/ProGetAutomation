
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$result = $null
$session = New-ProGetTestSession
$feedName = $PSCommandPath | Split-Path -Leaf
$content = $null
$upackFile = $null

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

    $packFilePath = Join-Path -Path $TestDrive.FullName -ChildPath ('{0}-{1}.upack.zip' -f $Name,$Version)
    $script:upackFile = New-ProGetUniversalPackage -OutFile $packFilePath -Version $Version -Name $Name -Title $Name -Description ('--description=ProGetAutomation test package for {0}' -f ($PSCommandPath | Split-Path -Leaf))
    Get-ChildItem -Path $TestDrive.FullName |
        Where-Object { $_.Extension -ne '.zip' } |
        Add-ProGetUniversalPackageFile -PackagePath $upackFile.FullName -BasePath $TestDrive.FullName
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $upackFile.FullName
}

function Init
{
    $script:content = $null
    $script:result = $null
    $script:upackFile = $null

    Get-ProGetFeed -Session $Session -Name $feedName | Remove-ProGetFeed -Session $Session -Force
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
    WhenReadingFile 'MyPackage' 'package\file' '1.0.0'
    ThenContentIs 'content'
}

Describe 'Read-ProGetUniversalPackageFile.when getting file from latest version of a package' {
    Init
    GivenPackage 'MyPackage' '1.0.0' @{ 'file' = '1.0.0' }
    GivenPackage 'MyPackage' '1.0.1' @{ 'file' = '1.0.1' }
    WhenReadingFile 'MyPackage' 'package\file'
    ThenContentIs '1.0.1'
}

Describe 'Read-ProGetUniversalPackageFile.when reading upack.json' {
    Init
    GivenPackage 'MyPackage' '1.0.1' @{ 'file' = '1.0.1' }
    WhenReadingFile 'MyPackage' 'upack.json'
    $expandPath = Join-Path -Path $TestDrive.FullName -ChildPath ('upack.{0}' -f [IO.Path]::GetRandomFileName())
    Expand-Archive -Path $upackFile -DestinationPath $expandPath
    ThenContentIs (Get-Content -Path (Join-Path -Path $expandPath -ChildPath 'upack.json') -Raw)
}
