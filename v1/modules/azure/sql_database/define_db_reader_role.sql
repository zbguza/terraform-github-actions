-- Define the security group if it doesn't exist.
IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '$(security_group_name)' )
BEGIN
	CREATE USER [$(security_group_name)] FROM EXTERNAL PROVIDER;
END
GO

-- Add the security group to the reader DB role.
ALTER ROLE db_datareader ADD MEMBER [$(security_group_name)];
GO