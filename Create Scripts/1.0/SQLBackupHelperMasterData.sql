 SET NUMERIC_ROUNDABORT OFF
GO
SET XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
-- Pointer used for text / image updates. This might not be needed, but is declared here just in case
DECLARE @pv binary(16)

BEGIN TRANSACTION
INSERT INTO [dbo].[Settings] ([Key], [Value], [Description]) VALUES (N'BackupRootFolder', N'D:\Microsoft SQL Server\MSSQL\BACKUP', N'Root Folder for all database backups. For each database a new folder will be created.')
INSERT INTO [dbo].[Settings] ([Key], [Value], [Description]) VALUES (N'CloneTempFolder', N'D:\Microsoft SQL Server\MSSQL\BACKUP\TEMP', N'Root Folder for database clones. For each database a new folder will be created.')
INSERT INTO [dbo].[Settings] ([Key], [Value], [Description]) VALUES (N'HistoryRootFolder', N'\\SERVER\Backup', N'Root Folder for all old database backups. For each database a new folder will be created.')

COMMIT TRANSACTION