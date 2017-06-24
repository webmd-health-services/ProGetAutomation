
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession

Describe 'Invoke-ProGetNativeApiMethod.when making a GET request' {
    
    New-ProGetFeed -Session $session -FeedName 'Fubar' -FeedType 'ProGet' -ErrorAction Ignore

    # This failed in early versions of the module.
    $Global:Error.Clear()
    It 'should not throw an error' {
        { Invoke-ProGetNativeApiMethod -Session $session -Name 'Feeds_GetFeed' } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

}