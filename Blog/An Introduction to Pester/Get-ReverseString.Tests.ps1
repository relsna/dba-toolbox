$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-ReverseString" {
    It "Should reverse a string" {
        $expected = '!dlroW olleH'
        Get-ReverseString('Hello World!') | Should -Be $expected
    }
}
