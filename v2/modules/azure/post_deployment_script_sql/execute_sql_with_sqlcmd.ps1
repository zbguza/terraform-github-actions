Param (
    [string]$ScriptFilePath,
    [string]$SqlDatabaseName,
    [string]$ServerName,
    #Should be used for local testing only:
    [bool]$UserLocalCredentials = $false,
    #Comma-separated list of key-value pairs, e.g. "key1=value1,key2=value2"
    [string]$SqlArguments
)
Write-Verbose "Script file path: $ScriptFilePath"
Write-Verbose "SQL Database name: $SqlDatabaseName"
Write-Verbose "Server name: $ServerName"
Write-Verbose "Using local credentials: $UserLocalCredentials"
Write-Verbose "SQL Arguments: $SqlArguments"

if ($UserLocalCredentials) {
    Write-Host 'Using local credentials to authenticate...'
    try {
        $null = Get-AzContext
        Write-Verbose "Previous context available, no additional actions needed; successfully authenticated."
    }
    catch {
        Write-Verbose "No Azure connection active yet; connecting Az account..."
        Connect-AzAccount -AccountId $accountId #TODO implement this as param at some point
    }
}
else {
    $tenantId = $env:ARM_TENANT_ID;
    $clientId = $env:ARM_CLIENT_ID;
    $secret   = $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN;

    Connect-AzAccount -ServicePrincipal -Tenant $tenantId -ApplicationId $clientId -FederatedToken $secret -Environment AzureCloud -Scope Process
}

if (Get-Module -ListAvailable -Name "SqlServer") {
    Write-Verbose "SQL Server module is installed"
} 
else {
    Write-Verbose "Installing SQL Server module module..."
    Install-Module -Name "SqlServer" -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    Write-Verbose "SQL Server module installed!"
}

$token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Parse $SqlArguments into a hashtable
$sqlVariables = @{}
if (-not [string]::IsNullOrEmpty($SqlArguments)) {
    $SqlArguments.Split(',') | ForEach-Object {
        $key, $value = $_.Split('=')
        $sqlVariables[$key.Trim()] = $value.Trim()
    }
}

Write-Host "Executing '$ScriptFilePath' on Server '$ServerName' with Database '$SqlDatabaseName'"
try {
    Invoke-Sqlcmd `
        -ServerInstance $ServerName `
        -Database $SqlDatabaseName `
        -InputFile $ScriptFilePath `
        -Variable $sqlVariables `
        -AbortOnError `
        -QueryTimeout 3600 `
        -OutputSqlErrors $true `
        -AccessToken "$token" `
        -verbose `
        4>&1 | `
        ForEach-Object { if ($_.Message) { "$(TimeStamp) " + ($_.Message).ToString() } } `
    | Write-Host
}
catch {
    $errorMessage = "Failed to execute SQL script: $($_.Exception.Message)"
    $errorDetails = $_.Exception.ToString()
    Write-Host "Error: $errorMessage" -ForegroundColor Red
    Write-Host "Error Details: $errorDetails" -ForegroundColor Red
    throw $errorMessage
}