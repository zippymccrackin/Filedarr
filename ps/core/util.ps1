Import-Module powershell-yaml -ErrorAction Stop

if (Get-Command -Name "Notify-Listeners" -CommandType Function -ErrorAction SilentlyContinue) {
    return
}

$Global:Config = Get-Content -Raw -Path (Join-Path $PSScriptRoot '..\..\config.yml') | ConvertFrom-Yaml
Write-Debug "Loaded config: $( $Global:Config | ConvertTo-Json -Depth 5 )"

function Notify-Listeners {
    param (
        [Parameter(Position = 1)]
        [ScriptBlock[]]$Listeners,

        [Parameter(ValueFromRemainingArguments = $True, Position = 2)]
        $Args,

        [Parameter()]
        [object]$Return = $Null
    )

    if ($Null -eq $Listeners) {
        throw "Listeners parameter cannot be null. Pass an empty array if no listeners."
    }

    $count = 0
    Write-Debug "Calling listeners"
    foreach ($listener in $Listeners) {
        $count = $count + 1
        Write-Debug "Inside Listener Call $count"
        if ($Return -ne $Null) {
            $Return = & $listener $Return @Args
        } else {
            & $listener @Args
        }
    }
    Write-Debug "Return from listeners (called $count)"

    return $Return
}

function Report-Error {
    param(
        [String]$errorMsg,
        [bool]$NotifyListeners=$True
    )

    Write-Error $errorMsg
    if (
        $NotifyListeners -and 
        $ReportErrorListeners -is [System.Collections.IEnumerable] -and 
        $ReportErrorListeners.Count -gt 0
    ) {
        Notify-Listeners $ReportErrorListeners $errorMsg
    }
}

function Module-Enabled {
    param(
        [string]$moduleName
    )
    $ret = $False

    Write-Debug("Config: $( $Global:Config | ConvertTo-Json -Depth 5 )")
    if ($Global:Config.modules -is [System.Collections.IEnumerable]) {
        $mod = $Global:Config.modules | Where-Object { $_.module_name -eq $moduleName }

        if ($mod) {
            if ($mod.enabled -ne $false) {
                $ret = $True
            }
        }
    }
    Write-Debug("Module $moduleName enabled: $ret")
    return $ret
}

function Get-Module-Variables {
    param(
        [string]$moduleName
    )

    $mod = $null
    foreach ($m in $Global:Config.modules) {
        if ($m.module_name -eq $moduleName) {
            $mod = $m
            break
        }
    }

    if ($mod) {
        $vars = @{}
            foreach ($v in $mod.variables) {
                foreach ($key in $v.Keys) {
                    Write-Debug("  Variable $key = $($v.$key)")

                    # Handle environment variable substitution if the value starts with "env:"
                    if ($v[$key] -is [string] -and $v[$key].StartsWith("env:")) {
                        $envVarName = $v[$key].Substring(4)
                        $envVarValue = [System.Environment]::GetEnvironmentVariable($envVarName)
                        if ($null -ne $envVarValue) {
                            Write-Debug("    Substituting environment variable '$envVarName' with value '$envVarValue'")
                            $vars[$key] = $envVarValue
                            continue
                        }
                    }

                    $vars[$key] = $v[$key]
                }
            }
        Write-Debug("Module $moduleName variables: $( $vars | ConvertTo-Json -Depth 5 )")
        return $vars
    }
    Write-Debug("Module $moduleName not found or has no variables")
    return $Null
}

function Convert-ToBytes {
        param($size)
        if ($null -eq $size) {
            throw "Size is null"
        }
        if ($size -is [int] -or $size -is [long] -or $size -is [double]) {
            Write-Debug "Converting numeric size: $size"
            return [long]$size
        }
        if ($size -isnot [string]) {
            throw "Invalid size format: $($size.GetType().ToString())"
        }
        if ($size -match '^([0-9.]+)\s*(B|KB|MB|GB|TB|PB)?$') {
            $value = [double]$matches[1]
            $unit = $matches[2]
            Write-Debug "Converting size ($size): value=$value, unit=$unit"
            switch ($unit.ToUpper()) {
                'B'   { return [long]$value }
                'KB'  { return [long]($value * 1KB) }
                'MB'  { return [long]($value * 1MB) }
                'GB'  { return [long]($value * 1GB) }
                'TB'  { return [long]($value * 1TB) }
                'PB'  { return [long]($value * 1PB) }
            }
        } else {
            throw "Invalid size format: $size"
        }
}