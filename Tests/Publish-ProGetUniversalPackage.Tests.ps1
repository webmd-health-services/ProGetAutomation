
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:packagePath = Join-Path -Path $PSScriptRoot -ChildPath '.\UniversalPackageTest-0.1.1.upack'
    $script:packageName = 'UniversalPackageTest'
    $script:feedName = 'Publish-ProGetUniversalPackage.Tests.ps1'

    $script:session = New-ProGetTestSession
    New-ProGetFeed -Session $script:session -Type 'Universal' -Name $script:feedName -ErrorAction Ignore

    function ThenError
    {
        param(
            [int] $AtIndex,

            [String] $MatchesPattern
        )

        $errToTest = $Global:Error
        if ($PSBoundParameters.ContainsKey('AtIndex'))
        {
            $errToTest = $Global:Error[$AtIndex]
        }
        $errToTest | Should -Match $MatchesPattern
    }

    function ThenPackage
    {
        param(
            [switch] $Not,

            [switch] $Published
        )

        $pkg = Get-ProGetUniversalPackage -Session $script:session `
                                          -FeedName $script:feedName `
                                          -Name $script:packageName `
                                          -ErrorAction Ignore

        if ($Not)
        {
            $pkg | Should -BeNullOrEmpty
            $Global:Error | Should -Not -BeNullOrEmpty
        }
        else
        {
            $pkg | Should -Not -BeNullOrEmpty
            $Global:Error | Should -BeNullOrEmpty
        }
    }

    function WhenPublishing
    {
        [CmdletBinding()]
        param(
            [hashtable] $WithArgs = @{}
        )

        if (-not $WithArgs.ContainsKey('Session'))
        {
            $WithArgs['Session'] = $script:session
        }

        if (-not $WithArgs.ContainsKey('PackagePath'))
        {
            $WithArgs['PackagePath'] = $script:packagePath
        }

        if (-not $WithArgs.ContainsKey('FeedName'))
        {
            $WithArgs['FeedName'] = $script:feedName
        }

        Publish-ProGetUniversalPackage @WithArgs
    }
}

Describe 'Publish-ProGetUniversalPackage.publish a new Universal package' {
    BeforeEach {
        $Global:Error.Clear()
        # Remove all packages from target ProGet feed
        Get-ProGetUniversalPackage -Session $script:session -Feedname $script:feedName |
            ForEach-Object {
                foreach ($version in $_.versions)
                {
                    Remove-ProGetUniversalPackage -Session $script:session `
                                                  -FeedName $script:feedName `
                                                  -Name $_.name `
                                                  -Version $version
                }
            }
    }

    It 'publishes universal packages' {
        WhenPublishing
        ThenPackage -Published
    }

    It 'not replace existing package' {
        WhenPublishing
        ThenPackage -Published

        WhenPublishing -ErrorAction SilentlyContinue
        ThenError -MatchesPattern 'already exists'
    }

    It 'should replace existing package' {
        WhenPublishing
        ThenPackage -Published

        WhenPublishing -WithArgs @{ Force = $true }
        ThenPackage -Published
    }

    It 'sends credentials' {
        $session = New-ProGettestSession -ExcludeApiKey
        WhenPublishing -WithArgs @{ Session = $session }
        ThenPackage -Published
    }

    It 'sends API key' {
        $session = New-ProGettestSession -ExcludeCredential
        WhenPublishing -WithArgs @{ Session = $session }
        ThenPackage -Published
    }

    It 'does not publish to a non-existent feed' {
        WhenPublishing -WithArgs @{ FeedName = 'invalidFeedName' } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -AtIndex 0 -Matches 'Failed to upload'
    }

    It 'validates package file exists' {
        $packagePath = '.\BadPackagePath'
        WhenPublishing -WithArgs @{ PackagePath = $packagePath } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -Matches 'does not exist'
    }

    It 'validates package is a ZIP file' {
        WhenPublishing -WithArgs @{ PackagePath = $PSCommandPath } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -AtIndex 0 -Matches 'isn''t a valid ZIP file'
    }

    It 'validates upackJson file' {
        $packagePath = Join-Path -Path $PSScriptRoot -ChildPath 'UniversalInvalidUpackJson.upack'
        WhenPublishing -WithArgs @{ PackagePath = $packagePath } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -AtIndex 0 -Matches 'must be a valid JSON file'
    }

    It 'validates upackJson file exists' {
        $packagePath = Join-Path -Path $PSScriptRoot -ChildPath 'UniversalNoUpackJson.upack'
        WhenPublishing -WithArgs @{ PackagePath = $packagePath } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -Matches 'must contain a upack\.json'
    }

    It 'validates upackJson file contais name and description' {
        $packagePath = Join-Path -Path $PSScriptRoot -ChildPath 'UniversalUpackJsonMissingNameAndVersion.upack'
        WhenPublishing -WithArgs @{ PackagePath = $packagePath } -ErrorAction SilentlyContinue
        ThenPackage -Not -Published
        ThenError -Matches '''name'' and ''version'''
    }
}