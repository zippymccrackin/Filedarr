if (Get-Command -Name "Notify-Listeners" -CommandType Function -ErrorAction SilentlyContinue) {
    return
}

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