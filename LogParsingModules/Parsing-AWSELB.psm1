<#  
    Title:          AWS Elastic Load Balancing Parsing instructions
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Katherine Wu
    Last Modified:  2020-09-10
    Comment:        Inital Build


    DESCRIPTION
    This is the ParseInstructions function for parsing AWS Elastic Load Balancing logs. 
    This function will be called to read the whole unzipped file and match the AWS Elastic Load Balancing schema with the corresponding values.
    The output of this function is JSON log file.
   
    Log format: Space seperated CSV with no Header Row


    CHANGE HISTORY


#>

Function ParseInstructions {
    Param ($LogFile)
    #Read each line of the log file
    $LogLines = Get-content -Path $LogFile
    $rowCount = $LogLines.count
    #Provide the schema of AWS ELB
    $header = 'type','time','elb', 'client:port','target:port','request_processing_time','target_processing_time','response_processing_time','elb_status_code','target_status_code','received_bytes','sent_bytes','request','user_agent','ssl_cipher','ssl_protocol','target_group_arn','trace_id','domain_name','chosen_cert_arn','matched_rule_priority','request_creation_time','actions_executed','redirect_url','error_reason','target:port_list','target_status_code_list','classification','classification_reason'
    $parsedLogs = [psobject[]]::new($rowCount)
    $i = 0
    Foreach ($Log in $LogLines) {
        $csvContent = ConvertFrom-Csv -Input $LogLines[$i] -Header $header -Delimiter ' '
        # write-output "processed $($i)"
        $parsedLogs[$i] = $csvContent
        $i++ 
    }
    ConvertTo-Json $parsedLogs
}

# ParseInstructions AWSELBLog.csv