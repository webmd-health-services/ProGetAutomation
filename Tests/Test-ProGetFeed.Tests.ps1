
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
$result = $null

function Init
{
    $script:result = $null

    Get-ProGetFeed -Session $session | Remove-ProGetFeed -Session $session -Force
}

function GivenFeed
{
    param(
        $Name,
        $OfType
    )

    New-ProGetFeed -Session $session -Name $Name -Type $OfType
}

function ThenFeedExists
{
    It ('should exist') {
        $result | Should -BeTrue
    }
}

function ThenFeedDoesNotExist
{
    It ('should not exist') {
        $result | Should -BeFalse
    }
}

function WhenTesting
{
    param(
        $Name,
        $OfType
    )

    $script:result = Test-ProGetFeed -Session $session -Name $Name -Type $OfType
}

Describe 'Test-ProGetFeed.when feed exists' {
    Init
    GivenFeed 'Fubar' -OfType 'Universal'
    WhenTesting 'Fubar' -OfType 'Universal'
    ThenFeedExists
}

Describe 'Test-ProGetFeed.when feed does not exist' {
    Init
    WhenTesting 'Fubar' -OfType 'Universal'
    ThenFeedDoesNotExist
}

Describe 'Test-ProGetFeed.when feed with a name exists but it''s type is different' {
    Init
    GivenFeed 'Fubar' -OfType 'Universal'
    WhenTesting 'Fubar' -OfType 'NuGet'
    ThenFeedDoesNotExist
}