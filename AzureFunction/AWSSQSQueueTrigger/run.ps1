<#  
    Title:          Azure Sentinel s3 ToolBox - Process AWS SQS Queue Messages
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Chris Abberley
    Last Modified:  2020-08-26
    Comment:        Inital Build


    DESCRIPTION
    This function performs the second step triggered by a message in the queue which contains the name of an AWS queue that needs to be checked for messages.
    If there is a message validate it and retrieve the log file
    If it is compressed with GZ or ZIP decompress it as well
    Then put a message on the log processing queue.
      
    NOTES
    Please read and understand the documents for the entire collection and ingestion process, there are numerous dependancies on Azure Function Settings, Powershell modules and Storage tables, queues & Blobs 

    CHANGE HISTORY
    1.0.0
    Inital release of code
#>

# Input bindings are passed in via param block.
param([string] $QueueItem, $TriggerMetadata)

#Message format structure to pull apart
$QueueItems = $QueueItem.split(";")
$AWSSQSQueueName = $QueueItems[0]
$AWSRegion = $QueueItems[1]
$AWSProfileName = $QueueItems[2]

$QueueObj = @{'AWSSQSQueueName' = $QueueItems[0]; `
'AWSRegion' = $QueueItems[1]; `
'AWSProfileName' = $QueueItems[2]}
$QueueObj = ConvertTo-Json $QueueObj

# Write out the queue message and insertion time to the information log.
Write-Information "AWSSQSQueueTrigger: AWS Queue: $AWSSQSQueueName triggered time: $($TriggerMetadata.InsertionTime)"

#Import Modules Required
import-module AWS.Tools.common
import-module AWS.Tools.SQS
import-module AWS.Tools.S3
import-module AzTable
import-module AWSCore -Force
import-module AzureCore -Force

#####Environment Variables
$LogConfigTable = $env:s3logconfigstable
$KeyVaultName = $env:s3ToolBoxKeyVault
$AzureWebJobsStorage = $env:AzureWebJobsStorage  
$AzureQueueName = $env:AzureQueueName

#####If Environment did not supply set the default names
if ($null -eq $logConfigTable) { $LogConfigTable = 's3logconfigs' }
if ($null -eq $AzureQueueName) { $AzureQueueName = "logfiles" }

#####script local variables
$AWSQueueCount = 10
$LocalWorkDir = 'D:\home\data\working'  #Azure Function Shared home Directory across any instances spun up.
$EndAWSSQSMessages = $false
$counterMessages = 0
$counterLogFiles = 0

#### Move this to Module
Function Expand-GZip {
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$', '')
    )
    $inputfile = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $outputfile = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $inputfile, ([IO.Compression.CompressionMode]::Decompress)
    $buffer = New-Object byte[](1024)
    while ($true) {
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0) { break }
        $output.Write($buffer, 0, $read)
    }
    $gzipStream.Close()
    $outputfile.Close()
    $inputfile.Close()
}
######

###Check Access to Tables on AzureStorage
$LogConfigTable = confirm-aztable -AzureWebJobsStorage $AzureWebJobsStorage -TableName $LogConfigTable

#connect to storage
$AzureStorage = New-AzStorageContext -ConnectionString $AzureWebJobsStorage

#Connect and setup Azure Message Queue
if (( Get-AzstorageQueue -context $AzureStorage -Name $AzureQueueName -ErrorAction SilentlyContinue ).name ) {
    $AzureQueue = Get-AzStorageQueue -Name $AzureQueueName -Context $AzureStorage
} 
else {
    $AzureQueue = New-AzStorageQueue -Name $AzureQueueName -Context $AzureStorage
}

#connect and retrieve config information from COnfig Tables
$LogConfigTable = (Get-AzStorageTable -Name $LogConfigTable -Context $AzureStorage.Context).cloudTable
$LogConfigs = Get-azTableRow -table $LogConfigTable

#####Sort out AWS Credentials
$AWSCredentials = get-AWSCredential -profilename $AWSprofileName
IF($Null -eq $AWSCredentials){
    $Result = Set-CWCredential -PKey $AWSprofileName -KVault $KeyVaultName -Region $AWSRegion
}
$AWSCredentials = get-AWSCredential -profilename $AWSprofileName

#Connect to AWS SQS Queue
DO {
    $AWSSQSMessages = Receive-SQSMessage -QueueUrl $AWSSQSQueueName -MessageCount $AWSQueueCount -MessageAttributeName All -Credential $AWSCredentials -region $AWSRegion #USE SQS Creds
    if ($AWSSQSMessages.count -eq 0) { $EndAWSSQSMessages = $true }
    $counterMessages += $AWSSQSMessages.count
    foreach ($AWSSQSMessage in $AWSSQSMessages) {
        if ($AWSSQSMessage) {
            $AWSSQSReceiptHandle = $AWSSQSMessage.ReceiptHandle
            $FileCopyFolder = $null
            $FileCopyFolder += $LocalWorkDir + '\' + $AWSSQSMessage.MessageID
            if ((((ConvertFrom-Json -InputObject $AWSSQSMessage.Body)).Records[0].eventName) -clike 'ObjectCreated*') {
                $AWSs3ObjectSize = ((ConvertFrom-Json -InputObject $AWSSQSMessage.Body)).Records[0].s3.object.size
                if ($AWSs3ObjectSize -gt 0) {
                    $AWSs3BucketName = ((ConvertFrom-Json -InputObject $AWSSQSMessage.Body)).Records[0].s3.bucket.name
                    $AWSs3ObjectName = ((ConvertFrom-Json -InputObject $AWSSQSMessage.Body)).Records[0].s3.object.key
                    #validate if it is a logfile we want to collect
                    :filevalidate foreach ($config in $LogConfigs) {
                        #check if the bucket is one of the buckets we are looking for log files on
                        $buckettest = $config.s3Bucket
                        if($buckettest -eq $AWSs3BucketName){
                            #check if the log file path and/or file matches the regex in the config table
                            $nametest = $config.LogKeyMatch
                            if($AWSs3ObjectName -Match $nametest){
                                #found a match so now we know what log config we need to tack and process with this file
                                $counterLogFiles += 1
                                #strip the AWS key down to a filename and also strip any NTFS non confirming characters from the file name
                                $fileNameSplit = $AWSs3ObjectName.split('/')
                                $fileSplits = $fileNameSplit.Length - 1
                                $fileName = $filenameSplit[$fileSplits].replace(':', '_')

                                $null = copy-S3Object -BucketName $AWSs3BucketName -key $AWSs3ObjectName -LocalFile "$FileCopyFolder\$filename" -Credential $AWSCredentials -region $AWSRegion #use s3 creds to collect!
                                #check if file is compressed and decompress based on file extension
                                if ($result.Extension -eq '.gz') {
                                    write-output "decompress GZIP file $FileName"
                                    Expand-GZip -infile "$FileCopyFolder\$fileName" 
                                    Remove-item  -literalPath "$FileCopyFolder\$fileName" 
                                }
                                elseif ($result.Extension -eq '.zip') {
                                    write-output "decompress ZIP file $FileName"
                                    Expand-Archive -LiteralPath "$FileCopyFolder\$fileName" -DestinationPath $FileCopyFolder
                                    Remove-item  -literalPath "$FileCopyFolder\$fileName" 
                                }
                                #create and place message on Log Processing queue for the log folder the files were put in
                                $AzureQmessage = `
                                    $config.RowKey + ';' `
                                    + $FileCopyFolder + ';' `
                                    + $currentUTCtime
                                $AzureQmessage = [Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($AzureQmessage)
                                $AzureQueue.CloudQueue.AddMessageAsync($AzureQMessage, $null, 0, $null, $null)
                                break filevalidate
                            }
                        }
                    }
                }
            }
            $null = Remove-SQSMessage -QueueUrl $AWSSQSQueueName -ReceiptHandle $awsSQSReceiptHandle -Force -Credential $AWSCredentials -region $AWSRegion  #USE SQS Creds
        }
    }
    #check on time running, Azure Function default timeout is 5 minutes, if we are getting close exit function cleanly now and get more records next execution
    IF ((new-timespan -Start $currentUTCtime -end ((Get-Date).ToUniversalTime())).TotalSeconds -gt 500) { $EndAWSSQSMessages = $true } 
}until ($EndAWSSQSMessages)

$CompleteDate = (Get-Date).ToUniversalTime()
$CompleteDate = $CompleteDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Write-Information "AWSSQSQueueTrigger: AWS Queue: $AWSSQSQueueName Completed Processed $counterMessages messages, $counterLogFiles valid Logs copied to staging TIME: $CompleteDate"
    