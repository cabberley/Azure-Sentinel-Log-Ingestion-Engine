#module Imports
import-module -Name AWS.Tools.Common
import-module -Name AWS.Tools.SecurityToken
import-module -Name Az.KeyVault

#confirm-validregion -awsregion 'us-east-1'
Function Confirm-ValidRegion {
param(
    $Aregion
    )
    $regions = (Get-AWSRegion -includechina -includegovcloud).region
    if($regions.Contains($Aregion)){
        Return $True
    }
    else{
        Return $False
    }
}


Function Set-CWCredential {
param(
    $PKey,
    $KVault,
    $Region
    )
    $Creds = $null
    $secrets = $null
    $secrets1 = $null
    $ARN = $False
    $ExID = $False
    $Secrets = (Get-AzKeyVaultSecret -VaultName $KVault -Name $PKey).SecretValueText
    $secrets1 = $Secrets.split(';')
    if($secrets1.count.Equals(3)){$ARN = $True}
    if($secrets1.count.Equals(4)){$ExID = $True}
    if ($ExID){
        Set-AWSCredential `
         -StoreAs $PKey `
         -AccessKey $Secrets1[0] `
         -SecretKey $Secrets1[1] `
         -Region $Region

        $Credstemp = Get-AWSCredential -ProfileName $PKey
        $Creds = Use-STSRole -RoleArn $Secrets1[2] -RoleSessionName "AzureSentinel" -Credential $credstemp -Region $Region -ExternalId $Secrets1[3]
        $Credentials = $Creds.Credentials 
    }
    Elseif($ARN){
        Set-AWSCredential `
         -StoreAs $PKey `
         -AccessKey $Secrets1[0] `
         -SecretKey $Secrets1[1] `
         -Region $Region

        $Credstemp = Get-AWSCredential -ProfileName $PKey
        $Creds = Use-STSRole -RoleArn $Secrets1[2] -RoleSessionName "AzureSentinel" -Credential $credstemp -Region $Region
        $Credentials = $Creds.Credentials 
    }
    Else{
        Set-AWSCredential `
         -StoreAs $PKey `
         -AccessKey $Secrets1[0] `
         -SecretKey $Secrets1[1] 
             
        $Creds = Get-AWSCredential -ProfileName $PKey
        $Credentials = $Creds.credentials
    }
    Return Write-output -NoEnumerate $Credentials 
}

  Export-ModuleMember -Function Set-CWCredential
  Export-ModuleMember -Function Confirm-ValidRegion