/*
Run this script to update the schema of SQL Backup Helper from v0.9 to v1.0
*/
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE id=OBJECT_ID('tempdb..#tmpErrors')) DROP TABLE #tmpErrors
GO
CREATE TABLE #tmpErrors (Error int)
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
PRINT N'Altering [dbo].[Settings]'
GO
ALTER TABLE [dbo].[Settings] ADD
[Description] [nvarchar] (300) COLLATE Latin1_General_CI_AS NULL
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetCloneFolder]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Returns the temporary clone foldername
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetCloneFolder] 
(
)
RETURNS NVARCHAR(256)
AS
BEGIN
	
	DECLARE	@path	NVARCHAR(256)
	SET @path = ''

	SELECT @path = @path + LTRIM(RTRIM([Value])) FROM Settings WHERE [Key] = 'CloneTempFolder'		-- clone temp path

	IF (RIGHT(@path, 1) <> '\') SET @path = @path + '\'

	RETURN @path

END





GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetBackupFile]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Returns the latest backup filename for a database
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetBackupFile]
(
	@dbName	NVARCHAR(100),
	@dbID	INT
)
RETURNS NVARCHAR(4000)
AS
BEGIN

	IF (@dbID IS NULL)	SET @dbID = DB_ID(@dbName)

	RETURN(	SELECT TOP 1 BackupFile
			FROM Backups 
			WHERE BackupType = 'FULL'
				AND DatabaseName = @dbName
				AND DatabaseID = @dbID
			ORDER BY [TimeStamp] DESC )

END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_SplitString]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Splits a NVARCHAR into a table
-- =============================================
ALTER FUNCTION [dbo].[UDF_SplitString]
(	
	@string		NVARCHAR(4000),
	@delimiter	CHAR(1)
)
RETURNS @tokens TABLE ( Position INT IDENTITY, Token NVARCHAR(4000) )
AS
BEGIN

	DECLARE @cr VARCHAR(1)
	SET @cr = CHAR(10)

	DECLARE @lf varchar(1)
	SET @lf = CHAR(13)

	IF @string IS NULL RETURN

	DECLARE @pattern	CHAR(3)

	SET @pattern = '%' + @delimiter + '%'

	SELECT @string = @string + @delimiter			-- add trailing delimiter

	DECLARE @pos		INT
	SELECT @pos = PATINDEX(@pattern, @string)

	WHILE (@pos <> 0) 
	BEGIN

		DECLARE @token VARCHAR(4000)
		SELECT @token = LTRIM(RTRIM(SUBSTRING(@string, 1, @pos - 1)))

		SELECT @token = REPLACE(@token, @cr, '')
		SELECT @token = REPLACE(@token, @lf, '')

		INSERT @tokens VALUES (@token)

		SELECT @string = STUFF(@string, 1, PATINDEX(@pattern, @string),'')
		SELECT @pos = PATINDEX(@pattern, @string)

	END

	RETURN

END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetAffectedBackups]'
GO
-- =============================================
-- Author:		Thomas Stensitzki	
-- Create date: 2008-10-20
-- Description:	Returns a table containing present backups of databases with backuptype FULL
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetAffectedBackups] 
(	
	@includeDbName		NVARCHAR(4000) = NULL,
	@excludeDbName		NVARCHAR(4000) = NULL
)
RETURNS @affected TABLE ( BackupID INT )
AS
BEGIN

	IF (@includeDbName IS NULL) SET @includeDbName = '%'
	IF (@excludeDbName IS NULL) SET @excludeDbName = ''

	INSERT INTO @affected
	SELECT baks.BackupID
	FROM Backups baks
		INNER JOIN dbo.UDF_SplitString(@includeDbName, ',') inc
				ON baks.DatabaseName LIKE inc.Token
	WHERE baks.BackupType = 'FULL'

	DELETE aff 
	FROM @affected aff
		INNER JOIN Backups baks
				ON aff.BackupID = baks.BackupID
				INNER JOIN dbo.UDF_SplitString('%oc', ',') exc
						ON baks.DatabaseName LIKE exc.Token

	RETURN

END


GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_ExistFile]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Check if file exists
-- =============================================
ALTER PROCEDURE [dbo].[USP_ExistFile] 
	@path	NVARCHAR(4000),
	@exist	BIT OUT
AS
BEGIN

	SET NOCOUNT ON;

	SET @exist = 1 -- exists by default

	CREATE TABLE #output (contents VARCHAR(300))

	DECLARE @shell VARCHAR(4000)
	SET @shell = 'dir "' + @path + '"'

	INSERT #output EXEC XP_CMDSHELL @shell

	IF EXISTS(	SELECT 1
				FROM #output 
				WHERE 
					-- Locale EN
					   contents = 'The system cannot find the file specified.' 
					OR contents = 'The system cannot find the path specified.'
					OR contents = 'File Not Found' 
					-- Locale DE
					OR contents = 'Datei nicht gefunden'
					OR contents = 'Das System kann die angegebene Datei nicht finden.' 
					OR contents = 'Das System kann den angegebenen Pfad nicht finden.'
			  ) SET @exist = 0

	DROP TABLE #output

END


GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_ExistFolder]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Check if folder exists
-- =============================================
ALTER PROCEDURE [dbo].[USP_ExistFolder] 
	@path	NVARCHAR(4000),
	@exist	BIT OUT
AS
BEGIN

	SET NOCOUNT ON;

	IF ( @path IS NOT NULL AND RIGHT(@path, 1) <> '\' )
		SET @path = @path + '\'

	EXEC USP_ExistFile @path, @exist OUT

END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetFolderNameFromShell]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Extracts foldername from shell command line return value
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetFolderNameFromShell] 
(
	@shellLine NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN

	DECLARE @dirPattern NVARCHAR(7)
	SET @dirPattern = '%<DIR>%'

	IF (PATINDEX(@dirPattern, @shellLine) = 0) RETURN NULL

	DECLARE @dirName NVARCHAR(4000)
	SET @dirName = LTRIM(RTRIM(SUBSTRING(@shellLine,PATINDEX(@dirPattern, @shellLine)+len(@dirPattern), len(@shellLine))))

	IF (@dirName = '.') RETURN NULL
	IF (@dirName = '..') RETURN NULL

	RETURN @dirName

END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetFileNameFromShell]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Extracts a filename from shell command return value
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetFileNameFromShell] 
(
	@shellLine NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN

	DECLARE @dirPattern NVARCHAR(7)
	SET @dirPattern = '%<DIR>%'

	DECLARE @blankPattern NVARCHAR(3)
	SET @blankPattern = '% %'

	IF (PATINDEX(@dirPattern, @shellLine) > 0) RETURN NULL
	IF (LEFT(@shellLine, 1) NOT IN ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')) RETURN NULL

	SET @shellLine = LTRIM(RTRIM(SUBSTRING(@shellLine,18,len(@shellLine))))

	RETURN LTRIM(RTRIM(SUBSTRING(@shellLine, PATINDEX(@blankPattern, @shellLine), LEN(@shellLine))))

END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_CreateFolder]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Create a new folder in file system
-- =============================================
ALTER PROCEDURE [dbo].[USP_CreateFolder] 
	@path	NVARCHAR(4000)
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @exist	BIT
	EXEC USP_ExistFolder @path, @exist OUT

	IF (@exist = 0)
	BEGIN

		DECLARE @shell VARCHAR(4000)
		SET @shell = 'md "' + @path + '"'

		DECLARE @shellResult	INT
		EXEC @shellResult = XP_CMDSHELL @shell, no_output
		
		IF (@shellResult <> 0) PRINT 'Failed to created backup folder: ' + @path + CHAR(13)

	END

END





GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetHistoryFolder]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Returns history folder for a selected database
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetHistoryFolder] 
(
	@dbName		NVARCHAR(100) = NULL,
	@dbID		INT = NULL
)
RETURNS NVARCHAR(256)
AS
BEGIN	

	IF (@dbID IS NULL)	SET @dbID = DB_ID(@dbName)

	DECLARE	@path	NVARCHAR(256)
	SET @path = ''

	SELECT @path = @path + LTRIM(RTRIM([Value])) FROM Settings WHERE [Key] = 'HistoryRootFolder'		-- history root path

	IF (RIGHT(@path, 1) <> '\') SET @path = @path + '\'

	IF (@dbName IS NOT NULL OR @dbID IS NOT NULL)
	BEGIN
		
		IF (@dbName IS NULL) SET @dbName = DB_NAME(@dbID)
		IF (@dbID IS NULL) SET @dbID = DB_ID(@dbName)

		SET @path = @path + UPPER(@dbName) + ' (' + CAST(@dbID AS NVARCHAR) +')\'					-- history db folder

	END

	RETURN @path

END




GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetBackupFolder]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Returns the backup foldername for a database
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetBackupFolder] 
(
	@dbName		NVARCHAR(100) = NULL,
	@dbID		INT = NULL
)
RETURNS NVARCHAR(256)
AS
BEGIN	

	IF (@dbID IS NULL)	SET @dbID = DB_ID(@dbName)

	DECLARE	@path	NVARCHAR(256)
	SET @path = ''

	SELECT @path = @path + LTRIM(RTRIM([Value])) FROM Settings WHERE [Key] = 'BackupRootFolder'		-- backup root path

	IF	(RIGHT(@path, 1) <> '\') SET @path = @path + '\'

	IF (@dbName IS NOT NULL OR @dbID IS NOT NULL)
	BEGIN
		
		IF (@dbName IS NULL) SET @dbName = DB_NAME(@dbID)
		IF (@dbID IS NULL) SET @dbID = DB_ID(@dbName)

		SET @path = @path + UPPER(@dbName) + ' (' + CAST(@dbID AS NVARCHAR) +')\'					-- backup db folder

	END

	RETURN @path

END





GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_KillProcesses]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Kill processes eventually locking the database
-- =============================================
ALTER PROCEDURE [dbo].[USP_KillProcesses] 
	@dbName		NVARCHAR(500)
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @spid INT, 
		@cnt INT, 
		@sql VARCHAR(255) 
 
	SELECT @spid = MIN(spid), @cnt = COUNT(*) 
	FROM master..sysprocesses 
	WHERE dbid = DB_ID(@dbname) 
		AND spid != @@SPID 
 
	WHILE @spid IS NOT NULL 
	BEGIN 

		SET @sql = 'KILL ' + RTRIM(@spid) 
		EXEC(@sql) 
 
		SELECT @spid = MIN(spid), @cnt = COUNT(*) 
		FROM master..sysprocesses 
		WHERE dbid = DB_ID(@dbname) 
			AND spid != @@SPID 

	END 
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_CloneDatabase]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Clone selected database
-- =============================================
ALTER PROCEDURE [dbo].[USP_CloneDatabase] 
	@sourceDbName	NVARCHAR(500),
	@targetDbName	NVARCHAR(500)
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @dir	NVARCHAR(4000)
	SET @dir = dbo.UDF_GetCloneFolder()

	DECLARE @exist	BIT
	EXEC USP_ExistFolder @dir, @exist OUT 

	IF (@exist=0) EXEC USP_CreateFolder @dir

	DECLARE @bak	NVARCHAR(4000)
	SET @bak = @dir + UPPER(@sourceDbName) + ' CLONE.bak'

	DECLARE @set	NVARCHAR(500)
	SET @set = UPPER(@sourceDbName) + ' CLONE'

	BACKUP DATABASE @sourceDbName TO DISK = @bak WITH INIT, NOUNLOAD, NAME = @set, NOSKIP, STATS = 10, NOFORMAT, COPY_ONLY

	DECLARE @cmd	NVARCHAR(4000)

	IF EXISTS( SELECT 1 FROM master.sys.databases WHERE name = @targetDbName )
	BEGIN

		EXEC USP_KillProcesses @targetDbName

	END
	ELSE
	BEGIN

		SET @cmd = 'CREATE DATABASE ' + @targetDbName
		EXEC( @cmd )

	END

	CREATE TABLE #sourceFiles ( type TINYINT, name NVARCHAR(128), physical_name NVARCHAR(260) )

	SET @cmd = 'SELECT type, name, physical_name FROM ' + @sourceDbName + '.sys.database_files'
	INSERT INTO #sourceFiles EXEC( @cmd )

	CREATE TABLE #targetFiles ( type TINYINT, name NVARCHAR(128), physical_name NVARCHAR(260) )

	SET @cmd = 'SELECT type, name, physical_name FROM ' + @targetDbName + '.sys.database_files'
	INSERT INTO #targetFiles EXEC( @cmd )

	SET @cmd = 'RESTORE DATABASE ' + @targetDbName + ' ' +
				'FROM DISK = ''' + @bak + ''' ' +
				'WITH REPLACE'

	DECLARE file_cur CURSOR LOCAL FORWARD_ONLY FOR	
		SELECT DISTINCT src.name, trg.physical_name
		FROM #sourceFiles src
			INNER JOIN #targetFiles trg
				ON src.type = trg.type
	
	OPEN file_cur

	DECLARE @fileName	NVARCHAR(500)
	DECLARE @filePath	NVARCHAR(500)

	FETCH NEXT FROM file_cur INTO @fileName, @filePath

	WHILE (@@FETCH_STATUS=0)
	BEGIN
		
		SET @cmd = @cmd + ', MOVE ''' + @fileName + ''' TO ''' + @filePath + ''''

		FETCH NEXT FROM file_cur INTO @fileName, @filePath

	END

	CLOSE file_cur
	DEALLOCATE file_cur

	-- PRINT 'EXEC: ' + @cmd
	EXEC( @cmd )

	DROP TABLE #sourceFiles
	DROP TABLE #targetFiles

END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetFileName]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Extracts the filename from a file path
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetFileName]
(
	@path	NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN

	DECLARE @firstToken		NVARCHAR(4000)

	IF (@path IS NOT NULL)
	BEGIN

		SET @path = REVERSE(LTRIM(RTRIM(@path)))

		DECLARE @pos			INT
		SELECT @pos = PATINDEX('%\%', @path)

		IF (@pos <> 0)		SET @firstToken = REVERSE(SUBSTRING(@path, 1, @pos - 1))
		ELSE				SET @firstToken = @path

	END

	RETURN @firstToken

END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetTimeStamp]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Creates a unique timestamp
-- =============================================
ALTER FUNCTION [dbo].[UDF_GetTimeStamp] 
(
	@now	DATETIME
)
RETURNS NVARCHAR(15)
AS
BEGIN

	RETURN CONVERT(VARCHAR(50), @now, 112) + '-' + 
			CASE WHEN DATEPART(HH, @now) < 10 THEN '0' ELSE '' END + CAST(DATEPART(HH, @now) AS NVARCHAR) +
			CASE WHEN DATEPART(MI, @now) < 10 THEN '0' ELSE '' END + CAST(DATEPART(MI, @now) AS NVARCHAR) +
			CASE WHEN DATEPART(SS, @now) < 10 THEN '0' ELSE '' END + CAST(DATEPART(SS, @now) AS NVARCHAR)

END


GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[UDF_GetAffectedDatabases]'
GO


-- =========================================================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Returns a table containing the affected databases for backup
-- Changes:
-- 2011-10-27 TST: Include only databases with status ONLINE
-- =========================================================================
ALTER FUNCTION [dbo].[UDF_GetAffectedDatabases] 
(	
	@includeDbName		NVARCHAR(4000) = NULL,
	@excludeDbName		NVARCHAR(4000) = NULL
)
RETURNS @affected TABLE ( [Name] NVARCHAR(250) )
AS
BEGIN

	IF (@includeDbName IS NULL) SET @includeDbName = '%'
	IF (@excludeDbName IS NULL) SET @excludeDbName = ''

	INSERT INTO @affected
	SELECT dbs.[name]
	FROM master.sys.databases dbs
		INNER JOIN dbo.UDF_SplitString(@includeDbName, ',') inc
				ON dbs.name LIKE inc.Token
	WHERE dbs.[name] <> 'tempdb'
	AND dbs.state_desc = 'ONLINE'
	ORDER BY dbs.[name]

	DELETE dbs 
	FROM @affected dbs
		INNER JOIN dbo.UDF_SplitString(@excludeDbName, ',') exc
				ON dbs.name LIKE exc.Token

	RETURN

END




GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_GetFiles]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Get current files from file system
-- =============================================
ALTER PROCEDURE [dbo].[USP_GetFiles]
(	
	@path	NVARCHAR(4000),
	@filter NVARCHAR(4000) = '*.*',
	@deep	BIT = 0
)
AS
BEGIN
	
	SET NOCOUNT ON

	SET @path = LTRIM(RTRIM(@path))
	if ( right(@path, 1) <> '\' ) SET @path = @path + '\'

	SET @filter = ISNULL(@filter, '*.*')
	
	DECLARE @shell NVARCHAR(4000)
	CREATE TABLE #shell			( line NVARCHAR(4000) )

	CREATE TABLE #folder ([Path] NVARCHAR(4000), Parsed BIT DEFAULT 0 )
	INSERT INTO #folder ([Path]) VALUES (@path)

	IF(@deep=1)
	BEGIN
		
		DECLARE @subPath NVARCHAR(4000)

		WHILE EXISTS(SELECT * FROM #folder WHERE Parsed = 0)
		BEGIN
			
			SELECT TOP 1 @subPath = [Path] FROM #folder WHERE Parsed = 0			
			
			SET @subPath = LTRIM(RTRIM(@subPath))
			IF ( RIGHT(@subPath, 1) <> '\' ) SET @subPath = @subPath + '\'

			SET @shell = 'dir "' + @subPath + '"'
			--PRINT 'Shell: ' + @shell
									
			DELETE #shell
			INSERT INTO #shell EXEC master..xp_cmdshell @shell
			UPDATE #shell SET line = dbo.UDF_GetFolderNameFromShell(line)

			INSERT INTO #folder SELECT @subPath + line + '\', 0 FROM #shell WHERE line IS NOT NULL
			UPDATE #folder SET Parsed = 1 WHERE [Path] = @subPath

		END

	END

	UPDATE #folder SET Parsed = 0

	CREATE TABLE #file ([Path] NVARCHAR(4000))

	WHILE EXISTS(SELECT * FROM #folder WHERE Parsed = 0)
	BEGIN
		
		SELECT TOP 1 @subPath = [Path] FROM #folder WHERE Parsed = 0			

		SET @subPath = LTRIM(RTRIM(@subPath))
		IF ( RIGHT(@subPath, 1) <> '\' ) SET @subPath = @subPath + '\'

		SET @shell = 'dir "' + @subPath + @filter + '"'
		--PRINT 'Shell: ' + @shell
		
		DELETE #shell
		INSERT INTO #shell EXEC master..xp_cmdshell @shell
		UPDATE #shell SET line = dbo.UDF_GetFileNameFromShell(line)

		INSERT INTO #file SELECT SUBSTRING(@subPath, len(@path)+1, len(@subPath)) + line FROM #shell WHERE line IS NOT NULL
		UPDATE #folder SET Parsed = 1 WHERE [Path] = @subPath

	END

	IF (OBJECT_ID('SPID_GetFiles') IS NULL) 
	BEGIN
		SELECT @@SPID AS SPID, [Path] INTO SPID_GetFiles FROM #file
	END
	ELSE
	BEGIN
		DELETE SPID_GetFiles WHERE SPID = @@SPID
		INSERT INTO SPID_GetFiles SELECT @@SPID AS SPID, [Path] FROM #file
	END
	
	DROP TABLE #shell
	DROP TABLE #folder
	DROP TABLE #file	

END


GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_GetFolders]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Get current folders from file system
-- =============================================
ALTER PROCEDURE [dbo].[USP_GetFolders]
(	
	@path	NVARCHAR(4000),
	@deep	BIT = 0
)
AS
BEGIN

	SET NOCOUNT ON

	SET @path = LTRIM(RTRIM(@path))
	if ( right(@path, 1) <> '\' ) SET @path = @path + '\'
	
	DECLARE @shell NVARCHAR(4000)
	CREATE TABLE #shell			( line NVARCHAR(4000) )

	CREATE TABLE #folder ([Path] NVARCHAR(4000), Parsed BIT DEFAULT 0, FolderCount INT DEFAULT 0, FileCount INT DEFAULT 0 )
	INSERT INTO #folder ([Path]) VALUES (@path)

	DECLARE @subPath NVARCHAR(4000)

	WHILE EXISTS(SELECT * FROM #folder WHERE Parsed = 0)
	BEGIN
		
		SELECT TOP 1 @subPath = [Path] FROM #folder WHERE Parsed = 0			
		
		SET @subPath = LTRIM(RTRIM(@subPath))
		IF ( RIGHT(@subPath, 1) <> '\' ) SET @subPath = @subPath + '\'

		SET @shell = 'dir "' + @subPath + '"'
		--PRINT 'Shell: ' + @shell
								
		DELETE #shell
		INSERT INTO #shell EXEC master..xp_cmdshell @shell
		UPDATE #shell SET line = dbo.UDF_GetFolderNameFromShell(line)

		IF(@deep=1 OR @subPath = @path)
		BEGIN
			INSERT INTO #folder SELECT @subPath + line + '\', 0, 0, 0 FROM #shell WHERE line IS NOT NULL
			UPDATE #folder SET Parsed = 1, FolderCount = @@ROWCOUNT WHERE [Path] = @subPath
		END
		ELSE
		BEGIN
			DECLARE @folderCount INT
			SELECT @folderCount = COUNT(*) FROM #shell WHERE line IS NOT NULL
			UPDATE #folder SET Parsed = 1, FolderCount = @folderCount WHERE [Path] = @subPath
		END

	END

	UPDATE #folder SET Parsed = 0

	WHILE EXISTS(SELECT * FROM #folder WHERE Parsed = 0)
	BEGIN

		SELECT TOP 1 @subPath = [Path] FROM #folder WHERE Parsed = 0			
		
		SET @subPath = LTRIM(RTRIM(@subPath))
		IF ( RIGHT(@subPath, 1) <> '\' ) SET @subPath = @subPath + '\'

		SET @shell = 'dir "' + @subPath + '*.*"'
		--PRINT 'Shell: ' + @shell
								
		DELETE #shell
		INSERT INTO #shell EXEC master..xp_cmdshell @shell
		UPDATE #shell SET line = dbo.UDF_GetFileNameFromShell(line)
		
		DECLARE @fileCount INT
		SELECT @fileCount = COUNT(*) FROM #shell WHERE line IS NOT NULL
		UPDATE #folder SET Parsed = 1, FileCount = @fileCount WHERE [Path] = @subPath	

	END

	DELETE #folder WHERE [Path] = @path
	UPDATE #folder SET [Path] = SUBSTRING([Path], Len(@path) + 1, LEN([Path]))
 
	IF (OBJECT_ID('SPID_GetFolders') IS NULL) 
	BEGIN
		SELECT @@SPID AS SPID,[Path], FolderCount, FileCount INTO SPID_GetFolders FROM #folder
	END
	ELSE
	BEGIN
		DELETE SPID_GetFolders WHERE SPID = @@SPID
		INSERT INTO SPID_GetFolders SELECT @@SPID AS SPID, [Path], FolderCount, FileCount FROM #folder
	END
	
	DROP TABLE #shell
	DROP TABLE #folder

END



GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_CleanUpHistory_SYNC]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Cleanup history files in file system
-- =============================================
ALTER PROCEDURE [dbo].[USP_CleanUpHistory_SYNC]
AS
BEGIN

	DECLARE @shell			NVARCHAR(4000)
	DECLARE @shellResult	INT
	
	DECLARE @exist	BIT
	DECLARE @bak	NVARCHAR(4000)
	
	DECLARE @bakFolder NVARCHAR(4000)
	SET @bakFolder = dbo.UDF_GetBackupFolder(NULL, NULL)

	DECLARE @hisFolder NVARCHAR(4000)
	SET @hisFolder = dbo.UDF_GetHistoryFolder(NULL, NULL)

	PRINT CHAR(13) + '>>> FIND AND REMOVE ORPHAN BACKUP FILES IN: ' + @bakFolder + CHAR(13)

	EXEC USP_GetFiles @bakFolder, '*.bak', 1

	DECLARE orphanBak_cur CURSOR LOCAL FORWARD_ONLY FOR
		SELECT [Path] FROM SPID_GetFiles WHERE SPID = @@SPID
	
	OPEN orphanBak_cur

	FETCH NEXT FROM orphanBak_cur INTO @bak

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		IF NOT EXISTS(SELECT * FROM Backups WHERE BackupFile = @bakFolder + @bak)
		BEGIN

			SET @shell = 'DEL /F/Q "' + @bakFolder + @bak + '"'
				
			PRINT 'Shell: ' + @shell

			EXEC @shellResult = master..xp_cmdshell @shell, no_output

			IF (@shellResult <> 0) PRINT CHAR(13) +'FAILED TO RUN: ' + @shell

		END

		FETCH NEXT FROM orphanBak_cur INTO @bak

	END

	CLOSE orphanBak_cur

	PRINT CHAR(13) + '>>> FIND AND REMOVE ORPHAN FOLDERS IN: ' + @bakFolder + CHAR(13)

	EXEC USP_GetFolders @bakFolder, 1

	DECLARE orphanDir_cur CURSOR LOCAL FORWARD_ONLY FOR
		SELECT [Path] FROM SPID_GetFolders WHERE SPID = @@SPID AND FolderCount = 0 AND FileCount = 0
	
	OPEN orphanDir_cur

	FETCH NEXT FROM orphanDir_cur INTO @bak

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		SET @shell = 'RD "' + @bakFolder + @bak + '"'
			
		PRINT 'Shell: ' + @shell

		EXEC @shellResult = master..xp_cmdshell @shell, no_output

		IF (@shellResult <> 0) PRINT CHAR(13) +'FAILED TO RUN: ' + @shell

		FETCH NEXT FROM orphanDir_cur INTO @bak

	END

	CLOSE orphanDir_cur

	PRINT CHAR(13) + '>>> FIND AND REMOVE ORPHAN BACKUP FILES IN: ' + @hisFolder + CHAR(13)

	EXEC USP_GetFiles @hisFolder, '*.bak', 1

	OPEN orphanBak_cur

	FETCH NEXT FROM orphanBak_cur INTO @bak

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		IF NOT EXISTS(SELECT * FROM Backups WHERE ISNULL(HistoryFile, dbo.UDF_GetHistoryFolder(DatabaseName,DatabaseID) + dbo.UDF_GetFileName(@bak))  = @hisFolder + @bak)
		BEGIN

			SET @shell = 'DEL /F/Q "' + @hisFolder + @bak + '"'
				
			PRINT 'Shell: ' + @shell

			EXEC @shellResult = master..xp_cmdshell @shell, no_output

			IF (@shellResult <> 0) PRINT CHAR(13) +'FAILED TO RUN: ' + @shell

		END

		FETCH NEXT FROM orphanBak_cur INTO @bak

	END

	CLOSE orphanBak_cur
	DEALLOCATE orphanBak_cur

	PRINT CHAR(13) + '>>> FIND AND REMOVE ORPHAN FOLDERS IN: ' + @hisFolder + CHAR(13)

	EXEC USP_GetFolders @hisFolder, 1

	OPEN orphanDir_cur

	FETCH NEXT FROM orphanDir_cur INTO @bak

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		SET @shell = 'RD "' + @hisFolder + @bak + '"'
			
		PRINT 'Shell: ' + @shell

		EXEC @shellResult = master..xp_cmdshell @shell, no_output

		IF (@shellResult <> 0) PRINT CHAR(13) +'FAILED TO RUN: ' + @shell

		FETCH NEXT FROM orphanDir_cur INTO @bak

	END

	CLOSE orphanDir_cur
	DEALLOCATE orphanDir_cur

	PRINT CHAR(13) + '>>> FIND AND REMOVE GARBAGE ENTRIES IN BACKUPS TABLE (NO RELATED DB)' + CHAR(13)

	DECLARE trash_cur CURSOR LOCAL FORWARD_ONLY FOR
		SELECT DISTINCT DatabaseName, DatabaseID, ISNULL(HistoryFile, BackupFile) FROM Backups

	OPEN trash_cur

	DECLARE @dbName NVARCHAR(250)
	DECLARE @dbID	INT

	FETCH NEXT FROM trash_cur INTO @dbName, @dbID, @bak

	WHILE ( @@FETCH_STATUS = 0 )
	BEGIN

		IF NOT EXISTS( SELECT *  FROM master.sys.databases WHERE NAME = @dbName AND db_id(NAME) = @dbID )
		BEGIN

			SET @shell = 'DEL /F/Q "' + @bak + '"'
				
			PRINT 'Shell: ' + @shell

			EXEC @shellResult = master..xp_cmdshell @shell, no_output

			IF (@shellResult <> 0) PRINT CHAR(13) +'FAILED TO RUN: ' + @shell

		END
		
		FETCH NEXT FROM trash_cur INTO @dbName, @dbID, @bak

	END
	
	CLOSE trash_cur
	DEALLOCATE trash_cur

	PRINT CHAR(13) + '>>> FIND AND REMOVE GARBAGE ENTRIES IN BACKUPS TABLE (BACKUP FILE DOES NOT EXIST)' + CHAR(13)

	DECLARE baks_cur CURSOR LOCAL FORWARD_ONLY FOR
		SELECT DISTINCT ISNULL(HistoryFile, BackupFile) FROM Backups

	OPEN baks_cur

	FETCH NEXT FROM baks_cur INTO @bak

	WHILE ( @@FETCH_STATUS = 0 )
	BEGIN

		EXEC USP_ExistFile @bak, @exist OUT

		IF (@exist=0) DELETE FROM Backups WHERE BackupFile = @bak OR HistoryFile = @bak

		FETCH NEXT FROM baks_cur INTO @bak

	END

	CLOSE baks_cur
	DEALLOCATE baks_cur

END




GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_BackupDatabase_FULL]'
GO
ALTER PROCEDURE [dbo].[USP_BackupDatabase_FULL]
	@includeDbName	NVARCHAR(256) = NULL,
	@excludeDbName	NVARCHAR(256) = NULL
AS
BEGIN

	SET NOCOUNT ON;

	EXEC USP_CleanUpHistory_SYNC

	DECLARE	@now			DATETIME
	SET @now = GETDATE()

	DECLARE @timeStamp		NVARCHAR(15)
	SET @timeStamp = dbo.UDF_GetTimeStamp(@now)
	
	DECLARE database_cur CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT [Name] FROM dbo.UDF_GetAffectedDatabases( @includeDbName, @excludeDbName )

	OPEN database_cur

	DECLARE @database	NVARCHAR(100)

	FETCH NEXT FROM database_cur INTO @database

	WHILE( @@FETCH_STATUS=0 )
	BEGIN

		PRINT CHAR(13) + CHAR(13) + '>>> FULL BACKUP DB: ' + UPPER(@database) + ' (' + CONVERT(nvarchar, GETDATE(), 127) + ')' + CHAR(13) + CHAR(13)

		DECLARE @dir			NVARCHAR(256)
		SET @dir = dbo.UDF_GetBackupFolder(@database, NULL)

		DECLARE @bak			NVARCHAR(4000)
		SELECT @bak = @dir + UPPER(@database) + ' ' + @timeStamp + '.bak'

		EXEC USP_CreateFolder @dir

		DECLARE @set			NVARCHAR(500)
		SELECT @set = UPPER(@database) + ' ' + @timeStamp

		BACKUP DATABASE @database TO DISK = @bak WITH  NOINIT ,  NOUNLOAD ,  NAME = @set,  NOSKIP ,  STATS = 10,  NOFORMAT
		IF (@@ERROR=0)
		BEGIN

			INSERT INTO Backups 
			( DatabaseName, DatabaseID, [TimeStamp], [BackupType], [BackupFile] ) 
			VALUES 
			( @database, db_id(@database), @now, 'FULL', @bak )
			
			DECLARE @logfilename SYSNAME, @shrinkcommand NVARCHAR(1000)
			SELECT @logfilename = [name] FROM sys.master_files WHERE DB_NAME(database_id) = @database AND TYPE = 1
			
			PRINT 'Database Logfile (assuming only 1 file exists): ' + @logfilename 
			SET @shrinkcommand = 'USE [' + @database + ']; DBCC SHRINKFILE (' + @logfilename + ', ' + CONVERT(VARCHAR, 100) + ')'
			PRINT @shrinkcommand 
			BEGIN TRY
				EXEC (@shrinkcommand)
			END TRY
			BEGIN CATCH
				PRINT 'Error executing log shrink: "' + @shrinkcommand + '"; ' + ERROR_MESSAGE()
			END CATCH

		END

		FETCH NEXT FROM database_cur INTO @database
	
	END

	CLOSE database_cur
	DEALLOCATE database_cur

END












GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_BackupDatabase_DIFF]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Performs a differential backup
-- =============================================
ALTER PROCEDURE [dbo].[USP_BackupDatabase_DIFF] 
	@includeDbName	NVARCHAR(256) = NULL,
	@excludeDbName	NVARCHAR(256) = NULL
AS
BEGIN

	SET NOCOUNT ON;

	EXEC USP_CleanUpHistory_SYNC

	DECLARE	@now			DATETIME
	SET @now = GETDATE()

	DECLARE @timeStamp		NVARCHAR(15)
	SET @timeStamp = dbo.UDF_GetTimeStamp(@now)
	
	DECLARE database_cur CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT [Name] 
		FROM dbo.UDF_GetAffectedDatabases( @includeDbName, @excludeDbName )
		WHERE [Name] <> 'master'

	OPEN database_cur

	DECLARE @database	NVARCHAR(100)

	FETCH NEXT FROM database_cur INTO @database

	WHILE( @@FETCH_STATUS=0 )
	BEGIN

		IF NOT EXISTS( SELECT 1 FROM Backups WHERE DatabaseName = @database AND DatabaseID = db_id(@database) AND BackupType = 'FULL' )
		BEGIN

			EXEC USP_BackupDatabase_FULL @database

		END
		ELSE
		BEGIN

			PRINT CHAR(13) + CHAR(13) + '>>> DIFF BACKUP DB: ' + UPPER(@database) + ' (' + CONVERT(nvarchar, GETDATE(), 127) + ')' + CHAR(13) + CHAR(13)

			DECLARE @bak			NVARCHAR(256)
			SET @bak = dbo.UDF_GetBackupFile( @database, NULL )

			BACKUP DATABASE @database TO DISK = @bak WITH  NOINIT ,  NOUNLOAD ,  DIFFERENTIAL ,  NAME = @database,  NOSKIP ,  STATS = 10,  NOFORMAT 
			IF (@@ERROR=0)
			BEGIN

				INSERT INTO Backups 
				( DatabaseName, DatabaseID, [TimeStamp], [BackupType], [BackupFile] ) 
				VALUES 
				( @database, db_id(@database), @now, 'DIFF', @bak )

			END

		END

		FETCH NEXT FROM database_cur INTO @database
	
	END

	CLOSE database_cur
	DEALLOCATE database_cur

END








GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_BackupDatabase_TRAN]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Performs a transaction log backup
-- =============================================
ALTER PROCEDURE [dbo].[USP_BackupDatabase_TRAN] 
	@includeDbName	NVARCHAR(256) = NULL,
	@excludeDbName	NVARCHAR(256) = NULL
AS
BEGIN

	SET NOCOUNT ON;

	EXEC USP_CleanUpHistory_SYNC

	DECLARE	@now			DATETIME
	SET @now = GETDATE()

	DECLARE @timeStamp		NVARCHAR(15)
	SET @timeStamp = dbo.UDF_GetTimeStamp(@now)
	
	DECLARE database_cur CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT [Name] 
		FROM dbo.UDF_GetAffectedDatabases( @includeDbName, @excludeDbName )
		WHERE [Name] <> 'master'

	OPEN database_cur

	DECLARE @database	NVARCHAR(100)

	FETCH NEXT FROM database_cur INTO @database

	WHILE( @@FETCH_STATUS=0 )
	BEGIN

		IF NOT EXISTS( SELECT 1 FROM Backups WHERE DatabaseName = @database AND DatabaseID = db_id(@database) AND BackupType = 'FULL' )
		BEGIN

			EXEC USP_BackupDatabase_FULL @database

		END
		ELSE IF NOT EXISTS( SELECT 1 FROM master.sys.databases WHERE [Name] = @database AND database_ID = db_id(@database) AND recovery_model_desc = 'FULL' )
		BEGIN

			PRINT CHAR(13) + CHAR(13) + '>>> SKIP TRAN BACKUP BECAUSE OF A SIMPLE RECOVERY MODEL FOR DB: ' + UPPER(@database) + CHAR(13) + CHAR(13)

		END
		ELSE
		BEGIN

			PRINT CHAR(13) + CHAR(13) + '>>> TRAN BACKUP DB: ' + UPPER(@database) + ' (' + CONVERT(nvarchar, GETDATE(), 127) + ')' + CHAR(13) + CHAR(13)

			DECLARE @bak			NVARCHAR(256)
			SET @bak = dbo.UDF_GetBackupFile( @database, NULL )

			DECLARE @bakErr			INT 

			BACKUP LOG @database TO DISK = @bak WITH  NOINIT,  NOUNLOAD , NAME = @database,  NOSKIP ,  STATS = 10,  NOFORMAT
			SET @bakErr = @@ERROR

			IF (@bakErr=0)
			BEGIN

				INSERT INTO Backups 
				( DatabaseName, DatabaseID, [TimeStamp], [BackupType], [BackupFile] ) 
				VALUES 
				( @database, db_id(@database), @now, 'TRAN', @bak )

			END
			ELSE IF (@bakErr = 3013) -- BACKUP LOG cannot be performed because there is no current database backup.
			BEGIN

				EXEC USP_BackupDatabase_FULL @database

			END

		END

		FETCH NEXT FROM database_cur INTO @database
	
	END

	CLOSE database_cur
	DEALLOCATE database_cur

END











GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_BackupDatabase]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Base Stored Procedure for starting a backup
-- =============================================
ALTER PROCEDURE [dbo].[USP_BackupDatabase]
	@backupType		NVARCHAR(4) = 'FULL', -- Default Backup Type FULL
	@includeDbName	NVARCHAR(256) = NULL, -- Default include any database
	@excludeDbName	NVARCHAR(256) = NULL  -- Default exclude no database
AS
BEGIN

	SET NOCOUNT ON;

	IF (@backupType IS NULL)	SET @backupType = 'FULL'

	IF		(UPPER(@backupType) = 'FULL')	EXEC USP_BackupDatabase_FULL @includeDbName, @excludeDbName
	ELSE IF (UPPER(@backupType) = 'DIFF')	EXEC USP_BackupDatabase_DIFF @includeDbName, @excludeDbName
	ELSE IF (UPPER(@backupType) = 'TRAN')	EXEC USP_BackupDatabase_TRAN @includeDbName, @excludeDbName
	ELSE
	BEGIN

		DECLARE @errMsg		NVARCHAR(4000)
		SET @errMsg = 'Unknown backup type "' + UPPER(@backupType) + '"'

		RAISERROR (@errMsg, 10, 1) WITH NOWAIT

	END

END





GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_CleanUpHistory]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	Clean up backup history
-- =============================================
ALTER PROCEDURE [dbo].[USP_CleanUpHistory]
	@maxGeneration	INT = 0,
	@maxAgeAsDays	INT = 0,
	@includeDbName	NVARCHAR(256) = NULL,
	@excludeDbName	NVARCHAR(256) = NULL
AS
BEGIN
	
	SET NOCOUNT ON

	EXEC USP_CleanUpHistory_SYNC

	IF (@maxGeneration IS NULL OR @maxGeneration < 0)		SET @maxGeneration = 0
	IF (@maxAgeAsDays IS NULL OR @maxAgeAsDays < 0)			SET @maxAgeAsDays = 0

	DECLARE @today	DATETIME
	SET @today = CAST(CONVERT(NVARCHAR, GETDATE(), 112) AS DATETIME)

	DECLARE @exist			BIT

	DECLARE @shell			NVARCHAR(4000)
	DECLARE @shellResult	INT

	IF EXISTS( SELECT 1 FROM Settings WHERE [Key] = 'HistoryRootFolder' AND [Value] IS NOT NULL )
	BEGIN

		;WITH HistoryRank AS
		(
			SELECT RANK() OVER (PARTITION BY baks.DatabaseName, baks.DatabaseID ORDER BY baks.[TimeStamp] DESC) AS Generation, 
			baks.*
			FROM Backups baks
				INNER JOIN dbo.UDF_GetAffectedBackups(@includeDbName, @excludeDbName) aff
						ON baks.BackupID = aff.BackupID
			WHERE baks.HistoryFile IS NULL
		)
		
		SELECT * INTO #history FROM HistoryRank

		DECLARE history_cur CURSOR LOCAL FORWARD_ONLY FOR
			SELECT Generation, DatabaseName, DatabaseID, BackupFile, HistoryFile FROM #history

		OPEN history_cur

		DECLARE @generation		INT
		DECLARE @databaseName	NVARCHAR(250)
		DECLARE @databaseID		INT
		DECLARE @backupFile		NVARCHAR(500)
		DECLARE @historyFile	NVARCHAR(500)

		FETCH NEXT FROM history_cur INTO @generation, @databaseName, @databaseID, @backupFile, @historyFile

		WHILE (@@FETCH_STATUS=0)
		BEGIN

			IF EXISTS( SELECT 1 FROM Backups WHERE BackupFile = @backupFile AND HistoryFile IS NULL )
			BEGIN
				
				DECLARE @historyDir		NVARCHAR(4000)
				SET @historyDir = dbo.UDF_GetHistoryFolder(@databaseName, @databaseID)

				EXEC USP_ExistFolder @historyDir, @exist OUT
				IF (@exist=0) EXEC USP_CreateFolder @historyDir				

				SET @historyFile = @historyDir + dbo.UDF_GetFileName(@backupFile)

				IF (@generation=1)	SET @shell = 'COPY /Y/B '
				ELSE				SET @shell = 'MOVE /Y '

				SET @shell = @shell + '"' + @backupFile + 
								'" "' + @historyFile + 
								'"'
				PRINT 'Shell: ' + @shell

				EXEC @shellResult = master..xp_cmdshell @shell, no_output
				
				IF (@shellResult=0 AND @generation>1) UPDATE Backups SET HistoryFile = @historyFile WHERE BackupFile = @backupFile

				IF (@shellResult<>0 AND @generation>1)
				BEGIN
	
					PRINT 'FAILED TO RUN: ' + @shell
				
					-- fallback to copy and delete

					SET @shell = 'COPY /Y/B ' +
									'"' + @backupFile + 
									'" "' + @historyFile + 
									'"'

					PRINT '(Fallback) Shell: ' + @shell

					EXEC @shellResult = master..xp_cmdshell @shell, no_output

					IF (@shellResult = 0)
					BEGIN

						SET @shell = 'DEL /F/Q "' + @backupFile + '"'

						PRINT '(Fallback) Shell: ' + @shell

						EXEC @shellResult = master..xp_cmdshell @shell, no_output

						IF (@shellResult=0) UPDATE Backups SET HistoryFile = @historyFile WHERE BackupFile = @backupFile
						ELSE PRINT '(Fallback) FAILED TO RUN: ' + @shell

					END
					ELSE PRINT '(Fallback) FAILED TO RUN: ' + @shell

				END

			END

			FETCH NEXT FROM history_cur INTO @generation, @databaseName, @databaseID, @backupFile, @historyFile
	
		END

		CLOSE history_cur
		DEALLOCATE history_cur

	END

	IF (@maxGeneration + @maxAgeAsDays > 0)
	BEGIN

		IF (@maxGeneration = 0)		SELECT @maxGeneration = COUNT(BackupID) FROM Backups WHERE BackupType = 'FULL'
		IF (@maxAgeAsDays = 0)		SELECT @maxAgeAsDays = DATEDIFF(dd, MIN([TimeStamp]), GETDATE()) FROM Backups

		;WITH Garbage AS
		(
			SELECT RANK() OVER (PARTITION BY baks.DatabaseName, baks.DatabaseID ORDER BY baks.[TimeStamp] DESC) AS Generation, 
			baks.* 
			FROM Backups baks
				INNER JOIN dbo.UDF_GetAffectedBackups(@includeDbName, @excludeDbName) aff
						ON baks.BackupID = aff.BackupID
			WHERE BackupType = 'FULL'
		)
		
		SELECT * INTO #garbage FROM Garbage

		DECLARE trash_cur CURSOR LOCAL FORWARD_ONLY FOR
			SELECT DISTINCT ISNULL(HistoryFile, BackupFile) 
			FROM #garbage 
			WHERE ( Generation > @maxGeneration OR [TimeStamp] < DATEADD(dd, (@maxAgeAsDays * -1), @today) )

		OPEN trash_cur

		DECLARE @bak NVARCHAR(4000)

		FETCH NEXT FROM trash_cur INTO @bak

		WHILE ( @@FETCH_STATUS = 0 )
		BEGIN

			SET @shell = 'DEL /F/Q "' + @bak + '"'
				
			PRINT 'Shell: ' + @shell

			EXEC @shellResult = master..xp_cmdshell @shell, no_output

			IF (@shellResult <> 0) PRINT 'FAILED TO RUN: ' + @shell

			FETCH NEXT FROM trash_cur INTO @bak

		END

		CLOSE trash_cur
		DEALLOCATE trash_cur

		EXEC USP_CleanUpHistory_SYNC
 
	END
END



GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[USP_ExecDBCC]'
GO
-- =============================================
-- Author:		Thomas Stensitzki
-- Create date: 2008-10-20
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[USP_ExecDBCC]

	@database	NVARCHAR(500),
	@cmd		NVARCHAR(4000)

AS
BEGIN

	CREATE TABLE #output ( Line NVARCHAR(4000) )

	DECLARE @shell	NVARCHAR(4000)
	
	SET @shell = 'sqlcmd -E -S ' + @@SERVERNAME + ' '
	IF (@database IS NOT NULL) SET @shell = @shell + '-d ' + @database + ' '
	IF (@cmd IS NOT NULL) SET @shell = @shell + '-q "' + @cmd + '" '
	SET @shell = LTRIM(RTRIM(@shell))

	print 'SHELL: ' + @shell
	
	INSERT INTO #output EXEC master.sys.xp_cmdshell @shell

	DECLARE @errMsg	NVARCHAR(500)
	SELECT @errMsg = LTRIM(RTRIM(Line)) FROM #output WHERE Line LIKE 'Login failed for user%'

	IF (@errMsg IS NOT NULL) RAISERROR (@errMsg, 10, 1) WITH NOWAIT

	SELECT * FROM #output	

END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
IF EXISTS (SELECT * FROM #tmpErrors) ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT>0 BEGIN
PRINT 'The database update succeeded'
COMMIT TRANSACTION
END
ELSE PRINT 'The database update failed'
GO
DROP TABLE #tmpErrors
GO
