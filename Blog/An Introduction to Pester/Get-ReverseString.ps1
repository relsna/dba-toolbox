
# New-Fixture -Path C:\temp -Name Get-ReverseString

function Get-ReverseString {
    param (
        [Parameter(Mandatory=$true)]$string
    )
    $reversed = $string.ToCharArray()
    [array]::Reverse($reversed)

    return -join($reversed)
    #return -join($reversed) + "_bug"
}
<#
function Get-Host {
    return $env:COMPUTERNAME
}
#>

# Get-ReverseString('Hello World!')
# Get-ReverseString 'PowerShell'
# Get-ReverseString 'Pester'
