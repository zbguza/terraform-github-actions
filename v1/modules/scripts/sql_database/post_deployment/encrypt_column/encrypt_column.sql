DECLARE @SchemaName NVARCHAR(128) = '[schemaName]';
DECLARE @TableName NVARCHAR(128) = '[tableName]';
DECLARE @ColumnName NVARCHAR(128) = '[columnName]';

DECLARE @DatabaseMasterKeyValue NVARCHAR(256) = '[databaseMasterKeyValue]';

DECLARE @ColumnMasterKeyName NVARCHAR(128) = '[columnMasterKeyName]';
DECLARE @ColumnMasterKeyVaultURL NVARCHAR(256) = 'https://[encryptionKeyVaultName].vault.azure.net/secrets/[columnMasterKeyName]';

DECLARE @ColumnEncryptionKeyName NVARCHAR(128) = '[columnKeyName]';
DECLARE @ColumnEncryptionKeyValue VARBINARY(MAX) = '[columnKeyValue]';


-- Check if Database Master Key exists. If not, create it.
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    EXEC('CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @DatabaseMasterKeyValue+ ''';');
END


-- Check if Column Master Key exists. If not, create it from the Key Vault.
IF NOT EXISTS (SELECT * FROM sys.column_master_keys WHERE name = @ColumnMasterKeyName)
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'CREATE COLUMN MASTER KEY ' + QUOTENAME(@ColumnMasterKeyName) + N'
                WITH VALUES (
                    KEY_STORE_PROVIDER_NAME = ''AZURE_KEY_VAULT'',
                    KEY_PATH = @ColumnMasterKeyVaultURL
                );';

    EXEC sp_executesql @sql, N'@ColumnMasterKeyVaultURL NVARCHAR(256)', @ColumnMasterKeyVaultURL;
END


-- Check if Column Encryption Key exists. If not, create it.
IF NOT EXISTS (SELECT * FROM sys.column_encryption_keys WHERE name = @ColumnEncryptionKeyName)
BEGIN
    DECLARE @sqlColumnEncryptionKey NVARCHAR(MAX);
    SET @sqlColumnEncryptionKey = N'CREATE COLUMN ENCRYPTION KEY ' + QUOTENAME(@ColumnEncryptionKeyName) + N'
                 WITH VALUES (
                     COLUMN_MASTER_KEY = ' + QUOTENAME(@ColumnMasterKeyName) + N',
                     ALGORITHM = ''RSA_OAEP'',
                     ENCRYPTED_VALUE = @ColumnEncryptionKeyValue
                 );';

    EXEC sp_executesql @sqlColumnEncryptionKey, N'@ColumnEncryptionKeyValue VARBINARY(MAX)', @ColumnEncryptionKeyValue;
END


-- Check if encryption exists on a target column.
IF NOT EXISTS (SELECT * 
               FROM sys.columns AS columns
               JOIN sys.tables AS tables ON columns.object_id = tables.object_id
               JOIN sys.schemas AS schemas ON tables.schema_id = schemas.schema_id
               WHERE schemas.name = @SchemaName AND tables.name = @TableName AND columns.name = @ColumnName AND columns.is_encrypted = 1)
BEGIN
    DECLARE @sqlColumnEncryption NVARCHAR(MAX);
    SET @sqlColumnEncryption = N'ALTER TABLE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' 
                ALTER COLUMN ' + QUOTENAME(@ColumnName) + N' 
                ADD ENCRYPTION 
                WITH (COLUMN_ENCRYPTION_KEY = ' + QUOTENAME(@ColumnEncryptionKeyName) + N', 
                      ENCRYPTION_TYPE = DETERMINISTIC, 
                      ALGORITHM = ''AEAD_AES_256_CBC_HMAC_SHA_256'');';

    EXEC sp_executesql @sqlColumnEncryption;
END