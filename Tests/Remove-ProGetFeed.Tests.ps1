
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

Describe 'Remove-ProGetFeed.when using WhatIf switch' {
    $feedName = $PSCommandPath | Split-Path -Leaf
    $session = New-ProGetTestSession
    Get-ProGetFeed -Session $session -Name $feedName | Remove-ProGetFeed -Session $session -Force
    New-ProGetFeed -Session $session -Name $feedName -Type 'ProGet'
    $feed = Get-ProGetFeed -Session $session -Name $feedName
    Remove-ProGetFeed -Session $session -ID $feed.Feed_Id -WhatIf
    It ('should not delete the feed') {
        Get-ProGetFeed -Session $session -Name $feedName | Should -Not -BeNullOrEmpty
    }

    Remove-ProGetFeed -Session $session -ID $feed.Feed_Id -WhatIf -Force
    It ('should not delete the feed even when using the Force') {
        Get-ProGetFeed -Session $session -Name $feedName | Should -Not -BeNullOrEmpty
    }
}