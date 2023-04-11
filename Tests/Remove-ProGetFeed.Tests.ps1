
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)
}

Describe 'Remove-ProGetFeed' {
    It 'supports WhatIf' {
        $feedName = $PSCommandPath | Split-Path -Leaf
        $session = New-ProGetTestSession
        Get-ProGetFeed -Session $session -Name $feedName -ErrorAction Ignore |
            Remove-ProGetFeed -Session $session -Force
        New-ProGetFeed -Session $session -Name $feedName -Type 'Universal'
        $feed = Get-ProGetFeed -Session $session -Name $feedName
        Remove-ProGetFeed -Session $session -Name $feed.name -WhatIf
        Get-ProGetFeed -Session $session -Name $feedName | Should -Not -BeNullOrEmpty
        Remove-ProGetFeed -Session $session -Name $feed.name -WhatIf -Force
        Get-ProGetFeed -Session $session -Name $feedName | Should -Not -BeNullOrEmpty
    }
}