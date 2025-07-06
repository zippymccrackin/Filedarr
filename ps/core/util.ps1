function Notify-Listeners {
    param (
        [ScriptBlock[]]$Listeners,

        [Parameter(ValueFromRemainingArguments = $true)]
        $Args,

        [object]$Return = $null
    )

    if ($null -eq $Listeners) {
        throw "Listeners parameter cannot be null. Pass an empty array if no listeners."
    }

    $count = 0
    Write-Debug "Calling listeners"
    foreach ($listener in $Listeners) {
        $count = $count + 1
        Write-Debug "Inside Listener Call $count"
        $Return = & $listener $Return @Args
    }
    Write-Debug "Return from listeners (called $count)"

    return $Return
}