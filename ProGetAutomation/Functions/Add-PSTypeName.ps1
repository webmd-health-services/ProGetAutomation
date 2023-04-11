# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Add-PSTypeName
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $InputObject,

        [Parameter(Mandatory, ParameterSetName='PackageInfo')]
        [switch] $PackageInfo,

        [Parameter(Mandatory, ParameterSetName='Native.Feed')]
        [switch] $NativeFeed,

        [Parameter(Mandatory, ParameterSetName='Feed')]
        [switch] $Feed
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $typeName = 'Inedo.ProGet.{0}' -f $PSCmdlet.ParameterSetName
        $InputObject.pstypenames.Add( $typeName )

        if ($PackageInfo)
        {
            if (-not ($InputObject | Get-Member -Name 'group'))
            {
                $InputObject | Add-Member -MemberType NoteProperty -Name 'group' -Value ''
            }
        }

        $InputObject
    }
}