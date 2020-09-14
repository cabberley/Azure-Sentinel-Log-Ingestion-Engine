<#  
    Title:          Azure Sentinel s3 ToolBox - Time Trigger to queue list of AWS SQS Queues to check
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Chris Abberley
    Last Modified:  2020-08-26
    Comment:        Inital Build


    DESCRIPTION
    This function performs first step retrieve the list of AWS SQS Queues that need to be checked for new messages and create a queue for the next function to poll each message queue

      
    NOTES
    Please read and understand the documents for the entire collection and ingestion process, there are numerous dependancies on Azure Function Settings, Powershell modules and Storage tables, queues & Blobs 

    CHANGE HISTORY
    1.0.0
    Inital release of code


#>
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Information "AWSSQSTimeTrigger: Azure Function timer trigger is running late! TIME: $currentUTCtime"
}

# Write an information log with the current time.
Write-Information "AWSSQSTimeTrigger: Azure Function timer trigger function ran! TIME: $currentUTCtime"
#$awsip = Get-AWSPublicIpAddressRange -Region ap-southeast-1 -ServiceKey S3
import-module AzTable
import-module AzureCore

#####Environment Variables
$SQSQueuesTable = $env:SQSQueuesConfigTable
$AzureWebJobsStorage = $env:AzureWebJobsStorage  
$AzureSQSQueueName = $env:AzureSQSQueueName

#####If Environment did not supply set the default names
if ($null -eq $SQSQueuesTable) { $SQSQueuesTable = 'sqsqueueconfigs' }
if ($null -eq $AzureSQSQueueName) { $AzureSQSQueueName = 'sqsqueues' }

###Check Access to Tables on AzureStorage
$SQSQueuesTable = confirm-aztable -AzureWebJobsStorage $AzureWebJobsStorage -TableName $SQSQueuesTable

#connect to storage
$AzureStorage = New-AzStorageContext -ConnectionString $AzureWebJobsStorage

#Connect and setup Azure Message Queue
if (( Get-AzstorageQueue -context $AzureStorage -Name $AzureSQSQueueName -ErrorAction SilentlyContinue ).name ) {
    $AzureQueue = Get-AzStorageQueue -Name $AzureSQSQueueName -Context $AzureStorage
} 
else {
    $AzureQueue = New-AzStorageQueue -Name $AzureSQSQueueName -Context $AzureStorage
}

#connect and retrieve config information from COnfig Tables
$SQSQueuesTable = (Get-AzStorageTable -Name $SQSQueuesTable -Context $AzureStorage.Context).cloudTable
$SQSQueuesConfigs = Get-azTableRow -table $SQSQueuesTable

Foreach ($AWSQueue in $SQSQueuesConfigs){
    $AzureQmessage = `
    $AWSQueue.AWSSQSQueueName+ ';' `
    + $AWSQueue.AWSRegionSQS+ ';' `
    + $AWSQueue.AWSProfileNameSQS
    $AzureQmessage = [Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($AzureQmessage)
    $AzureQueue.CloudQueue.AddMessageAsync($AzureQMessage, $null, 0, $null, $null)
}
$count = $SQSQueuesConfigs.count
$CompleteDate = (Get-Date).ToUniversalTime()
$CompleteDate = $CompleteDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Write-Information "AWSSQSTimeTrigger: Trigger Completed inserted $count AWS queues to check TIME: $CompleteDate"
