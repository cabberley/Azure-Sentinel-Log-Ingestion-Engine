
<#  
    Title:          AWS VPC Flow Parsing instructions
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-09
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing AWS VPC Flow logs. 
    This function will be called to read the whole unzipped file and match the AWS VPC schema with the corresponding values.
    The output of this function is JSON log file.
   
    Log format: space seperated CSV with Header


    CHANGE HISTORY


#>
Function ParseInstructions {
    Param($LogFile)
    #Create an hash table of all possible schemas. AWS VPC flow log schema has version 2, 3, and 4.
    $headers = @{
        "v2" = 'version', 'account-id', 'interface-id', 'srcaddr', 'dstaddr', 'srcport', 'dstport', 'protocol', 'packets', 'bytes', 'start', 'end', 'action', 'log-status';
        "v3" = 'version', 'vpc-id', 'subnet-id', 'instance-id', 'interface-id', 'account-id', 'type', 'srcaddr', 'dstaddr', 'srcport', 'dstport', 'pkt-srcaddr', 'pkt-dstaddr', 'protocol', 'bytes', 'packets', 'start', 'end', 'action', 'tcp-flags', 'log-status';
        #v4: there is no documentation of what are the fields for v4 so if the customer have v4 configured, need to cross check the schema.
        "v4" = 'version', 'account-id', 'interface-id', 'srcaddr', 'dstaddr', 'srcport', 'dstport', 'protocol', 'packets', 'bytes', 'start', 'end', 'action', 'log-status', 'region', 'az-id', 'sublocation-type', 'sublocation-id'
    }
    #Read the content in $LogFile line by line
    $logLines = Get-Content $LogFile
    
    #Creatges an empty array
    $parsedLogs = @()

    for ($i = 0; $i -lt $logLines.Length; $i++) {
        # skip the first line, which is the header row
        if ($i -eq 0) {
            continue
        }
        #If the first character of the string equals "2", then use the header v2 schema
        if ($logLines[$i][0] -eq "2") {
            $header = $headers["v2"]
            #converts each line into object
            $csvContent = ConvertFrom-Csv -Input $logLines[$i] -Header $header -Delimiter ' '
           
        }
        #If the first character of the string equals "3", then use the header v3 schema
        elseif ($logLines[$i][0] -eq "3") {
            $header = $headers["v3"]
            #converts each line into object
            $csvContent = ConvertFrom-Csv -Input $logLines[$i] -Header $header -Delimiter ' '
        }
        #If the first character of the string equals "4", then use the header v4 schema
        elseif ($logLines[$i][0] -eq "4") {
            $header = $headers["v4"]
            #converts each line into object
            $csvContent = ConvertFrom-Csv -Input $logLines[$i] -Header $header -Delimiter ' '
        }

        #Add a time varialbe to be in ISO8601 format
        $time = (((Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($csvContent.start))).ToUniversalTime()).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')        
        #Add the the timestamp property to $csvContent object
        $csvContent | Add-Member -NotePropertyName timestamp -NotePropertyValue $time
        #Change the start and end time from Unix format to ISO 8601 format
        $csvContent.start = (((Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($csvContent.start))).ToUniversalTime()).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $csvContent.end = (((Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($csvContent.end))).ToUniversalTime()).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        #convert the object to JSON
        $parsedLogs += ConvertTo-JSON $csvContent
    }
    $parsedLogs
  }

# ParseInstructions VPCFlow.csv

