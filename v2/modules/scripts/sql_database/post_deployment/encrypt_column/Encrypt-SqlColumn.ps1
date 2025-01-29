Param (
    [string]$ScriptFilePath,
    [string]$SqlDatabaseName,
    [string]$ResourceGroupName,
    [string]$ServerName,
    [bool]$UserLocalCredentials = $false, # Should be used for local testing only.
    [string]$ScriptArguments
)

if ($UserLocalCredentials) {
    Write-Host 'Using local credentials to authenticate...'
    try {
        $null = Get-AzContext
        Write-Verbose "Prvious context available, no additional actions needed; successfully authenticated."
    }
    catch {
        Write-Verbose "No Azure connection active yet; connecting Az account..."
        Connect-AzAccount -AccountId $accountId
    }
}
else {
    $tenantId = $env:ARM_TENANT_ID;
    $clientId = $env:ARM_CLIENT_ID;
    $secret = $env:ARM_CLIENT_SECRET;

    Write-Host 'Interactive signing in to Azure due to MFA requirements'

    az login --service-principal --username $clientId --password $secret --tenant $tenantId --output none
}

if (Get-Module -ListAvailable -Name "SqlServer") {
    Write-Verbose "SQL Server module is installed"
} 
else {
    Write-Verbose "Installing SQL Server module module..."
    Install-Module -Name "SqlServer" -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    Write-Verbose "SQL Server module installed!"
}

$token = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken

# Amending script to match current setup
$script = Get-Content -Path "$ScriptFilePath"

$jsonArgument = ConvertFrom-Json "$ScriptArguments"
foreach($attribute in $jsonArgument.PSObject.Properties.Name)
{
    $name = $attribute
    $value = $jsonArgument.$attribute

    # Get encryption key from the KV based on key name
    if ($attribute.EndsWith("KeyName"))
    {
        $script = $script.Replace("[$name]", $jsonArgument.$attribute)

        $encryptionKey = Get-AzKeyVaultSecret -VaultName "$($jsonArgument.encryptionKeyVaultName)" -Name "$($jsonArgument.$attribute)"
        $value = Unprotect-Secret $encryptionKey.SecretValue
        
        $name = $name.Replace("KeyName", "KeyValue")
        $script = $script.Replace("[$name]", $value)

    }
    else
    {
        $script = $script.Replace("[$name]", $value)
    }
}

$script | Set-Content -Path "$ScriptFilePath"


# Execute SQL script
Write-Host "Executing '$ScriptFilePath' on Server '$ServerName' with Database '$SqlDatabaseName'"
Invoke-Sqlcmd `
    -ServerInstance $ServerName `
    -Database $SqlDatabaseName `
    -InputFile $ScriptFilePath `
    -AbortOnError `
    -QueryTimeout 3600 `
    -OutputSqlErrors $true `
    -AccessToken "$token" `
    -verbose `
    4>&1 | `
    ForEach-Object { if ($_.Message) { "$(TimeStamp) " + ($_.Message).ToString() } } `
| Write-Host