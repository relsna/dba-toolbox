
# New-Fixture -Path C:\temp -Name Get-ReverseString

function Get-ReverseString {
    param (
        [Parameter(Mandatory=$true)]$string
    )
    $reversed = $string.ToCharArray()
    [array]::Reverse($reversed)

    return -join($reversed)    
}

# Get-ReverseString('Hello World!')
# Get-ReverseString 'PowerShell'
# Get-ReverseString 'Pester'

<#
function Get-ReverseString {
    param (
        [Parameter(Mandatory=$true)]$string
    )
    $reversed = $string.ToCharArray()
    [array]::Reverse($reversed)

    return -join($reversed) + "_bug"
}
#>