--  We will create a custom role for the DB writers security group as the
--  default built-in role of db_datawriter also grants DELETE privileges, which
--  we do not want.

-- Define the custom role, make it so db_securityadmin built-in role is the
-- owner
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_writer_custom' AND type = 'R')
BEGIN
    CREATE ROLE db_writer_custom AUTHORIZATION db_securityadmin;
END
GO

-- Grant appropriate permissions to the role.
GRANT SELECT, UPDATE, INSERT ON DATABASE::[$(database_name)] TO db_writer_custom;
GO

-- Define the security group if it doesn't exist.
IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '$(security_group_name)' )
BEGIN
	CREATE USER [$(security_group_name)] FROM EXTERNAL PROVIDER;
END
GO

-- Add the security group to the DB role.
ALTER ROLE db_writer_custom ADD MEMBER [$(security_group_name)];
GO