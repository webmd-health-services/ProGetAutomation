

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\Modules\Carbon' -Resolve) -Verbose:$false
& (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve) -Verbose:$false

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ProGetAutomationTest') -Force -Verbose:$false
