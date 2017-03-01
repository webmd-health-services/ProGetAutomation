[CmdletBinding()]
param(
)

#Requires -Version 4
Set-StrictMode -Version 'Latest'

foreach( $moduleName in @( 'Pester', 'Carbon' ) )
{
    if( (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $moduleName) -PathType Container) )
    {
        break
    }

    Save-Module -Name $moduleName -Path '.' 
}
