<#  
    Title:          Cisco ASA Firewall Parsing instructions - OVO
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-13
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing Cisco ASA FW logs for OVO Business Unit.
    This function will be called to read the whole unzipped file and split each line into key value pair.
    The output of this function is JSON log file.
   
    Log format: Syslog Space separated


    CHANGE HISTORY


#>

Function Convertto-KVCiscoASA {
    param ($log)
    $pairs = @{
        'timestamp' = ''
        'event_vendor'=''
        'alert_severity' = '' #4
        'alert_severity_category'='' #warning message
        'alert_id'=''
        'alert_message'=''
    }
    $segments = $log -split ('%')
    # there are 2 strings in $segments now so loop through each string
    foreach ($value in $segments){
        # timestamp is the first value
        $firstvalue = $segments[0].Trim(': ')
        $timestamp = ([datetime]::parseexact($firstvalue,'MMM dd yyyy HH:mm:ss',$null)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $pairs['timestamp'] = $timestamp
        # ASA-x-xxxxxx is the second value
        $secondvalue = $segments[1].Substring(0, $segments[1].IndexOf(':'))
        $secondvalueidx = $secondvalue.Length
        $ciscoproduct = $secondvalue.Substring(0,$secondvalue.IndexOf('-'))
        $pairs['event_vendor'] = 'Cisco ' + $ciscoproduct
        # Get the severity number of the log to determin what type of message it is
        $severitynbr = $secondvalue.Substring($ciscoproduct.length + 1, $secondvalue.lastindexof('-').length)
        $pairs['alert_severity']='Priority '+ $severitynbr
        # $foo = $severitynbr.gettype()
        # $severitynbr = $severitynbr -as [int]
        # check the different severity type to see which one to output
        if ($severitynbr -match "1"){
            $pairs['alert_severity_category'] = 'Alert Message'
        } elseif ($severitynbr -match "2"){
            $pairs['alert_severity_category'] = 'Critical Message'
        } elseif ($severitynbr -match "3"){
            $pairs['alert_severity_category'] = 'Error Message'
        } elseif ($severitynbr -match "4"){
            $pairs['alert_severity_category'] = 'Warning Message'
        } elseif ($severitynbr -match "5"){
            $pairs['alert_severity_categorye'] = 'Notification Message'
        } elseif ($severitynbr -match "6"){
            $pairs['alert_severity_category'] = 'Informational Message'
        } elseif ($severitynbr -match "7"){
            $pairs['alert_severity_category'] = 'Debugging Message'
        }
        else {
            $pairs['alert_severity_category'] = ' '
        }
        # Assign message code
        $messagecode = $secondvalue.Substring($secondvalue.LastIndexOf('-')+1)
        $pairs['alert_id'] = $messagecode
        # Remaining message/eventlog is the third value
        $thirdvalue = $segments[1].Substring($secondvalueidx + 2)
        $pairs['alert_message'] = $thirdvalue
    }

    return $pairs
}

Function ParseInstructions {
    Param($LogFile)

    #  Measure-Command {
        $loglines = Get-Content $LogFile

        $parsedlogs = [Hashtable[]]::new($loglines.count)

        $i = 0
        Foreach ($log in $loglines) {
            Write-Host "Processing log line $($i + 1)..."
            # check if the log starts with <
            if ($log[0] -eq "<") {
            #Get rid off the <189> at the beginning of each line
            $log = $log -replace "^<[0-9]{2,4}>", ""
            $parsedlogs[$i] = Convertto-KVCiscoASA $log
            }
            else { # if the log line does not start with < then it's not logged correctly and return null
                $parsedlogs[$i] = $null
            }
            $i++
        }
        ConvertTo-Json $parsedlogs

    }

#ParseInstructions .\asatest.txt
