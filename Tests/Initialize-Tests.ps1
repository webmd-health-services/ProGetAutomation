

& (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve) -Verbose:$false

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ProGetAutomationTest') -Force -Verbose:$false

Assert-ProGetActivated
