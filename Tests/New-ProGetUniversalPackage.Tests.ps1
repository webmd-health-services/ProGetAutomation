
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve)

    $script:packageInfo = $null
    $script:testDir = $null
    $script:testNum = 0

    $edition = ''
    if( $PSVersionTable.ContainsKey('PSEdition') )
    {
        $edition = '; {0}' -f $PSVersionTable.PSEdition
    }
    $expectedCreatedBy = 'ProGetAutomation/{0} (PowerShell {1}{2})' -f (Get-Module -Name 'ProGetAutomation').Version,$PSVersionTable.PSVersion,$edition

    function GivenFile
    {
        param(
            [string[]]
            $Path
        )

        foreach( $pathItem in $Path )
        {
            $fullPath = Join-Path -Path $script:testDir -ChildPath $pathItem

            $parentDir = $fullPath | Split-Path
            if( -not (Test-Path -Path $parentDir -PathType Container) )
            {
                New-Item -Path $parentDir -ItemType 'Directory'
            }

            if( -not (Test-Path -Path $fullPath -PathType Leaf) )
            {
                New-Item -Path $fullPath -ItemType 'File'
            }
        }
    }

    function ThenError
    {
        [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
        param(
            $Matches
        )

        $Global:Error | Should -Match $Matches
    }

    function ThenPackage
    {
        param(
            [hashtable]
            $HasMetadata
        )

        $packageInfo | Should -Exist

        $packageExpandPath =
            Join-Path -Path $script:testDir -ChildPath ('upack.{0}.zip' -f [IO.Path]::GetRandomFileName())
        Expand-Archive -Path $packageInfo.FullName -DestinationPath $packageExpandPath

        $upackJsonPath = Join-Path -Path $packageExpandPath -ChildPath 'upack.json'
        $upackJsonPath | Should -Exist
        $upackJson = Get-Content -Path $upackJsonPath -Raw | ConvertFrom-Json
        if( -not $HasMetadata.ContainsKey('createdDate') )
        {
            $HasMetadata['createdDate'] = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:*.*Z')
        }
        if( -not $HasMetadata.ContainsKey('createdUsing') )
        {
            $HasMetadata['createdUsing'] = $expectedCreatedBy
        }
        $parameterToPropertyMap = @{
                                        'groupName' = 'group';
                                        'dependency' = 'dependencies';
                                        'author' = 'createdBy';
                                        'reason' = 'createdReason';
                                        'tag' = 'tags';
                                }
        foreach( $key in $HasMetadata.Keys )
        {
            $propertyName = $key
            if( $parameterToPropertyMap.ContainsKey($propertyName) )
            {
                $propertyName = $parameterToPropertyMap[$propertyName]
            }
            $member = $upackJson | Get-Member -Name $propertyName
            $member | Should -Not -BeNullOrEmpty -Because ('needs {0} property' -f $propertyName)
            $member.Name | Should -BeExactly $propertyName
            $value = $upackJson.$propertyName
            if( $value -is [object[]] )
            {
                $value | Should -Be $HasMetadata[$key]
            }
            else
            {
                if ($value -is [DateTime])
                {
                    $value = $value.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                }
                $value | Should -BeLike $HasMetadata[$key]
            }

        }
    }

    function ThenPackageNotCreated
    {
        param(
        )

        $packageInfo | Should -BeNullOrEmpty
    }

    function WhenPackaging
    {
        [CmdletBinding()]
        param(
            [hashtable]
            $WithParameters
        )

        $Global:Error.Clear()
        try
        {
            $outFilePath = Join-Path -Path $script:testDir -ChildPath 'test.upack.zip'
            $script:packageInfo = New-ProGetUniversalPackage @WithParameters -OutFile $outFilePath
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
    }
}

Describe 'New-ProGetUniversalPackage' {
    BeforeEach {
        $script:packageInfo = $null
        $script:testDir = Join-Path -Path $TestDrive -ChildPath ($script:testNum++)
        New-Item -Path $script:testDir -ItemType 'Directory'
    }

    It 'when packaging with minimum required metadata' {
        $metadata = @{ name = 'test' ; version = '0.0.0' }
        WhenPackaging -WithParameters $metadata
        ThenPackage -HasMetadata $metadata
    }

    It 'when packaging with all metadata' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        groupName = 'ProGetAutomation';
                        title = 'Test';
                        projectUri = 'https://github.com/webmd-health-services/ProGetAutomation';
                        iconUri = 'https://github.com/webmd-health-services/ProGetAutomation/icon.png';
                        description = 'A test package for New-ProGetUniversalPackage';
                        tag = @( 'one', 'two', 'three' );
                        dependency = @( 'package', 'package2' );
                        reason = 'To test New-ProGetUniversalPackage';
                        author = 'some person';
                    }
        WhenPackaging -WithParameters $metadata
        ThenPackage -HasMetadata $metadata
    }

    It 'when packaging with custom metadata' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        AdditionalMetadata = @{ '_fubar' = 'snafu' }
                    }
        WhenPackaging -WithParameters $metadata
        ThenPackage -HasMetadata @{ name = 'test' ; version = '0.0.0' ; '_fubar' = 'snafu' }
    }

    It 'when additional metadata contains parameters' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        AdditionalMetadata = @{ 'name' = 'snafu' ; 'createdUsing' = 'Blah'; 'createdDate' = 'blah' }
                    }
        WhenPackaging -WithParameters $metadata
        ThenPackage -HasMetadata @{ name = 'test' ; version = '0.0.0' ; 'createdUsing' = 'Blah'; 'createdDate' = 'blah' }
    }

    It 'when group name starts with a slash' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        groupName = '/snafu';
                    }
        WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
        ThenError -Matches 'does\ not\ match'
        ThenPackageNotCreated
    }

    It 'when group name ends with a slash' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        groupName = 'snafu/';
                    }
        WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
        ThenError -Matches 'does\ not\ match'
        ThenPackageNotCreated
    }

    It 'when group name contains invalid characters' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        groupName = 'snafu fubar';
                    }
        WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
        ThenError -Matches 'does\ not\ match'
        ThenPackageNotCreated
    }

    It 'when a tag contains invalid characters' {
        $metadata = @{
                        name = 'test' ;
                        version = '0.0.0';
                        tag = @( 'one', 'two three' );
                    }
        WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
        ThenError -Matches 'does\ not\ match'
        ThenPackageNotCreated
    }

    It 'when a name contains invalid characters' {
        $metadata = @{
                        name = 'test test' ;
                        version = '0.0.0';
                    }
        WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
        ThenError -Matches 'does\ not\ match'
        ThenPackageNotCreated
    }
}