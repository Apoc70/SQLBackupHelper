# SQLBackupHelper

The SQL Backup Helper is a set of Stored Procedures and User Defined Functions, which help you automate the process of creating backup sets, cloning database and creating a history set of database backups when using a SQL Server or SQL Server Express edition.

## Features

* Create full backups of selected databases, using wildcards of inclusion and exclusion
* Create differential backups of selected databases, using wildcards of inclusion and exclusion
* Create transaction log backups of selected databases, using wildcards of inclusion and exclusion
* Clone databases
* Copy backup sets to local or UNC folders to create a backup history

## How to use SQL Backup Helper

* Example FULL backup command performing a full backup of all databases, excluding master,model,msdb,tempdb databases 

``` SQL
EXEC USP_BackupDatabase 'FULL', NULL, 'master,model,msdb,tempdb'
```

Example FULL backup command performing a FULL backup of all databases starting with DEV, excluding master,model,msdb,tempdb databases

``` SQL
EXEC USP_BackupDatabase 'FULL', 'DEV%', 'master,model,msdb,tempdb'
```

Example for cleaning up history, keeping 3 backup sets, having no maximum age, including all databases, excluding master,model,msdb,tempdb databases

``` SQL
EXEC USP_CleanUpHistory 3, NULL, NULL, 'master,model,msdb,tempdb'
```

Example DIFF backup command performing a differential backup of all databases, excluding master,model,msdb,tempdb databases 

``` SQL
EXEC USP_BackupDatabase 'DIFF', NULL, 'master,model,msdb,tempdb'
```

Example TRAN backup command performing a tranaction log backup of all databases, excluding master,model,msdb,tempdb databases 

``` SQL
EXEC USP_BackupDatabase 'TRAN', NULL, 'master,model,msdb,tempdb'
```

## How To use SQL Backup Helper with SQL Server Express Editions

Use the downloadable installer to create the database in your SQL Server Express instance. Configure the folder parameters in the settings table.

Create a new BACKUP-FULL.sql file in a folder oy your choice (e.g. D:\Scripts) and add the following T-SQL code:

``` SQL
USE SQLBackupHelper
GO
EXEC USP_BackupDatabase 'FULL', NULL, 'master,model,msdb,tempdb'
GO
EXEC USP_CleanUpHistory 2, NULL, NULL, 'master,model,msdb,tempdb'
GO
```

Create a batch file which can be called by the system scheduler and add the following code:

``` CMD
osql -E -S SERVERNAME\INSTANCENAME -i D:\Scripts\BACKUP-FULL.sql -o D:\Scripts\BACKUP_FULL.rpt
```

Use the example commands to set up the .sql files for transaction log and differential backups.

## Installation

The SQL Backup Helper can be installed by using the setup binary (Red Gates SQL packager). The binary lets you choose the following:

* Database name
* Database folder
* Log folder
* Collation
* Recovery model
* Compatibility level
* Initial database size

The SQL Backup Helper can be installed by setting up the database manually and by running the Schema and MasterData scripts.

## Requirements

SQL Server
The SQL Backup Helper runs successfully on the following SQL Server Version:

* SQL Server 2005 (all versions)
* SQL Server 2008 (all versions)
* SQL Server 2008 R2 (all versions)
* SQL Server 2012 (all versions)
* SQL Server 2014 (all versions)
* SQL Server 2016 (all versions)

xp_cmdshell
The extended SP xp_cmdshell must be enabled, as the SPs need access to the file system.

Access Rights
The SQL Server Agent service account (when using SQL Server full edition) needs modify rights (at least) on the configured folders.

## Note

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE
RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

## Credits

Written by: Thomas Stensitzki

## Stay connected

- My Blog: [http://justcantgetenough.granikos.eu](http://justcantgetenough.granikos.eu)
- Twitter: [https://twitter.com/stensitzki](https://twitter.com/stensitzki)
- LinkedIn: [http://de.linkedin.com/in/thomasstensitzki](http://de.linkedin.com/in/thomasstensitzki)
- Github: [https://github.com/Apoc70](https://github.com/Apoc70)
- MVP Blog: [https://blogs.msmvps.com/thomastechtalk/](https://blogs.msmvps.com/thomastechtalk/)
- Tech Talk YouTube Channel (DE): [http://techtalk.granikos.eu](http://techtalk.granikos.eu)

For more Office 365, Cloud Security, and Exchange Server stuff checkout services provided by Granikos

- Blog: [http://blog.granikos.eu](http://blog.granikos.eu)
- Website: [https://www.granikos.eu/en/](https://www.granikos.eu/en/)
- Twitter: [https://twitter.com/granikos_de](https://twitter.com/granikos_de)

## Additional Credits

- Markus Heiliger (Initial Version of SQL Helper functions)