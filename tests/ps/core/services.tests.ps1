# core/services.ps1

BeforeAll {
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\services.ps1' | Resolve-Path
    . $includePath
}

Describe "Services" {
    It "should be empty and not null" {
        $Services.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'Services' -Scope Global).name | Should -Not -BeNull
    }
}