
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
            [Parameter(Position=0)]
            [String] $Name,

            [Parameter(ParameterSetName='FromString')]
            [String] $WithContent,

            [Parameter(ParameterSetName='FromFile')]
            [String] $FromFile
        )

        $setArgs = @{}
        if ($WithContent)
        {
            $setArgs['Content'] = $WithContent
        }
        elseif ($FromFile)
        {
            $setArgs['FilePath'] = Join-Path -Path $PSScriptRoot -Child $FromFile -Resolve
        }

        Set-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Name @setArgs
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
            [Parameter(ParameterSetName='Is')]
            [String] $Is,

            [Parameter(ParameterSetName='IsNull')]
            [switch] $IsNull,

            [Parameter(ParameterSetName='IsBinary')]
            [String] $IsFile
        )

        if( $IsNull )
        {
            $content | Should -BeNullOrEmpty
        }
        elseif ($IsFile)
        {
            $script:content |
                Should -Be ([IO.File]::ReadAllBytes((Join-Path -Path $PSScriptRoot -ChildPath $IsFile -Resolve)))
        }
        else
        {
            $script:content | Should -Be $Is
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
        ThenContent -Is '{ "foofoobar": "snafu" }'
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

    It 'returns asset that''s a number' {
        GivenSession
        GivenAsset 'number' -WithContent (([Int32]::MaxValue) - 1)
        WhenContentIsRequested 'number'
        ThenContent -Is (([Int32]::MaxValue) - 1).ToString()
        ThenNoErrorShouldBeThrown
    }

    It 'gets JSON content as raw string' {
        GivenSession
        GivenAsset 'list.json' -WithContent '[ "one", "two", "three" ]'
        WhenContentIsRequested 'list.json'
        ThenContent -Is '[ "one", "two", "three" ]'
        ThenNoErrorShouldBeThrown
    }

    It 'gets binary content' {
        GivenSession
        GivenAsset 'boom.png' -FromFile 'boom.png'
        WhenContentIsRequested 'boom.png'
        ThenContent -IsFile 'boom.png'
    }
}
