/*
Run this script to update the data of SQL Backup Helper from v0.9 to v1.0
*/
		
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
SET DATEFORMAT YMD
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
-- Pointer used for text / image updates. This might not be needed, but is declared here just in case
DECLARE @pv binary(16)

-- Update 3 rows in [dbo].[Settings]
UPDATE [dbo].[Settings] SET [Description]=N'Root Folder for all database backups. For each database a new folder will be created.' WHERE [Key]=N'BackupRootFolder'
UPDATE [dbo].[Settings] SET [Description]=N'Root Folder for database clones. For each database a new folder will be created.' WHERE [Key]=N'CloneTempFolder'
UPDATE [dbo].[Settings] SET [Description]=N'Root Folder for all old database backups. For each database a new folder will be created.' WHERE [Key]=N'HistoryRootFolder'
COMMIT TRANSACTION
GO