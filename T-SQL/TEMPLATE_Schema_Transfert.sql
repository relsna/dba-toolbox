USE [<Database_Name, sysname, CARL_CS04>];
BEGIN
	DECLARE schemaObjectsCursor CURSOR FOR 
		SELECT name
		FROM sys.objects
		WHERE schema_id = SCHEMA_ID(UPPER('<Src_Schema_Name, sysname, name>'))
		AND type in ('U','SO','V','P','FN','IT')

	DECLARE @objectName SYSNAME
	DECLARE @sql VARCHAR(1024)

	OPEN schemaObjectsCursor
	FETCH NEXT FROM schemaObjectsCursor INTO @objectName
	
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @sql = 'ALTER SCHEMA [<Dst_Schema_Name, sysname, CARL_CS04>] TRANSFER [<Src_Schema_Name, sysname, name>].[' +
@objectName + ']'
			--PRINT @sql
			EXEC(@sql)
			FETCH NEXT FROM schemaObjectsCursor INTO @objectName
		END
	
	CLOSE schemaObjectsCursor
	DEALLOCATE schemaObjectsCursor
END;