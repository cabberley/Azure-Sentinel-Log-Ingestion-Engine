##Log parsing Centralised conversion of data to Json based on


Function ConvertTo-AzureSentinelJson {
    #For AWS Cloudwatch pass the message in at the Events level as 
    #sometimes we might want the IngestionTime Key and not just the message
    param (
        $message,
        $ConversionType
        )
        if('json' -ceq $ConversionType){
            #Cloudwatch Json message format used for some of their logs
                $JsonMessage = "["
                foreach($event in $message.message)
                {$JSonMessage = $JsonMessage + $event +","}
                $Length = $JsonMessage.Length-1
                $JsonMessageX =$JsonMessage.Substring(0,$Length)
                $message1 = $JsonMessageX+"]"
        }
        elseif('cloudwatchvpcflow' -ceq $ConversionType){
            #Cloudwatch VPC format is a CSV style with headers?
    
    
        }
        elseif('cloudwatchRoute53' -ceq $ConversionType){
            #Cloudwatch VPC format is a CSV style with headers?
    
    
        }
        elseif('cloudwatchLambda' -ceq $ConversionType){
            #Cloudwatch VPC format is a CSV style with headers?
    
    
        }
        Return Write-output -NoEnumerate $message1
    }
    
Function ConvertTo-KeyValue {
    PARAM(
        $s)
    $qw = $null
    $qw = @{}
    Do {
        $key = $s.Substring(0, $s.indexOf('='))
        $s = $S.Substring($key.Length + 1)
        if ( $s.indexof('=') -gt 0) {
            $temp = $s.substring(0, $s.indexof('='))
        }
        else {
            $temp = $s
        }
        if (($temp.LastIndexOf(' ') -gt 0) -and ($s.indexof('=') -gt 0) ) {
            $value = $temp.Substring(0, $temp.LastIndexOf(' '))
            $s = $S.Substring($value.Length + 1)
        }
        else {
            $value = $temp
            $s = $S.Substring($value.Length)
        }
        $value = $value.replace('"', '')
        $kv = @{$key = $value }
        $qw += $kv
    }until($s.Length -eq 0)
    Return Write-Output -NoEnumerate $qw
}

Function ConvertTo-KeyValue2 {
    PARAM(
        $s)

    $segments = $s -split ('=')
    $Count = $segments.count
    $parsedrow = [Hashtable]::new($Count)
    $i = 0
    DO {
        $i ++
        if ($i -eq 1) {
            $parsedrow[$Segments[($i - 1)]] = $Segments[$i].Substring(0, $Segments[$i].LastIndexOf(' '))
        }
        elseif ($i -eq $count - 1) {
            $parsedrow[$Segments[($i - 1)].Substring($Segments[$i - 1].LastIndexOf(' ') + 1)] = $Segments[$i]
            #last
        }
        else {
            $parsedrow[$Segments[($i - 1)].Substring($Segments[$i - 1].LastIndexOf(' ') + 1)] = $Segments[$i].Substring(0, $Segments[$i].LastIndexOf(' '))
        }
    }until(($count - 1) -eq $i)

    Return Write-Output -NoEnumerate $parsedrow
}

#Function Edit-NormaliseDataKeyValue
#Input $EventdataND  message as an object with each row a seperate item
#Input $DataDictionaryND $DataDictionary.psobject.properties
Function Edit-NormaliseDataKeyValue {
    Param ($EventdataND,
        $DataDictionaryND)
    if ($Null -ne $DataDictionaryND) {
        foreach ($DDKey in $DataDictionaryND) {
            IF ('Etag', 'PartitionKey', 'TableTimeStamp', 'RowKey' -notcontains $DDKey.Name) {
                $EventField = $DDKey.Value
                $EVentField
                $EventDataND.Add($DDKey.Name, $EventdataND.$EventField)
                $EventDataND.remove($EventField)
            }
        }
    }
    Return Write-Output -NoEnumerate $EventDataND
}


Export-ModuleMember -Function Edit-NormaliseDataKeyValue
Export-ModuleMember -Function ConvertTo-KeyValue
Export-ModuleMember -Function ConvertTo-KeyValue2
Export-ModuleMember -Function ConvertTo-AzureSentinelJson 