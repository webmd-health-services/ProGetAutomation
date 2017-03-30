[CmdletBinding()]
param(
)

& (Join-Path -Path $PSScriptRoot -ChildPath 'init.ps1' -Resolve)

# Allow ProGet web service to load prior to initiating test suite 
Start-Sleep -Seconds 10

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Pester' -Resolve) -Force -Verbose:$false

$outputdir = Join-Path -Path $PSScriptRoot -ChildPath '.output'

New-Item -Path $outputdir -ItemType 'Directory' -ErrorAction Ignore
Get-ChildItem -Path $outputdir | Remove-Item -Recurse -Force

$outputFile = Join-Path -Path $outputdir -ChildPath 'pester.xml'
$result = Invoke-Pester -Script (Join-Path -Path $PSScriptRoot -ChildPath 'Tests\*.Tests.ps1') `
                        -OutputFile $outputFile `
                        -OutputFormat NUnitXml `
                        -PassThru

if( (Test-Path -Path 'env:APPVEYOR') -and (Test-Path -Path $outputFile) )
{
    $wc = New-Object 'System.Net.WebClient'
    $wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $outputFile)
}

exit $result.FailedCount