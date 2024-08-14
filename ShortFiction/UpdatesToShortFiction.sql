--Add a primary key to the Inventory table
IF NOT EXISTS (SELECT * FROM sys.key_constraints WHERE [name] = 'pk_Inventory_PublicationID_WarehouseLocation')
BEGIN
    ALTER TABLE dbo.Inventory ADD CONSTRAINT pk_Inventory_PublicationID_WarehouseLocation PRIMARY KEY CLUSTERED (PublicationID, WarehouseLocation);
END;
GO

--Add identity surrogate key to the inventory table
IF EXISTS (SELECT * FROM sys.key_constraints WHERE [name] = 'pk_Inventory_PublicationID_WarehouseLocation')
BEGIN
    ALTER TABLE dbo.Inventory DROP CONSTRAINT pk_Inventory_PublicationID_WarehouseLocation
END;

IF NOT EXISTS (SELECT * from sys.columns WHERE object_id = OBJECT_ID('Inventory') AND [name] = 'InventoryID')
BEGIN
    ALTER TABLE dbo.Inventory ADD InventoryID INT IDENTITY(1,1) NOT NULL;
END;

IF NOT EXISTS (SELECT * FROM sys.key_constraints WHERE [name] = 'pk_Inventory_InventoryID')
BEGIN
    ALTER TABLE dbo.Inventory ADD CONSTRAINT pk_Inventory_InventoryID PRIMARY KEY CLUSTERED (InventoryID);
END;
GO

--Add a nonclustered index to cover PublicationID and Warehouse location
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Inventory') AND [name] = 'ncix_Inventory_PublicationID_WarehouseLocation_include_Quantity')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Inventory_PublicationID_WarehouseLocation_include_Quantity
        ON dbo.Inventory (PublicationID, WarehouseLocation) INCLUDE (Quantity);
END;
GO

--Remove the foreign key constraints before we are able to drop the primary key constraint
IF EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_Publication_PublicationID')
BEGIN
    ALTER TABLE dbo.OrderDetail DROP CONSTRAINT fk_Publication_PublicationID;
END;
IF EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_Inventory_Publication_PublicationID')
BEGIN
    ALTER TABLE dbo.Inventory DROP CONSTRAINT fk_Inventory_Publication_PublicationID;
END;
IF NOT EXISTS (SELECT * FROM sys.key_constraints WHERE [name] = 'pk_Publication_PublicationID')
BEGIN
    ALTER TABLE dbo.Publication DROP CONSTRAINT pk_Publication_PublicationID;
END;
GO

--Add the primary key column and constraint
IF NOT EXISTS (SELECT * from sys.columns WHERE object_id = OBJECT_ID('Publication') AND [name] = 'PubID')
BEGIN
    ALTER TABLE dbo.Publication ADD PubID INT IDENTITY(1,1) NOT NULL;
END;

IF NOT EXISTS (SELECT * FROM sys.key_constraints WHERE [name] = 'pk_Publication_PubID')
BEGIN
    ALTER TABLE dbo.Publication ADD CONSTRAINT pk_Publication_PubID PRIMARY KEY CLUSTERED (PubID);
END;
GO

--Create a unique nonclustered index on PublicationID
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Publication') AND [name] = 'ncixunq_Publication_PublicationID')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX ncixunq_Publication_PublicationID
        ON dbo.Publication (PublicationID);
END;
GO

--Add a covering index for the procedure query
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Publication') AND [name] = 'ncix_Publication_AuthorID_include_PublicationID_Title_Genre_Rating')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Publication_AuthorID_include_PublicationID_Title_Genre_Rating
        ON [dbo].[Publication] ([AuthorID])
        INCLUDE ([PublicationID],[Title],[Genre],[Rating])
END;
GO

--Reinstate our foreign keys and rebuild the indexes
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_Inventory_Publication_PublicationID')
BEGIN
    ALTER TABLE dbo.Inventory ADD CONSTRAINT fk_Inventory_Publication_PublicationID FOREIGN KEY (PublicationID) REFERENCES Publication(PublicationID);
END;
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_OrderDetail_Publication_PublicationID')
BEGIN
    ALTER TABLE dbo.OrderDetail ADD CONSTRAINT fk_OrderDetail_Publication_PublicationID FOREIGN KEY (PublicationID) REFERENCES Publication(PublicationID);
END;
ALTER INDEX ALL ON dbo.Publication REBUILD;
GO

--Add the FullName column to the author table
IF NOT EXISTS (SELECT * from sys.columns WHERE object_id = OBJECT_ID('Author') AND [name] = 'FullName')
BEGIN
    ALTER TABLE dbo.Author ADD FullName VARCHAR(512);
END;
UPDATE dbo.Author SET FullName = CONCAT(FirstName, ' ', LastName) WHERE FullName IS NULL;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddAuthor
( @fName VARCHAR(256)
, @lName VARCHAR(256)
, @DOB DATETIME)
AS
INSERT INTO dbo.Author (FirstName, LastName, DOB, FullName)
SELECT @fName, @lName, @DOB, CONCAT(@fName, ' ', @lName);
RETURN SCOPE_IDENTITY();
/*****************************************************************************************
Created: unknown author
Purpose: To add a new author to the Author table
Modified: 2024-08-12 lmesa: Adding functionality to support the new FullName column
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdateAuthor
( @authorID INT
, @fName VARCHAR(256)=NULL
, @lName VARCHAR(256)=NULL
, @DOB DATETIME=NULL)
AS
UPDATE dbo.Author
SET FirstName = CASE WHEN @fName IS NOT NULL THEN @fName ELSE FirstName END
, LastName = CASE WHEN @lName IS NOT NULL THEN @lName ELSE LastName END
, DOB = CASE WHEN @DOB IS NOT NULL THEN @DOB ELSE DOB END
, FullName = CONCAT(CASE WHEN @fName IS NOT NULL THEN @fName ELSE FirstName END 
    , ' ', CASE WHEN @lName IS NOT NULL THEN @lName ELSE LastName END)
WHERE AuthorID = @authorID;
/*****************************************************************************************
Created: unknown author
Purpose: To update an author entry in the Author table
Modified: 2024-08-12 lmesa: Adding functionality to support the new FullName column
*****************************************************************************************/
GO

--Add the fulltext indexes
IF NOT EXISTS (SELECT * FROM sys.databases WHERE [name] = 'ShortFiction' AND is_fulltext_enabled = 1)
BEGIN
    EXEC sp_fulltext_database 'enable';
END;
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE [name] = 'author_name_catalog')
BEGIN
    CREATE FULLTEXT CATALOG author_name_catalog;
END;
GO

IF NOT EXISTS (SELECT * FROM sys.fulltext_index_columns fic 
    JOIN sys.columns c ON fic.object_id = c.object_id AND fic.column_id = c.column_id
    WHERE fic.object_id = OBJECT_ID('dbo.Author'))
BEGIN
CREATE FULLTEXT INDEX ON dbo.Author 
    ( FullName )
    KEY INDEX pk_Author_AuthorID ON author_name_catalog;
END;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchForAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchForAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchForAuthor
( @name VARCHAR(256)=NULL
, @DOBYear INT=NULL
, @DOBMonth INT=NULL
, @DOBDay INT=NULL)
AS
IF @name IS NOT NULL
BEGIN
    SELECT AuthorID, FirstName, LastName, DOB 
    FROM dbo.Author 
    WHERE CONTAINS(FullName, @name)
    AND DATEPART(yyyy, DOB) = CASE WHEN @DOBYear IS NOT NULL THEN @DOBYear ELSE DATEPART(yyyy, DOB) END
    AND DATEPART(mm, DOB) = CASE WHEN @DOBMonth IS NOT NULL THEN @DOBMonth ELSE DATEPART(mm, DOB) END 
    AND DATEPART(dd, DOB) = CASE WHEN @DOBDay IS NOT NULL THEN @DOBDay ELSE DATEPART(dd, DOB) END
END
ELSE
BEGIN
    SELECT AuthorID, FirstName, LastName, DOB 
    FROM dbo.Author 
    WHERE DATEPART(yyyy, DOB) = CASE WHEN @DOBYear IS NOT NULL THEN @DOBYear ELSE DATEPART(yyyy, DOB) END
    AND DATEPART(mm, DOB) = CASE WHEN @DOBMonth IS NOT NULL THEN @DOBMonth ELSE DATEPART(mm, DOB) END 
    AND DATEPART(dd, DOB) = CASE WHEN @DOBDay IS NOT NULL THEN @DOBDay ELSE DATEPART(dd, DOB) END
END;
/*****************************************************************************************
Created: unknown author
Purpose: To return author information based on either a name search or a partial or full birthdate
Modified: 2024-08-12 lmesa: Making use of the full-text index on FullName
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchInventoryByAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchInventoryByAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchInventoryByAuthor
( @name VARCHAR(256)=NULL )
AS
IF @name IS NOT NULL
BEGIN
    SELECT a.FirstName, a.LastName, p.Title, p.Genre, FORMAT(p.DatePublished, 'dd-MM-yyyy') AS DatePublished, p.Rating, i.Price, i.Quantity AS QuantityAvailable
    FROM dbo.Author a 
    JOIN dbo.Publication p ON a.AuthorID = p.AuthorID 
    JOIN dbo.Inventory i  ON p.PubID = i.PubID
    WHERE CONTAINS(FullName, @name);
END;
ELSE
BEGIN
    SELECT a.FirstName, a.LastName, p.Title, p.Genre, FORMAT(p.DatePublished, 'dd-MM-yyyy') AS DatePublished, p.Rating, i.Price, i.Quantity AS QuantityAvailable
    FROM dbo.Author a 
    JOIN dbo.Publication p ON a.AuthorID = p.AuthorID 
    JOIN dbo.Inventory i  ON p.PubID = i.PubID
END;
/*****************************************************************************************
Created: unknown author
Purpose: To return inventory information based on a name - will return all rows when no name is supplied
Modified: 2024-08-12 lmesa: Making use of the full-text index on FullName
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchPublicationInfoWithInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchPublicationInfoWithInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchPublicationInfoWithInventory
( @title VARCHAR(256)=NULL
, @genre VARCHAR(128)=NULL
, @rating SMALLINT=NULL
, @authorName VARCHAR(256)=NULL
, @hasInventory BIT=NULL)
AS
IF @authorName IS NOT NULL
BEGIN
    SELECT p.PublicationID, p.Title, p.Genre, a.FullName AS AuthorName, p.Rating
        , CASE WHEN SUM(i.Quantity) IS NULL THEN 'Out of Stock' ELSE CAST(SUM(i.Quantity) AS VARCHAR) + ' available' END AS QuantityAvailable
    FROM dbo.Publication p 
    INNER JOIN dbo.Author a ON p.AuthorID = a.AuthorID
    LEFT JOIN dbo.Inventory i ON p.publicationid = i.PublicationID 
    WHERE CONTAINS(FullName, @authorName)
    AND (p.Title LIKE '%' + @title + '%' OR @title IS NULL)
    AND Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END
    AND Rating = CASE WHEN @rating IS NOT NULL THEN @rating ELSE Rating END
    AND ((i.Quantity IS NOT NULL AND @hasInventory = 1) OR (@hasInventory = 0 AND i.Quantity IS NULL) OR (@hasInventory IS NULL))
    GROUP BY p.PublicationID, p.Title, p.Genre, a.FullName, p.Rating;
END;
ELSE
BEGIN
    SELECT p.PublicationID, p.Title, p.Genre, a.FullName AS AuthorName, p.Rating
        , CASE WHEN SUM(i.Quantity) IS NULL THEN 'Out of Stock' ELSE CAST(SUM(i.Quantity) AS VARCHAR) + ' available' END AS QuantityAvailable
    FROM dbo.Publication p 
    INNER JOIN dbo.Author a ON p.AuthorID = a.AuthorID
    LEFT JOIN dbo.Inventory i ON p.publicationid = i.PublicationID 
    WHERE (p.Title LIKE '%' + @title + '%' OR @title IS NULL)
    AND Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END
    AND Rating = CASE WHEN @rating IS NOT NULL THEN @rating ELSE Rating END
    AND ((i.Quantity IS NOT NULL AND @hasInventory = 1) OR (@hasInventory = 0 AND i.Quantity IS NULL) OR (@hasInventory IS NULL))
    GROUP BY p.PublicationID, p.Title, p.Genre, a.FullName, p.Rating;
END;

IF @@ROWCOUNT = 0
BEGIN
    SELECT 'No publications have been found for the selected criteria.' AS Message;
END;
/*****************************************************************************************
Created: 2024-08-08 lmesa
Purpose: To return Publication information based on various search criteria
Modified: 2024-08-12 lmesa: Replacing concatenation of first and last name to use FullName.
*****************************************************************************************/
GO

--Rebuild the indices
ALTER INDEX ALL ON dbo.Publication REBUILD;
ALTER INDEX ALL ON dbo.Author REBUILD;
ALTER INDEX ALL ON dbo.Inventory REBUILD;
GO

--Add the PubID column to the Inventory table
IF NOT EXISTS (SELECT * from sys.columns WHERE object_id = OBJECT_ID('Inventory') AND [name] = 'PubID')
BEGIN
    ALTER TABLE dbo.Inventory ADD PubID INT;
END;
GO

--Update the PubID values from the Publication table
UPDATE i 
SET PubID = p.PubID 
FROM dbo.Inventory i 
JOIN dbo.Publication p ON i.PublicationID = p.PublicationID
WHERE i.PubID IS NULL;
GO

--Drop the old PublicationID-based index
IF EXISTS (SELECT * FROM sys.indexes WHERE [name] = 'ncix_Inventory_PublicationID_WarehouseLocation_include_Quantity')
BEGIN
    DROP INDEX ncix_Inventory_PublicationID_WarehouseLocation_include_Quantity
        ON dbo.Inventory;
END;


IF EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_Inventory_Publication_PublicationID')
BEGIN
    ALTER TABLE Inventory
    DROP CONSTRAINT fk_Inventory_Publication_PublicationID;
END;

IF EXISTS (SELECT * from sys.columns WHERE object_id = OBJECT_ID('Inventory') AND [name] = 'PublicationID')
BEGIN
    ALTER TABLE dbo.Inventory DROP COLUMN PublicationID;
END;

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE [name] = 'fk_Inventory_Publication_PubID')
BEGIN
    ALTER TABLE dbo.Inventory ADD CONSTRAINT fk_Inventory_Publication_PubID FOREIGN KEY (PubID) REFERENCES Publication(PubID);
END;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE [name] = 'ncix_Inventory_PubID_include_Quantity')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Inventory_PubID_include_Quantity
        ON [dbo].[Inventory] ([PubID])
        INCLUDE ([Quantity]);
END;

IF EXISTS (SELECT * FROM sys.indexes WHERE [name] = 'ncix_Publication_AuthorID_include_PublicationID_Title_Genre_Rating')
BEGIN
    DROP INDEX ncix_Publication_AuthorID_include_PublicationID_Title_Genre_Rating
        ON dbo.Publication;
END;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE [name] = 'ncix_Publication_AuthorID_include_PubID_Title_Genre_Rating')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Publication_AuthorID_include_PubID_Title_Genre_Rating
        ON [dbo].[Publication] ([AuthorID])
        INCLUDE ([PubID],[Title],[Genre],[Rating])
END;
GO


IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE [dbo].[AddInventory]
( @PubID INT
, @WarehouseLocation CHAR(8)
, @Price DECIMAL(5,2)
, @Quantity SMALLINT)
AS
INSERT INTO dbo.Inventory (PubID, WarehouseLocation, Price, Quantity)
SELECT @PubID, @WarehouseLocation, @Price, @Quantity
/*****************************************************************************************
Created: unknown author
Purpose: To add an item to inventory in a specific warehouse location with a price and quantity
Modified: 2024-08-12 lmesa: Making use of the new PubID integer column
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'DecrementInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.DecrementInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE [dbo].[DecrementInventory]
( @PubID INT
, @WarehouseLocation CHAR(8)
, @Quantity SMALLINT)
AS
DECLARE @QuantityOnHand INT;
SELECT @QuantityOnHand = Quantity FROM Inventory WHERE PubID = @PubID AND WarehouseLocation = @WarehouseLocation;
IF @QuantityOnHand > @Quantity
BEGIN
    UPDATE dbo.Inventory SET Quantity = Quantity - @Quantity WHERE PubID = @PubID AND WarehouseLocation = @WarehouseLocation;
END;
ELSE
BEGIN
    RAISERROR('An error occurred updating inventory. Please ensure there is quantity of the publication greater than the quantity requested in the location specified', 16, 1)
END;
/*****************************************************************************************
Created: unknown author
Purpose: To remove quantity of an item from inventory in a specific warehouse location
Modified: 2024-08-12 lmesa: Making use of the new PubID integer column
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE [dbo].[UpdateInventory]
( @pubID INT
, @warehouseLocation CHAR(8)
, @price DECIMAL(5,2)=NULL
, @quantity SMALLINT=NULL)
AS
UPDATE dbo.Inventory 
SET Quantity = CASE WHEN @quantity IS NOT NULL THEN @quantity ELSE Quantity END,
Price = CASE WHEN @price IS NOT NULL THEN @price ELSE Price END
WHERE PubID = @pubID AND WarehouseLocation = @warehouseLocation;

SELECT PubID, WarehouseLocation, Price, Quantity
FROM dbo.Inventory
WHERE PubID = @pubID AND WarehouseLocation = @warehouseLocation;
/*****************************************************************************************
Created: unknown author
Purpose: To update the price and/or quantity of an item in inventory in a specific warehouse location
    and return that inventory information to the caller
Modified: 2024-08-12 lmesa: Making use of the new PubID integer column
*****************************************************************************************/
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchPublicationInfoWithInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchPublicationInfoWithInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchPublicationInfoWithInventory
( @title VARCHAR(256)=NULL
, @genre VARCHAR(128)=NULL
, @rating SMALLINT=NULL
, @authorName VARCHAR(256)=NULL
, @hasInventory BIT=NULL)
AS
IF @authorName IS NOT NULL
BEGIN
    SELECT p.PublicationID, p.Title, p.Genre, a.FullName AS AuthorName, p.Rating
        , CASE WHEN SUM(i.Quantity) IS NULL THEN 'Out of Stock' ELSE CAST(SUM(i.Quantity) AS VARCHAR) + ' available' END AS QuantityAvailable
    FROM dbo.Publication p 
    INNER JOIN dbo.Author a ON p.AuthorID = a.AuthorID
    LEFT JOIN dbo.Inventory i ON p.PubID = i.PubID 
    WHERE CONTAINS(FullName, @authorName)
    AND (p.Title LIKE '%' + @title + '%' OR @title IS NULL)
    AND Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END
    AND Rating = CASE WHEN @rating IS NOT NULL THEN @rating ELSE Rating END
    AND ((i.Quantity IS NOT NULL AND @hasInventory = 1) OR (@hasInventory = 0 AND i.Quantity IS NULL) OR (@hasInventory IS NULL))
    GROUP BY p.PublicationID, p.Title, p.Genre, a.FullName, p.Rating;
END;
ELSE
BEGIN
    SELECT p.PublicationID, p.Title, p.Genre, a.FullName AS AuthorName, p.Rating
        , CASE WHEN SUM(i.Quantity) IS NULL THEN 'Out of Stock' ELSE CAST(SUM(i.Quantity) AS VARCHAR) + ' available' END AS QuantityAvailable
    FROM dbo.Publication p 
    INNER JOIN dbo.Author a ON p.AuthorID = a.AuthorID
    LEFT JOIN dbo.Inventory i ON p.PubID = i.PubID 
    WHERE (p.Title LIKE '%' + @title + '%' OR @title IS NULL)
    AND Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END
    AND Rating = CASE WHEN @rating IS NOT NULL THEN @rating ELSE Rating END
    AND ((i.Quantity IS NOT NULL AND @hasInventory = 1) OR (@hasInventory = 0 AND i.Quantity IS NULL) OR (@hasInventory IS NULL))
    GROUP BY p.PublicationID, p.Title, p.Genre, a.FullName, p.Rating;
END;

IF @@ROWCOUNT = 0
BEGIN
    SELECT 'No publications have been found for the selected criteria.' AS Message;
END;
/*****************************************************************************************
Created: 2024-08-08 lmesa
Purpose: To return Publication information based on various search criteria
Modified: 2024-08-12 lmesa: Replacing concatenation of first and last name to use FullName.
Modified: 2024-08-13 lmesa: Updating the join condition for the Inventory table
*****************************************************************************************/
GO
