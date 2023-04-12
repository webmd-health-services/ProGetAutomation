
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
$feedName = $PSCommandPath | Split-Path -Leaf

function Init
{
    Get-ProGetFeed -Session $session -Name $feedName -ErrorAction Ignore | Remove-ProGetFeed -Session $session -Force
    New-ProGetFeed -Session $session -Name $feedName -Type 'Universal'
}

Describe 'Invoke-ProGetNativeApiMethod.when making a GET request' {
    Init
    # This failed in early versions of the module.
    $Global:Error.Clear()
    It 'should not throw an error' {
        { Invoke-ProGetNativeApiMethod -Session $session -Name 'Feeds_GetFeed' } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

}

Describe 'Invoke-ProGetNativeApiMethod.when using WhatIf' {
    Init
    $feed = Get-ProGetFeed -Session $Session -Name $feedName

    Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_DeleteFeed' -Parameter @{ Feed_Name = $feed.name } -WhatIf

    It ('should not make web request') {
        Get-ProGetFeed -Session $Session -Name $feedName | Should -Not -BeNullOrEmpty
    }
}