<#  
    Title:          Azure Sentinel s3 ToolBox - Azure Function for LogFile Processing and ingestion into Log Analytics
    Language:       PowerShell
    Version:        0.1.1
    Author(s):      Microsoft - Chris Abberley
    Last Modified:  2020-08-26
    Comment:        Inital Build


    DESCRIPTION
    This function performs final steps to ingest the collected log files into the Azure Log Analytics workspace.

      
    NOTES
    Please read and understand the documents for the entire collection and ingestion process, there are numerous dependancies on Azure Function Settings, Powershell modules and Storage tables, queues & Blobs 

    CHANGE HISTORY
    1.0.0
    Inital release of code

#>

# Input bindings are passed in via param block from the Azure Function Queue Trigger.
param([string] $QueueItem, $TriggerMetadata)

#Queue essage provides the code the Logfile type and folder location where the log files for this execution reside. There could be more than one file
$QueueItems = $QueueItem.split(";")
$LogConfig = $QueueItems[0]
$LogFolder = $QueueItems[1]


$QueueObj = @{'LogConfig' = $QueueItems[0]; `
        'LogFolder'       = $QueueItems[1] 
}
$QueueObj = ConvertTo-Json $QueueObj

# Write out the queue message and insertion time to the information log.
Write-Information "LogProcessingQueueTrigger: $LogFolder Time started: ($TriggerMetadata.InsertionTime)"

#Import Modules Required
Import-Module AzTable -Force
Import-Module AzureCore -Force

#####Environment Variables
$LogConfigTable = $env:s3logconfigstable
$AzureWebJobsStorage = $env:AzureWebJobsStorage  
$AzureQueueName = $env:AzureQueueName
$AzureWorkSpaceTable = $env:AzureWorkspaceTable
$DataDictionaryTable = $env:DataDictionaryTable
$AzureCloud = $env:AzureCloud
$PartitionKey = $env:PartitionKey

#####If Environment did not supply set the default names
if ($null -eq $logConfigTable) { $LogConfigTable = 's3logconfigs' }
if ($null -eq $AzureQueueName) { $AzureQueueName = "logfiles" }
if ($null -eq $AzureWorkSpaceTable) { $AzureWorkSpaceTable = "azureworkspaces" }
if ($null -eq $DataDictionaryTable) { $DataDictionaryTable = "DataDictionary" }
if ($null -eq $AzureCloud) { $AzureCloud = 'Commercial' }
if ($null -eq $PartitionKey) { $PartitionKey = 'Part1' }

#connect to storage
$AzureStorage = New-AzStorageContext -ConnectionString $AzureWebJobsStorage

#connect and retrieve config information from Config Tables
$LogConfigTable = (Get-AzStorageTable -Name $LogConfigTable -Context $AzureStorage.Context).cloudTable
$LogFileConfig = Get-AzTableRow -Table $LogConfigTable -RowKey $LogConfig -PartitionKey $PartitionKey
$AzureWorkSpaceTable = (Get-AzStorageTable -Name $AzureWorkSpaceTable -Context $AzureStorage.Context).cloudTable
$WorkspaceConfig = Get-AzTableRow -Table $AzureWorkSpaceTable -RowKey ($LogFileConfig.WorkSpaceName) -PartitionKey $PartitionKey
$DataDictionaryTable = (Get-AzStorageTable -Name $DataDictionaryTable -Context $AzureStorage.Context).cloudTable
$DataDictionary = Get-AzTableRow -Table $DataDictionaryTable -RowKey $LogConfig -PartitionKey $PartitionKey
$DataDictionary = $DataDictionary.psobject.properties

#Get list of files that need to be ingested
$FileList = Get-ChildItem -Path $LogFolder

#get parsing Block from Blob Storage and put it in the Log File working Folder
$Block = $logFileConfig.ParsingInstructions
$null = Get-AzStorageBlobContent -Context $AzureStorage -Container logparsers -Blob $Block -Destination $logFolder
#load the Parsing Code required for this log type
Import-Module "$logfolder\$Block" -Force

#process each file and ingest into Log Analytics Workspace
foreach ($file in $FileList) {
    if ($file.mode[0] -ne 'd') {
        #If Json file we want to load the entire file as an object, if not load each line as an object
        if($logFileConfig.LogFormat -ieq 'json'){
            $RawEventLogs = Get-Content -Raw -LiteralPath ($LogFolder + '\' + $file.name)    
        }
        Else {
            $RawEventLogs = Get-Content -LiteralPath ($LogFolder + '\' + $file.name)
        }
        ###### Pass Raw event log to parsing instruction block loaded earlier
        $parsedLogs = $null
        $parsedLogs = ParseInstructions -LogEvents $RawEventLogs
        ##Function Send-LogAnalyticsData Param $customerId,$sharedKey, $EventLogs, $CustomLogName, $TimeStampField
        $null = Send-LogAnalyticsData -CustomerID ($WorkspaceConfig.WorkspaceID) -sharedKey ($WorkspaceConfig.WorkspaceKey) -EventLogs $ParsedLogs -CustomLogName ($LogFileConfig.LogAnalyticsTable) -TimeStampField ($LogFileConfig.TimeStampField) -ResourceId ($LogFileConfig.ResourceID)

    }
}
##### Delete folder from storage when all files processed
$null = remove-item -path $LogFolder -Force -Recurse

### Record log entry of completion
$CompleteDate = (Get-Date).ToUniversalTime()
$CompleteDate = $CompleteDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Write-Information "LogProcessingQueueTrigger: Completed: Folder:$LogFolder Config:$logConfig Time Completed:$CompleteDate"
