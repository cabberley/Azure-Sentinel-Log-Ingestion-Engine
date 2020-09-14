[Configuring the Data Ingestion](#configuring-the-data-ingestion)

[Azure Function Configuration](#azure-function-configuration)

- [Settings - Configuration - Application Settings](#settings---configuration---application-settings)
  - [Settings - Configuration - General Settings](#settings---configuration---general-settings)
  - [Settings - Identity](#settings---identity)
  - [Settings - Scale Up & Scale Out](#settings---scale-up--scale-out)
  - [Settings - Application Insights](#settings---application-insights)
  - [Functions - App Files](#functions---app-files)
    - [profile.ps1](#profileps1)
    - [requirements.psd1](#requirementspsd1)
    - [host.json](#hostjson)
- [Configuration Information for a Log Ingestion](#configuration-information-for-a-log-ingestion)
	- [AWS Information](#aws-information)
	- [Azure Information](#azure-information)
	- [Log File Specific Information](#log-file-specific-information)
		- [Table sqsqueueconfigs](#table-sqsqueueconfigs)
		- [Table azureworkspaces](#table-azureworkspaces)
		- [Table s3logconfigs](#table-s3logconfigs)
	- [Azure Key Vault](#azure-key-vault)
		- [Storing AWS Credentials](#storing-aws-credentials)
- [Parsing/Transforming Log Files to ingest into Azure Sentinel](#parsingtransforming-log-files-to-ingest-into-azure-sentinel)
	- [Structure of the PowerShell Module](#structure-of-the-powershell-module)
	- [Design Considerations](#design-considerations)
	- [Deployment of your Parsing Instructions](#deployment-of-your-parsing-instructions)

[Configuration Information for a Log Ingestion](#configuration-information-for-a-log-ingestion)

* [AWS Information](#aws-information)
* [Azure Information](#azure-information)
* [Log File Specific Information](#log-file-specific-information)
  + [Table sqsqueueconfigs](#table-sqsqueueconfigs)
  + [Table azureworkspaces](#table-azureworkspaces)
  + [Table s3logconfigs](#table-s3logconfigs)
* [Azure Key Vault](#azure-key-vault)
  + [Storing AWS Credentials](#storing-aws-credentials)

[Parsing/Transforming Log Files to ingest into Azure Sentinel](#parsing-transforming-log-files-to-ingest-into-azure-sentinel)

* [Structure of the PowerShell Module](#structure-of-the-powershell-module)
* [Design Considerations](#design-considerations)
* [Deployment of your Parsing Instructions](#deployment-of-your-parsing-instructions)

# Configuring the Data Ingestion

This Azure Function has multiple parts that require configuration for it to provide a complete end to end solution.

Configuration work can be grouped into two parts

1. The underlying Azure Function and dependencies  for the Ingestion Pipeline to operate.
2. Configuration information required for a log file to be collected and ingested into Log Analytics ready for Azure Sentinel.



# Azure Function Configuration

There are several sections within the Azure Function that should be configured or verified 

## Settings - Configuration - Application Settings

In addition to some default settings these key Application Settings should be created 

| Name                                     | Description                                                  | Sample Value    |
| ---------------------------------------- | ------------------------------------------------------------ | --------------- |
| AzureCloud                               | Azure has different end points for the "commercial" and Government clouds. This Application Setting enables you to configure which cloud you are using. The expected values are "Commercial" and "Government".  The default is Commercial and if this Application Setting is not set it will default to Commercial. | Commercial      |
| AzureQueueName                           | This is the name of the Azure Storage Queue the functions will use to message the log processing Function which log files have been retrieved that need to be transposed and ingested into Log Analytics. The default value is "logfiles" | logfiles        |
| AzureSQSQueueName                        | This is the name of the Azure Storage Queue the functions will use to message the function that needs to connect to the AWS SQS queues to retrieve the messages from AWS about the logfiles that need to be collected from the AWS s3 buckets. The default value is "sqsqueues" | sqsqueues       |
| AzureWebJobStorage                       | This should be automatically created by the Azure Function and refers to the underlying Azure Storage Account the Azure Function relies on. This will also be the default Storage Account that the "Tables" and "Queues" will be located on. |                 |
| AzureWorkSpaceTable                      | The name of the Table that will be created and used on the Azure Storage Account to hold the Log Analytics Workspace details for all the Log Analytics Workspaces these Azure Functions will need to send data to for ingestion. The default value is "azureworkspaces" | azureworkspaces |
| DataDictionary                           | The name of the Table that will be created and used on the Azure Storage Account to hold Data Dictionaries for data normalisation if utilised during the Log Transposing phase of ingestion. The default value is "DataDictionary" |                 |
| FUNCTIONS_EXTENSION_VERSION              | THe PowerShell scripts used by this function are based on PowerShell 7 which does require Azure Functions version 3. so ensure that this value is correctly set as "~3" | "~3"            |
| FUNCTIONS_WORKER_PROCESS_COUNT           | For this data ingestion pipeline to be able to scale and run multiple PowerShell functions simultaneously we need to set this value. Please refer to [Azure Function PowerShell Concurrency](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal#concurrency) For details and how this works and setting an appropriate value. |                 |
| FUNCTIONS_WORKER_RUNTIME                 | Default Function setting that sets what Runtime the function requires. | powershell      |
| PartitionKey                             | Azure Storage Tables require a unique Key and Row combination. This setting sets this Azure Function's Partition Key. If you were running multiple Azure Function instances and sharing the configurations, by using a different Partition Key for each Azure Functions configs the configs could be shared. The default value is "Part1" | Part1           |
| PSWorkerInProcConcurrencyUpperBound      | This setting also helps the Azure Function to increase concurrency and better utilise the resources of the Azure Function. Please read and understand [PowerShell Profile](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal#powershell-profile) to determine an appropriate value for your implementation. |                 |
| s3logconfigstable                        | This setting is the name of the Azure Storage Table used by the scripts to read the Log file configuration information required to process logs. The default value is "s3logconfigs" | s3logconfigs    |
| s3ToolBoxKeyVault                        | The scripts will access a KeyVault to retrieve the AWS credentials required to access the SQS queues and the s3 buckets. This is the name of the Azure KeyVault where these credentials are stored. It must be a globally unique name and does not have a default. |                 |
| SQSQueuesConfigTable                     | This setting is the name of the Azure Storage Table used by the scripts to read the AWS SQS Queue details required to identify and access the Queues in AWS being used to notify of new log file creation events. The default value is "sqsqueueconfigs" | sqsqueueconfigs |
| WEBSITE_CONTENTAZUREFILECONNECTIONSTRING | This is a standard Azure Function Application Setting created when an Azure Function is created. |                 |
| WEBSITE_CONTENTSHARE                     | This is a standard Azure Function Application Setting created when an Azure Function is created. |                 |
|                                          |                                                              |                 |

## Settings - Configuration - General Settings

On the General Settings Section, verify and or set the following

**Stack settings**

- Stack - PowerShell Core
- PowerShell Core Version - PowerShell 7.0

**Platform settings**

- Platform - 64 bit
- FTP state - Should be disabled unless there is a specific requirement in your environment
- Web Sockets - Off
- ARR affinity - Off

Please review the other settings and disable/secure your environment!

## Settings - Identity

The Azure Functions and PowerShell scripts have been architected to use the Azure Functions Managed Identity to authenticate to Azure KeyVault.

Configure the system assigned Managed Identity and provide List and Read access for the identity to the Azure Key Vault that will store the AWS credentials. 

## Settings - Scale Up & Scale Out

Depending on the volume of logs that your implementation will need to process you will need to configure an appropriate base Azure SKU for scale UP and configure Scale Out to handle within your desired ingestion delays the peaks and troughs of your log ingestions.

## Settings - Application Insights

While not mandatory, Application Insights will provide solid help to understand the workloads and processing performance for your environment and also alert you in real time of any errors in the ingestion process code.

## Functions - App Files

The App Files section sets some base configuration and environment profiles for all the Functions that will run on this Azure Function Instance. There are several important files that if you haven't created this Azure Function from a package need to be checked and configured where not set correctly.

### profile.ps1

Needs to have the Managed Service Identity enabled and should contain the following lines'

```
if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
	Connect-AzAccount -Identity
}
```

### requirements.psd1

This file enables the Azure Function to download the first time it runs or new modules have been added required Azure PowerShell Gallery modules automatically in the background. NOTE: the first time a PowerShell script executes on the Azure Function the platform will download all the modules listed on the requirements.psd1. This may take a while to complete and may even exceed the timeout you have set for a Function execution.

```
#This file enables modules to be automatically managed by the Functions service.
#See https://aka.ms/functionsmanageddependency for additional information.
#
@{
#For latest supported version, go to 'https://www.powershellgallery.com/packages/Az'. 
	'Az' = '4.*'
	'AzTable' = '2.*'
	'Az.KeyVault' = '2.*'
	'AWS.Tools.common' = '4.*'
	'AWS.Tools.SQS' = '4.*'
	'AWS.Tools.s3' = '4.*'
	'AWS.Tools.SecurityToken' = '4.*'
	'Az.OperationalInsights' = '2.*'
}
```

### host.json

```
{
  "version": "2.0",
  "managedDependency": {
	"Enabled": true
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[1.*, 2.0.0)"
  }
}
```

# Configuration Information for a Log Ingestion

To successfully configure and enable a log file stored on an AWS s3 bucket to be ingested into an Azure Sentinel Log Analytics Workspace there are several pieces of information required and these need to be correctly stored to enable the Azure Function to be bale to use them and process the log file.

## AWS Information

| Item             | Description                                                  |
| ---------------- | ------------------------------------------------------------ |
| AWS Credentials  | The system will require the correct AWS Credentials to successfully access both the AWS SQS Queue and the AWS s3 Buckets. The Ingestion Pipeline has been designed so that various sets of credentials can be used, Each AWS Resource can have a separate set of credentials or you could use the same set of credentials for everything. The system will also support a standard AWS identity using the AWS AccessID and SecretKey as will as Cross-Account Role based access with or without the externalID attribute. |
| SQS Queue names  | The system will require the details for each AWS SQS queue that it requires to read messages from. The identity used to access the queue will need to be able to read and then remove completed messages from each queue. |
| s3 Bucket name   | The names of the s3 buckets where log files are stored as well as the AWS identity required to access the bucket. |
| s3 Key           | The system will need the Key or folder\container path to where the log files are stored. While the SQS queue message will contain the full Key this information is required in the Log File config section to validate the log file is one that is wanted for ingestion. |
| AWS Connectivity | The Azure Functions will require network connectivity between Azure and AWS, this can be achieved and has been tested in a few different ways. Including Azure Function being configured using a VNet Integration and s3 buckets being accessed via Azure Express Route and AWS Direct Connect. |
|                  |                                                              |
|                  |                                                              |

## Azure Information

| Item                    | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| Key Vault               | The function uses an Azure  key Vault to Store the AWS credentials that it requires to access the AWS SQS and s3 bucket resources. |
| Log Analytics workspace | The Function will require the Workspace ID and Workspace Key of the Log Analytics workspaces that the Data is going to be ingested to. |
| Storage Account         | The storage account that the Azure Function uses is also used to create a container to store the various log parsing modules required to transform each type of log file. |
| Azure Storage Tables    | There are several tables that the Function requires to store config information to enable a variety of log sources and log types to be collected and processed. |
| Azure Storage Queues    | To enable the Azure function to scale each stage of the ingestion operates independently of the others. The Azure Storage Queues are used to communicate and trigger the following stage. |



## Log File Specific Information

For each log file that you will be ingested there are various pieces of information required by the function. This information is stored in several Azure Storage tables. Below is the details require3d and which Azure Storage Table they are stored in. To help load this information into the Azure Storage tables, you can create CSV file with headers and use Microsoft Azure Storage Explorer to import the configuration data in bulk.

### Table sqsqueueconfigs

This table stores configuration information required to access the AWS queues. The same queue can be used by multiple log file configs. The default name for this table is sqsqueueconfigs, but can be changed if the matching Application Settings value for this setting matches.

| Column Name       | Description                                                  | Example                                                      |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| PartitionKey      | The name of the Partition Key that is being used for this instantiation of the Azure Function. | Part1                                                        |
| RowKey            | A unique value, to enable the Partition Key and Row Key combination to be unique within the table. Such as using a GUID | e7402991-d02f-4f8f-bd84-729cd1f96c91                         |
| AWSProfileNameSQS | The AWS Credential Profile name that has been given to the AWS Credentials required to authenticate to this queue. This value needs to also be the value used in Azure KeyVault to store the credentials, they must match for the system to be able to find and retrieve them from the Azure Key Vault. | myawscreds                                                   |
| AWSRegionSQS      | AWS requires the name of the region where the queue is hosted. | ap-southeast-2                                               |
| AWSSQSQueueName   | The full URI of the SQS Queue that needs to be queried.      | https://sqs.ap-southeast-1.amazonaws.com/111111111111/queuename |

### Table azureworkspaces

This table stores configuration information required to access the Azure Log Analytics workspaces. Only one entry is required for each Log Analytics workspace the function needs to authenticate to. The default name for this table is azureworkspaces, but can be changed if the matching Application Settings value for this setting matches.

| Column Name  | Description                                                  | Example                                                      |
| ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| PartitionKey | The name of the Partition Key that is being used for this instantiation of the Azure Function. | Part1                                                        |
| RowKey       | The name that you are giving the Azure Log Analytics workspace and is cross referenced in the s3logconfigs table. Must be a unique value, to enable the Partition Key and Row Key combination to be unique within the table.  Suggestion that you use the actual name of the Log Analytics workspace that the details refer to. | My-Log-Analytics-WS                                          |
| WorkspaceID  | The workspace ID value from your Log Analytics workspace in Azure. | e7402991-d02f-4f8f-bd84-729cd1f96c91                         |
| WorkspaceKey | The primary or secondary key for the Log Analytics workspace, Be aware that if you regenerate this key in Azure you will need to update this value here in the table. | bsdfgsdrQyTljl1qtABNhvSi56sdfgaH2TuF9/ RLPsGVbkwifIyh04eVN4tI/0oJGhtylKF1q4VO0b6fYBirQ== |
| AzureCloud   | The Log Analytics end point (URI) for Log Analytics workspaces is different for Azure Commercial and Government clouds. This setting enables the function to direct the data ingestion to the right cloud. The two values that are recognised is "Commercial" and "Government" if it is null or doesn't match it is defaulted by the Function to "Commercial" | Commercial                                                   |

### Table s3logconfigs

This table stores configuration information required to identify and process a log file on a AWS s3 bucket. One entry is required for each unique combination of Log file source location, Log File type and Log Analytics destination Table. The default name for this table is s3logconfigs, but can be changed if the matching Application Settings value for this setting matches.

| Column Name         | Description                                                  | Example                                        |
| ------------------- | ------------------------------------------------------------ | ---------------------------------------------- |
| PartitionKey        | The name of the Partition Key that is being used for this instantiation of the Azure Function. | Part1                                          |
| RowKey              | The name that you are giving the configuration for this particular log files ingestion. Must be a unique value, to enable the Partition Key and Row Key combination to be unique within the table. | myciscoasa                                     |
| AWSProfileNameS3    | The AWS Credential Profile name that has been given to the AWS Credentials required to authenticate to the  s3 bucket that stores the log file that needs to be collected. This value needs to also be the value used in Azure KeyVault to store the credentials, they must match for the system to be able to find and retrieve them from the Azure Key Vault. | myAWScredentials                               |
| AWSRegion           | AWS requires the name of the region where the s3 bucket is hosted. | ap-southeast-1                                 |
| LogAnalyticsTable   | This is the custom table name minus the "_CL" that you would like the data ingested into in the Log Analytics Workspace. Multiple Log configs can ingest into the same table if desired. | firewall                                       |
| LogFormat           | The function scripts need to know what type of log file structure is being used. To successfully read the file. By default the function will treat a log file as a one event per row structure, which is the most common. In particular if it is a JSON file then it needs to be read differently. Accepted values are "JSON", "CSV","SYSLOG","CEF" | JSON                                           |
| LogParseName        |                                                              |                                                |
| LogKeyMatch         | This a regex pattern to validate the keypath in the AWS SQS message, to help avoid ingestion of log files that shouldn't be ingested. How complex or simple you create this pattern will depend on what level of certainty you have that the SQS queues are only sending messages for log files that should be ingested. This regex pattern also enables you to differentiate different log file configs for files that are stored on the same s3 bucket. | logtest/\d+/\d+/\d+/data_test1\d+-\d+-\d+\.zip |
| ParsingInstructions | For each log file being ingested, the system needs to have instructions on how to interpret the contents of the file. The Azure Function requires you to provide a PowerShell Module file that it can load inline during execution. More detailed information on creating parsing instructions are (Still need to do thisTBD) | myparse.psm1                                   |
| ResoureID           | If you require Log Analytics Custom Table row level RBAC, the ResourceID value for this log type needs to be provided during ingestion. |                                                |
| TimeStampField      | By Default Log Analytics Data Ingestion will use the time of ingestion as the TImeGenerated value in the table. There is an option for ingestion to be configured to use one of the fields from the Data itself instead. This column stores the name of the field from your data that you want to be used for the TImeGenerated in the table. This field must be in a time format that the ingestion process recognises. | eventtime                                      |
| WorkSpaceName       | The value of the RowKey in the azureworkspaces table that holds the details of the Log Analytics Workspace that the data is to be ingested into. | My-Log-Analytics-WS                            |
| s3Bucket            | The Name of the AWS s3 bucket that this log file is stored on. Each configuration can only be found in one s3 bucket. If you have multiple s3 buckets storing the same log files, you will need a separate config line for each one. | mys3bucket                                     |
| s3Key               | This field is not used by the Functions at the moment, however it is good practice to store the core key path on the s3 bucket where the log files are normally found. | logs/firewall/2020/                            |

## Azure Key Vault

This Log Ingestion Pipeline utilises Azure Key Vault to securely store the AWS Credentials that are required to access the various AWS resources.

### Storing AWS Credentials

For the Log Ingestion to authenticate to the AWS resources it requires valid AWS Credentials. These credentials can be a standard IAM or a Cross-Account Role IAM. The system uses the AWS PowerShell Cmdlet to set and get AWS credentials and they will be stored in a .AWS folder on the Azure Function as per the normal operation of those Cmdlet.

Depending on what type of credential you will be using will determine which information you require, refer to AWS documentation for more information.

**Standard AWS IAM**

| AWS Attribute     | Description                                                  | Example                                   |
| ----------------- | ------------------------------------------------------------ | ----------------------------------------- |
| Access Key ID     | The generated Access Key for the identity you will be using  | AKZARIQF5YFXD34L5PN                       |
| Secret Access Key | The secret which has been generated for this Key. If you delete or disable the secret in AWS you will need to update this value. | Y2ZOpiSW8dZb4ZTEjiE4o5SFwpM1JfrYELS54bW/g |

**Cross-Account Role**

| AWS Attribute     | Description                                                  | Example                                     |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------- |
| Access Key ID     | The generated Access Key for the identity you will be using for the base tenancy Identity | AKZARIQF5YFXD34L5PN                         |
| Secret Access Key | The secret which has been generated for this Key for the base tenancy Identity. If you delete or disable the secret in AWS you will need to update this value. | Y2ZOpiSW8dZb4ZTEjiE4o5SFwpM1JfrYELS54bW/g   |
| Role ARN          | The AWS Role setup in the tenancy where the resource is hosted. | arn:aws:iam::111111111111:role/crossaccount |
| ExternalID        | AWS Cross-Account Role has an optional attribute called external ID, if this is required for this Cross-Account Role. | asdfgdsafg                                  |
|                   |                                                              |                                             |

**Storing the secret in Azure KeyVault**

These details are stored in Azure Key Vault as a secret, in addition the all details are stored in the one secret. To store the AWS Credentials follow these instructions.

1. The details for the AWS Credentials are stored as a ';' separated string, in the following order

   AccessKeyID;SecretAccessKey;RoleARN;ExternalID

2. The secret needs to be stored under the AWS Profile name that you have chosen to use in your configs for SQS Queues and s3 Buckets in the configuration Tables. This is the key that links your configuration required credentials to the storage of them in Azure Key Vault.

3. To store the credentials in the Azure Key Vault, this can be done through the portal, CLI or a script. 

4. If you prefer to do it manually through the Portal navigate to your Key Vault, select secrets and add\generate a new secret.

   ![AzureKeyVaultSecret](.\images\image-20200914094900331.png)



# Parsing/Transforming Log Files to ingest into Azure Sentinel

Log files come in all sorts of formats and variations. To manage this we need the ability to provide instructions to the Ingestion Pipeline that are specific for each situation. The Ingestion Pipeline achieves this by providing the ability for a custom set of instructions to be loaded for each log file as it is processed. These instructions take the form of a PowerShell 7.x Module file that contains a single PowerShell Function which you insert the required PowerShell commands required to transpose and transform the source data into JSON.

## Structure of the PowerShell Module

The PowerShell Module can be called whatever name is convenient, however there are several important guidelines that need to be followed for the  pipeline to successfully load and utilise the instructions provided.

1. The file must be a PowerShell Module with the file extension ".psm1"
2. The File should only contain the single function , which must be called "ParseInstructions"
3. A single Parameter is used by the Function to receive the Log Events to be processed, this parameter must be called ""$LogEvents".
4. Your code must not generate any output except for the final clean Log Events in JSON format.

An example shell of the Function code is below

```
FUNCTION ParseInstructions {
  Param($LogEvents)
  #Powershell commands to convert input to JSON
  .
  .
  .
  #last line before closing function Variable of the JSON to return to the main code
  $JSON 
}
```

In the GitHub Repository for this Azure Function code in the Tools folder there is a Test Harness PowerShell script file which you use to test and validate your Parsing Instructions before uploading it to the Azure Function.

## Design Considerations

During testing and development of your instructions take into consideration the following helpers

1. Make use of the PowerShell cmdlet "Measure-Command {}" to monitor how long your code takes to parse a log file.
2. There are a few helper functions that have been provided in the "LogParser" PowerShell Module to help breakdown a Key Value pair event log.
3. Review the time it takes for a log file to process and how often that type of log will be processed each day, some log files can be 700MB which can take more than 1 hour to process.

## Deployment of your Parsing Instructions

To deploy your log files Parsing Instructions requires following steps.

1. Upload the .PSM1 file to the Azure Storage Account - Blob Storage used by the Azure Function. The name of the storage account can be identified in the application settings in your function. In the value string for the AzureWebJobsStorage look for the value associated with "AccountName="
2. Using Microsoft Azure Storage Explorer - connect to your subscription and find the storage account in the list.
3. Expand the Blob Containers and create a new container called "logparsers"
4. Upload your .PSM1 file into that container.
5. In your s3logsconfig make sure the full name including the file extension matches the value you have in the ParsingInstructions column for that log files configuration.