FUNCTION ParseInstructions {
    Param($LogEvents)

    $clean = $null
    Foreach ($log in $LogEvents) {
        $log = $Log -replace "^<[0-9]{2,4}>", "" -Replace '"', ''
        $mess= $null
        $mess = ConvertTo-KeyValue -s $log
        $logtime = $mess[0].date +'T'+$mess[0].time
        $logtime = Get-Date $logtime
        $logTime = $logtime.AddHours(-7)
        $logtime = ((Get-date ($mess[0].date +'T'+$mess[0].time)).AddHours(-7)).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $mess[0].eventtime = $logtime
        $mess[0].remove('time')
        $mess[0].remove('date')
        $j = ConvertTo-Json $mess
        $j = $j -Replace ('\[','') -replace ('\]','')
        if ($clean.length -eq 0) {
            $clean = $j
        }
        else {
            $clean = $clean + ",`n" + $j
        }
    }
    $clean = '[' + $clean + ']'
    $clean #Return Write-Output -NoEnumerate $clean
}

