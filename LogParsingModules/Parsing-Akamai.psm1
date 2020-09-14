<#  
    Title:          Akamai Kona WAF Parsing instructions
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-11
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing Akamai WAF logs. 
    This function will be called to read the whole unzipped file and match the Akamai WAF Proxy schema with the corresponding values.
    The output of this function is JSON log file.
   
    Log format: Space seperated CSV with no Header Row


    CHANGE HISTORY


#>
Function ConvertTo-KVAkamai {
    Param(
        $Log
    )

    $schema = 'client_ip - - [date] "http_method_ARL_PATH_HTTP/1.1" status_code total_bytes "referrer" "user_agent" "cookie" "waf-info"'
    #Split each schema by space
    $components = $schema.Split(" ")

    #Create a hash table
    $output = @{}
    ForEach ($comp in $components) {
        $logIdx = 0 #Set log index to be zero

        # Skip -
        if ($comp -eq "-") {
            $logIdx += 2  # Skip past - and space.
            $Log = $Log.Substring($logIdx)  # Trim the processed part of the log.
            continue
        }
        $currVal = "" #Set an empty string
        $distanceToClosingToken = 0 #Set the distance from current location to the next value
        #Each component is treated differently based on its structure
        if ($comp.StartsWith('"') -and $comp.EndsWith('"')) {
            $comp = $comp.Substring(1, $comp.Length - 2)
            # Process component bounded by "".
            $Log = $Log.Substring(1)
            $distanceToClosingToken = $Log.IndexOf('"') - $logIdx
            $currVal = $Log.Substring($logIdx, $distanceToClosingToken)
            $logIdx++
        }
        elseif ($comp.StartsWith('[') -and $comp.EndsWith(']')) {
            $comp = $comp.Substring(1, $comp.Length - 2)
            #Process component bounded by [].
            $Log = $Log.Substring(1)
            $distanceToClosingToken = $Log.IndexOf(']') - $logIdx
            $currVal = $Log.Substring($logIdx, $distanceToClosingToken)
            $logIdx++
        }
        else {
            #Process unbounded component (look for next space).
            $distanceToClosingToken = $Log.IndexOf(' ') - $logIdx
            $currVal = $Log.Substring($logIdx, $distanceToClosingToken)
        }

        #Increment logIdx to advance to the beginning of the next value.
        $logIdx += $distanceToClosingToken + 1

        #Short-circuit if logIdx is less than remaining length of the log.
        if ($logIdx -ge $Log.Length) {
            break
        }

        #Trim the processed parts of the log.
        $Log = $Log.Substring($logIdx)

        $output[$comp] = $currVal
    }
    $output
    # Write-Output $output
}


# Function to parse the whole file
Function ParseInstructions {
    Param ($LogFile)
    #Read the log line by line
    $LogLines = Get-content -Path $LogFile
    #Count how many lines in this file
    $rowCount = $LogLines.count
    #Create an array of hash table with the defined number of count
    $parsedLogs = [Hashtable[]]::new($rowCount)
    $i = 0
    Foreach ($Log in $LogLines) {
        #For each log, call ConverTo-KV function to parse
        $parsedLogs[$i] = ConvertTo-KVAkamai -Log $Log
        #Set the timestamp to parse the current date format in the log
        $timestamp = [datetime]::ParseExact($parsedLogs[$i]["date"], 'dd/MMM/yyyy:HH:mm:ss zzz', $null)
        #Convert the date to UTC format and ISO8601 standard
        $parsedLogs[$i]["date"] =  $timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $i++ 
    }
    ConvertTo-Json $parsedLogs
}

# ParseInstructions AkamaiKudoWafLog.csv