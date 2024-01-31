
#Requires -Version 4
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    function GivenSession
    {
        $script:session = New-ProGetTestSession
        $script:baseDirectory = (split-path -Path $TestDrive -leaf)
        $feed = Test-ProGetFeed -Session $session -Name $baseDirectory
        if( !$feed )
        {
            New-ProGetFeed -Session $session -Name $baseDirectory -Type 'Asset'
        }
    }

    function GivenAsset
    {
        param(
            [string]
            $Name,

            [string]
            $WithContent
        )

        Set-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Name -Content $WithContent
    }

    function WhenContentIsRequested
    {
        [CmdletBinding()]
        param(
            [string]
            $Subdirectory
        )
        $Global:Error.Clear()
        $script:content = Get-ProGetAssetContent -Session $session -DirectoryName $baseDirectory -Path $Subdirectory
    }

    function ThenContent
    {
        param(
            [string]
            $Is,

            [Switch]
            $IsNull
        )

        if( $IsNull )
        {
            $content | Should -BeNullOrEmpty
        }
        else
        {
            $content | Should -Be $Is
        }
    }

    function ThenNoErrorShouldBeThrown
    {
        $Global:Error | Should -BeNullOrEmpty
    }

    function ThenError
    {
        [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
        param(
            $Matches
        )

        $Global:Error | Should -Match $Matches
    }
}

Describe 'Get-ProGetAssetContent' {
    It 'when content is plain text'{
        GivenSession
        GivenAsset 'foobar' -WithContent "snafu`nfizzbuzz"
        WhenContentIsRequested 'foobar'
        ThenContent -Is "snafu`nfizzbuzz"
        ThenNoErrorShouldBeThrown
    }

    It 'when content is JSON'{
        GivenSession
        GivenAsset 'foofoobar' -WithContent '{ "foofoobar": "snafu" }'
        WhenContentIsRequested 'foofoobar'
        ThenContent 'foofoobar' -Is '{ "foofoobar": "snafu" }'
        ThenNoErrorShouldBeThrown
    }

    It 'when asset does not exist' {
        GivenSession
        WhenContentIsRequested 'nothin' -ErrorAction SilentlyContinue
        ThenContent -IsNull
        ThenError -Matches 'The\ specified\ asset\ was\ not\ found'
    }

    It 'when asset is in a sub-directory'{
        GivenSession
        GivenAsset 'fubar/snafu/fizzbuzz.txt' -WithContent "snafu`nfizzbuzz"
        WhenContentIsRequested 'fubar/snafu/fizzbuzz.txt'
        ThenContent -Is "snafu`nfizzbuzz"
        ThenNoErrorShouldBeThrown
    }
}
