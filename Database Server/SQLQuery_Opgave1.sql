USE master;
GO
-- Check for database existence and drop if it exists
IF DB_ID('SkoleDB') IS NOT NULL
BEGIN
    -- Disconnect all users from the database to be dropped
    DECLARE @KillCommand NVARCHAR(1000);
    DECLARE kill_cursor CURSOR FOR 
    SELECT 'KILL ' + CONVERT(VARCHAR(10), session_id)
    FROM sys.dm_exec_sessions
    WHERE database_id  = DB_ID('SkoleDB');

    OPEN kill_cursor;

    FETCH NEXT FROM kill_cursor INTO @KillCommand;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @KillCommand;
        FETCH NEXT FROM kill_cursor INTO @KillCommand;
    END

    CLOSE kill_cursor;
    DEALLOCATE kill_cursor;

    ALTER DATABASE [SkoleDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [SkoleDB];
    PRINT 'Databasen SkoleDB er blevet slettet.';
END
ELSE
BEGIN
    PRINT 'Databasen SkoleDB eksisterer ikke - intet behov for handling.';
END
GO

-- Create the SkoleDB database
CREATE DATABASE SkoleDB;
GO

-- Add filegroups
ALTER DATABASE SkoleDB ADD FILEGROUP ElevGroup;
ALTER DATABASE SkoleDB ADD FILEGROUP LaererGroup;
ALTER DATABASE SkoleDB ADD FILEGROUP KlasseGroup;
ALTER DATABASE SkoleDB ADD FILEGROUP PostNrByGroup;
ALTER DATABASE SkoleDB ADD FILEGROUP LaererKlasseGroup;
GO

-- Modify the path as per your environment
ALTER DATABASE SkoleDB ADD FILE (
    NAME = 'ElevData',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.PATRICKDB\MSSQL\DATA\Elev.ndf',
    SIZE = 10MB,
    FILEGROWTH = 5MB
) TO FILEGROUP ElevGroup;

ALTER DATABASE SkoleDB ADD FILE (
    NAME = 'LaererData',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.PATRICKDB\MSSQL\DATA\Laerer.ndf',
    SIZE = 10MB,
    FILEGROWTH = 5MB
) TO FILEGROUP LaererGroup;

ALTER DATABASE SkoleDB ADD FILE (
    NAME = 'KlasseData',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.PATRICKDB\MSSQL\DATA\Klasse.ndf',
    SIZE = 10MB,
    FILEGROWTH = 5MB
) TO FILEGROUP KlasseGroup;

ALTER DATABASE SkoleDB ADD FILE (
    NAME = 'PostNrByData',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.PATRICKDB\MSSQL\DATA\PostNr.ndf',
    SIZE = 10MB,
    FILEGROWTH = 5MB
) TO FILEGROUP PostNrByGroup;

ALTER DATABASE SkoleDB ADD FILE (
    NAME = 'LaererKlasseData',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.PATRICKDB\MSSQL\DATA\LaererKlasse.ndf',
    SIZE = 10MB,
    FILEGROWTH = 5MB
) TO FILEGROUP LaererKlasseGroup;

ALTER DATABASE SkoleDB SET RECOVERY FULL;
GO

USE SkoleDB;
GO

-- Create the independent tables first
CREATE TABLE PostNrBy (
    postNr SMALLINT PRIMARY KEY,
    bynavn VARCHAR(30) NOT NULL
) ON PostNrByGroup;
GO

CREATE TABLE Klasse (
    klasseId INT PRIMARY KEY,
    klassenavn VARCHAR(10) NOT NULL
) ON KlasseGroup;
GO

-- Now create tables that have FK dependencies on the above tables
CREATE TABLE Elev (
    elevId INT PRIMARY KEY,
    fornavn VARCHAR(30) NOT NULL,
    efternavn VARCHAR(30) NOT NULL,
    adresse VARCHAR(50) NOT NULL,
    postNr SMALLINT NOT NULL,
    klasseId INT NOT NULL, -- Make sure the data type matches with the Klasse table
    CONSTRAINT [FK_Elev_postNr] FOREIGN KEY (postNr) REFERENCES PostNrBy(postNr),
    CONSTRAINT [FK_Elev_klasseId] FOREIGN KEY (klasseId) REFERENCES Klasse(klasseId)
) ON ElevGroup;
GO

CREATE TABLE Laerer (
    laererId INT PRIMARY KEY,
    fornavn VARCHAR(30) NOT NULL,
    efternavn VARCHAR(30) NOT NULL,
    adresse VARCHAR(50) NOT NULL,
    postNr SMALLINT NOT NULL,
    FOREIGN KEY (postNr) REFERENCES PostNrBy(postNr)
) ON LaererGroup;
GO

-- And lastly create the associative table that has FK dependencies on multiple tables
CREATE TABLE LaererKlasse (
    lkId INT IDENTITY(1,1) PRIMARY KEY,
    laererId INT NOT NULL,
    klasseId INT NOT NULL,
    FOREIGN KEY (laererId) REFERENCES Laerer(laererId),
    FOREIGN KEY (klasseId) REFERENCES Klasse(klasseId)
) ON LaererKlasseGroup;
GO

-- Insert test data
INSERT INTO PostNrBy (postNr, bynavn) VALUES (1000, 'København');
INSERT INTO Klasse (klasseId, klassenavn) VALUES (1, '10A');

-- Now you can safely insert data into the Elev table because the referenced values exist
INSERT INTO Elev (elevId, fornavn, efternavn, adresse, postNr, klasseId) 
VALUES (1, 'John', 'Doe', '123 Main St', 1000, 1);

-- Take a full backup
-- Ensure the backup directory exists
EXEC xp_create_subdir 'C:\SQLBackups';

BACKUP DATABASE SkoleDB TO DISK = 'C:\SQLBackups\SkoleDB_FullBackup.bak'
WITH FORMAT, MEDIANAME = 'SkoleDBBackup', NAME = 'Full Backup of SkoleDB';
GO
