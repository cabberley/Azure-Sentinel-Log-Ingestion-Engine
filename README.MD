# Azure Sentinel - AWS s3 Logs Ingestion Toolbox

## Summary

This set of Azure functions provides an ingestion pipeline to retrieve logs from s3 buckets, transform the log file structure into the required Log Analytics HTTP API Json format and ingest them into Log Analytics Custom Tables.

## Background on the ToolBox

This Azure Sentinel Data Connector (group of functions) for Log Ingestion came about from an Azure Sentinel implementation where there was a requirement to ingest more than 2.5TB (**Yes Terabytes!**) a day from a variety of sources and log formats, where all the logs are staged on AWS s3 buckets. There was wide variety of log file sizes and frequencies as well to consider. Further requirements also meant we couldn't change the how the logs were being generated and stored on the s3 buckets, at least initially. 

To solve this ingestion requirement, we could have deployed solutions like Logstash or other solutions which all require underlying Virtual Servers. This approach creates other overheads and operational management requirements to maintain the Virtual Servers, manage scale out and in during the 24 hour ingestion cycle etc. 

The other consideration for large scale Log ingestion from sources outside Azure is the Data Egress costs. For small volumes of data this is not an issue but for 2.5TB that adds up quickly. There are however some options to reduce that significantly, Log files are predominately "white space" and standard file compression options can reduce a log file to 10-15% of the original size. The Log Analytics HTTP RestAPI does not accept compressed, but there is no egress cost between an Azure Resource and the HTTP RestAPI if they are in the same region.

## Overview of the Ingestion Toolbox

This log Ingestion pipeline has been architected to be modular, scalable and flexible using the power of Azure Functions to provide a serverless solution. While this first version is focused on collecting Log files from AWS s3 buckets, other functions can be added to collect log files from other sources and incorporated into the ingestion pipeline.

The Pipeline relies on using the s3 bucket audit capability to generate a message when a new file is created, this message is configured to be inserted onto an AWS SQS messaging queue. Periodically the Azure function checks the message queue\s for new messages, if it finds one it reads it. It then reads the message on takes the required information from the message, retrieves the file and stores it on Azure Storage. Once stored locally it then puts the details of the logfile into the list of files (using an Azure Storage message queue) that need to be processed. The final stage is to then process the log file, restructure its contents if required and post it to the Log Analytics HTTP RestAPI.

**Some of the features and benefits of this pipeline:**

1. Scale out and processing in parallel for both the retrieval stage and the log processing phase. 

2. Helps contain Data transfer costs for Egress out of AWS by allowing the log file to stay compressed during the transfer between AWS and Azure. (There are AWS Lambda Function examples which demonstrate compressing a new file when it lands on a s3 bucket if your log files are not already compressed.)

3. Most logfiles fall into 1 of 2 categories, a file which has an event per line or multine events like Json with a record delimiter. This function has been designed so the core code does not need to be changed for every differant log file. It relies on loading at runtime a seperate PowerShell module file that is selected based on the config. Minimising the potential of a code change for one log file causing the whole pipeline to stop working.

4. Configuration parameters for each log file are stored in Azure Storage tables, so any new log files or changes to a log files processing are independant of the Azure Function itself. Again minimising potentially breaking the Azure Function with a bad config.



