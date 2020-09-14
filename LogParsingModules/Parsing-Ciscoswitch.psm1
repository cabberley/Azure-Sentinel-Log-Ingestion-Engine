<#  
    Title:          Cisco Switch Parsing instructions
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-11
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing Cisco Switch logs. 
    This function will be called to read the whole unzipped file and split each line into key value pair.
    The output of this function is JSON log file.
   
    Log format: Syslog Space separated


    CHANGE HISTORY


#>

# Below is the ConvertTo-KV function Katherine developed, both functions work.
Function ConvertTo-KVCisco {
    Param(
        $Message
    )

    $pairs = @{}

    Do {
        $key = $Message.Substring(0, $Message.IndexOf("="))
        $value = ""

        # Trim off the key and the '='.
        $Message = $Message.Substring($Message.IndexOf("=") + 1)

        # Check if we're processing the last pair.
        if ($Message.Contains("=")) {
            # Not processing the last pair.
            $temp = $Message.Substring(0, $Message.IndexOf("="))
            $value = $temp.Substring(0, $temp.LastIndexOf(" "))

            # Trim includes the next '=' char.
            $Message = $Message.Substring($value.Length + 1)
        }
        else {
            # Processing the last pair. No more '=' so we need to handle things
            # differently.
            $value = $Message

            # Trim doesn't include the next '=' char because we're at the end.
            $Message = $Message.Substring($value.Length)
        }

        # Add to hash and remove extra quotations if present.
        $pairs[$key] = $value.Trim('"')

    } Until($Message.Length -eq 0)

    return $pairs
}

Function ParseInstructions {
    Param($LogFile)

    # Measure-Command {
        $loglines = Get-Content $LogFile

        $parsedlogs = [Hashtable[]]::new($loglines.count)

        $i = 0
        Foreach ($log in $loglines) {
            # Write-Host "Processing log line $($i + 1)..."

            #Get rid off the <189> at the beginning of each line
            $log = $log -replace "^<[0-9]{2,4}>", ""

            $parsedlogs[$i] = ConvertTo-KVCisco $log
            $timestampsrting = ($parsedlogs[$i]['date'] + " " + $parsedlogs[$i]['time'])
            $timestamp = ([datetime]::parseexact($timestampsrting,'yyyy-MM-dd HH:mm:ss',$null)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $parsedlogs[$i]['Timestamp'] = $timestamp
            $parsedlogs[$i].Remove('date')
            $parsedlogs[$i].Remove('time')
            $parsedlogs[$i]['eventtime'] = (((Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($parsedlogs[$i]['eventtime']))).ToUniversalTime()).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $i++
        } 
        ConvertTo-Json $parsedlogs
}

# ParseInstructions .\Ciscoswitchlog.txt