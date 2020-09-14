<#  
    Title:          Cisco Umbrella Proxy Parsing instructions
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-09
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing Cisco Umbrella Proxy logs. 
    This function will be called to read the whole unzipped file and match the Cisco Umbrella Proxy schema with the corresponding values.
    The output of this function is JSON log file.
   
    Log format: Comma Seperated CSV No Header - W3C extended type data


    CHANGE HISTORY


#>

Function ParseInstructions {
    param(
        $LogFile
    )
    #Create an array, which is made up of Cisco Umbrella Proxy schema
    $header = "Timestamp", "Identities", "Internal IP", "External IP", "DestinationIP", "ContentType", "Verdict", "URL", "Referer", "userAgent", "statusCode", "requestSize", "responseSize", "responseBodySize", "SHA", "Categories", "AVDetections", "PUAs", "AMPDisposition", "AMPMalware Name", "AMPScore", "IdentityType", "Blocked Categories"
    #Set an empty array
    $parsedLogs = @()
    #Read each line of log in the log file
    foreach ($log in Get-content $LogFile) {
        #converts each line into object
        $csvContent = ConvertFrom-Csv -Input $log -Header $header
        #Change the existing timestamp property value to ISO8601 format
        $csvContent.timestamp = Get-Date -Date $csvContent.Timestamp -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        #convert the object to JSON
        $parsedLogs += ConvertTo-JSON $csvContent
    }
    $parsedLogs
}

# ParseInstructions CiscoUmbrellaProxy.csv