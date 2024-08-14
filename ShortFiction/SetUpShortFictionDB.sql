USE master;
IF NOT EXISTS (SELECT * FROM sys.databases WHERE [name] = 'ShortFiction')
BEGIN
    CREATE DATABASE ShortFiction;
END;

IF NOT EXISTS (SELECT * FROM sys.databases WHERE [name] = 'ShortFiction' AND recovery_model = 3)
BEGIN
    ALTER DATABASE ShortFiction SET RECOVERY SIMPLE;
END;
GO

USE ShortFiction;
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE [name] = 'FileGroup01')
BEGIN
    ALTER DATABASE ShortFiction ADD FILEGROUP FileGroup01;
END;
GO
IF NOT EXISTS (SELECT * FROM sys.database_files WHERE [name] = 'ShortFiction_FG01_Data01')
BEGIN
    ALTER DATABASE ShortFiction ADD FILE
    ( NAME = ShortFiction_FG01_Data01
    , FILENAME = '/var/opt/mssql/data/ShortFiction_FG01_Data01.ndf'
    , SIZE = 30MB
    , FILEGROWTH = 5MB)
    TO FILEGROUP FileGroup01;
END;
IF EXISTS (SELECT * FROM sys.filegroups WHERE [name] = 'FileGroup01' AND is_default = 0)
BEGIN
    ALTER DATABASE ShortFiction MODIFY FILEGROUP FileGroup01 DEFAULT;
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Author')
BEGIN
    CREATE TABLE Author 
        ( AuthorID INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_Author_AuthorID PRIMARY KEY (AuthorID)
        , FirstName VARCHAR(256)
        , LastName VARCHAR(256)
        , DOB DATETIME)
END;
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Author') and [name] = 'ncix_Author_LastName_FirstName')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Author_LastName_FirstName ON Author (LastName, FirstName);
END;
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Publication')
BEGIN
    CREATE TABLE Publication
        ( PublicationID UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_Publication_PublicationID PRIMARY KEY (PublicationID) CONSTRAINT df_PublicationID DEFAULT (NEWID())
        , Title VARCHAR(256)
        , Genre VARCHAR(128)
        , DatePublished DATETIME
        , Rating INT
        , AuthorID INT CONSTRAINT fk_Publication_Author_AuthorID FOREIGN KEY (AuthorID) REFERENCES Author(AuthorID))
END;
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Publication') and [name] = 'ncix_Publication_Genre')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Publication_Genre ON Publication (Genre);
END;
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Publication') and [name] = 'ncix_Publication_Rating')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Publication_Rating ON Publication (Rating);
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Inventory')
BEGIN
    CREATE TABLE Inventory 
        ( PublicationID UNIQUEIDENTIFIER NOT NULL CONSTRAINT fk_Inventory_Publication_PublicationID FOREIGN KEY REFERENCES Publication(PublicationID)
        , WarehouseLocation CHAR(8) NOT NULL
        , Price DECIMAL(5,2)
        , Quantity SMALLINT);
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Customer')
BEGIN
    CREATE TABLE Customer
        ( CustomerID INT IDENTITY(2001,1) CONSTRAINT pk_Customer_CustomerID PRIMARY KEY (CustomerID)
        , FirstName VARCHAR(256)
        , LastName VARCHAR(256)
        , AddressLine1 VARCHAR(256)
        , AddressLine2 VARCHAR(256)
        , City VARCHAR(256)
        , [State] CHAR(5)
        , PostalCode CHAR(14))
END;
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('Customer') and [name] = 'ncix_Customer_LastName_FirstName')
BEGIN
    CREATE NONCLUSTERED INDEX ncix_Customer_LastName_FirstName ON Customer (LastName, FirstName);
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Order')
BEGIN
    CREATE TABLE [Order]
        ( OrderID BIGINT IDENTITY(20824,1) NOT NULL CONSTRAINT pk_Order_OrderID PRIMARY KEY (OrderID)
        , CustomerID INT NOT NULL CONSTRAINT fk_Customer_CustomerID FOREIGN KEY REFERENCES Customer (CustomerID)
        , OrderDate DATETIME
        , [Status] CHAR(20)
        )
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'OrderDetail')
BEGIN
    CREATE TABLE [OrderDetail]
        ( OrderID BIGINT NOT NULL CONSTRAINT fk_Order_OrderID FOREIGN KEY REFERENCES [Order] (OrderID)
        , PublicationID UNIQUEIDENTIFIER NOT NULL CONSTRAINT fk_Publication_PublicationID FOREIGN KEY REFERENCES Publication (PublicationID)
        , PurchasePrice DECIMAL(5,2)
        , PurchaseQuantity SMALLINT
        , ShippingDate DATETIME
        , TrackingNumber CHAR(20)
        , Tax AS CAST(PurchasePrice * PurchaseQuantity * .05 AS DECIMAL(5,2))
        , Total AS CAST((PurchasePrice * PurchaseQuantity) + (PurchasePrice * PurchaseQuantity * .05) AS DECIMAL(8,2)));
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddCustomer' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddCustomer AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddCustomer
( @fName VARCHAR(256)
, @lName VARCHAR(256)
, @addressLine1 VARCHAR(256)
, @addressLine2 VARCHAR(256)
, @city VARCHAR(256)
, @state CHAR(5)
, @postalCode CHAR(14))
AS
INSERT INTO dbo.Customer(FirstName, LastName, AddressLine1, AddressLine2, City, [State], PostalCode)
SELECT @fName, @lName, @addressLine1, @addressLine2, @city, @state, @postalCode;

RETURN SCOPE_IDENTITY();
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateCustomer' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateCustomer AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdateCustomer
( @customerID INT
, @fName VARCHAR(256) = NULL
, @lName VARCHAR(256) = NULL
, @addressLine1 VARCHAR(256) = NULL
, @addressLine2 VARCHAR(256) = NULL
, @city VARCHAR(256) = NULL
, @state CHAR(5) = NULL
, @postalCode CHAR(14) = NULL)
AS
UPDATE dbo.Customer
SET FirstName = CASE WHEN @fName IS NOT NULL THEN @fName ELSE FirstName END
    , LastName = CASE WHEN @lName IS NOT NULL THEN @lName ELSE LastName END
    , AddressLine1 = CASE WHEN @addressLine1 IS NOT NULL THEN @addressLine1 ELSE AddressLine1 END
    , AddressLine2 = CASE WHEN @addressLine2 IS NOT NULL THEN @addressLine2 ELSE AddressLine2 END
    , City = CASE WHEN @city IS NOT NULL THEN @city ELSE City END
    , [State] = CASE WHEN @state IS NOT NULL THEN @state ELSE [State] END
    , PostalCode = CASE WHEN @postalCode IS NOT NULL THEN @postalCode ELSE PostalCode END
WHERE CustomerID = @customerID;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'GetCustomerTotalsByMonth' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.GetCustomerTotalsByMonth AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.GetCustomerTotalsByMonth
AS

SELECT c.CustomerID, c.FirstName, c.LastName, DATEPART(m, o.OrderDate), SUM(od.Total) AS Total
FROM dbo.Customer c 
JOIN dbo.[Order] o ON c.CustomerID = o.CustomerID
JOIN dbo.OrderDetail od ON o.OrderID = od.OrderID
WHERE o.OrderDate > DATEADD(m, -6, GETDATE())
GROUP BY c.CustomerID, c.FirstName, c.LastName, DATEPART(m, o.OrderDate)
ORDER BY DATEPART(m, o.OrderDate), SUM(od.Total) DESC;
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
INSERT INTO dbo.Author (FirstName, LastName, DOB)
SELECT @fName, @lName, @DOB;
RETURN SCOPE_IDENTITY();
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
WHERE AuthorID = @authorID;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchForAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchForAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchForAuthor
( @fName VARCHAR(256)=NULL
, @lName VARCHAR(256)=NULL
, @DOBYear INT=NULL
, @DOBMonth INT=NULL
, @DOBDay INT=NULL)
AS
SELECT AuthorID, FirstName, LastName, DOB 
FROM dbo.Author 
WHERE FirstName = CASE WHEN @fName IS NOT NULL THEN @fName ELSE FirstName END
AND LastName = CASE WHEN @lName IS NOT NULL THEN @lName ELSE LastName END
AND DATEPART(yyyy, DOB) = CASE WHEN @DOBYear IS NOT NULL THEN @DOBYear ELSE DATEPART(yyyy, DOB) END
AND DATEPART(mm, DOB) = CASE WHEN @DOBMonth IS NOT NULL THEN @DOBMonth ELSE DATEPART(mm, DOB) END 
AND DATEPART(dd, DOB) = CASE WHEN @DOBDay IS NOT NULL THEN @DOBDay ELSE DATEPART(dd, DOB) END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'SearchInventoryByAuthor' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.SearchInventoryByAuthor AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.SearchInventoryByAuthor
( @fName VARCHAR(256)=NULL
, @lName VARCHAR(256)=NULL)
AS
SELECT a.FirstName, a.LastName, p.Title, p.Genre, FORMAT(p.DatePublished, 'dd-MM-yyyy') AS DatePublished, p.Rating, i.Price, i.Quantity AS QuantityAvailable
FROM dbo.Author a 
JOIN dbo.Publication p ON a.AuthorID = p.AuthorID 
JOIN dbo.Inventory i  ON p.PublicationID = i.PublicationID
WHERE FirstName = CASE WHEN @fName IS NOT NULL THEN @fName ELSE FirstName END
AND LastName = CASE WHEN @lName IS NOT NULL THEN @lName ELSE LastName END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddPublication' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddPublication AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddPublication
( @title VARCHAR(256)
, @genre VARCHAR(128)
, @datePublished DATETIME
, @rating SMALLINT
, @authorID INT)
AS
INSERT INTO dbo.Publication (Title, Genre, DatePublished, Rating, AuthorID)
SELECT @title, @genre, @datePublished, @rating, @authorID;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdatePublication' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdatePublication AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdatePublication
( @PublicationID UNIQUEIDENTIFIER
, @title VARCHAR(256)=NULL
, @genre VARCHAR(128)=NULL
, @datePublished DATETIME=NULL
, @rating SMALLINT=NULL
, @authorID INT=NULL)
AS
UPDATE dbo.Publication
SET Title = CASE WHEN @title IS NOT NULL THEN @title ELSE Title END,
Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END,
DatePublished = CASE WHEN @datePublished IS NOT NULL THEN @datePublished ELSE DatePublished END,
Rating = CASE WHEN @rating IS NOT NULL AND @rating BETWEEN 1 AND 5 THEN @rating ELSE Rating END,
AuthorID = CASE WHEN @authorID IS NOT NULL THEN @authorID ELSE AuthorID END
WHERE PublicationID = @PublicationID
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddInventory
( @PublicationID UNIQUEIDENTIFIER
, @WarehouseLocation CHAR(8)
, @Price DECIMAL(5,2)
, @Quantity SMALLINT)
AS
INSERT INTO dbo.Inventory (PublicationID, WarehouseLocation, Price, Quantity)
SELECT @PublicationID, @WarehouseLocation, @Price, @Quantity
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'DecrementInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.DecrementInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.DecrementInventory
( @PublicationID UNIQUEIDENTIFIER
, @WarehouseLocation CHAR(8)
, @Quantity SMALLINT)
AS
DECLARE @QuantityOnHand INT;
SELECT @QuantityOnHand = Quantity FROM Inventory WHERE PublicationID = @PublicationID AND WarehouseLocation = @WarehouseLocation;
IF @QuantityOnHand > @Quantity
BEGIN
    UPDATE dbo.Inventory SET Quantity = Quantity - @Quantity WHERE PublicationID = @PublicationID AND WarehouseLocation = @WarehouseLocation;
END;
ELSE
BEGIN
    RAISERROR('An error occurred updating inventory. Please ensure there is quantity of the publication greater than the quantity requested in the location specified', 16, 1)
END;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateInventory' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateInventory AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdateInventory
( @publicationID UNIQUEIDENTIFIER
, @warehouseLocation CHAR(8)
, @price DECIMAL(5,2)=NULL
, @quantity SMALLINT=NULL)
AS
UPDATE dbo.Inventory 
SET Quantity = CASE WHEN @quantity IS NOT NULL THEN @quantity ELSE Quantity END,
Price = CASE WHEN @price IS NOT NULL THEN @price ELSE Price END
WHERE PublicationID = @publicationID AND WarehouseLocation = @warehouseLocation;

SELECT PublicationID, WarehouseLocation, Price, Quantity
FROM dbo.Inventory
WHERE PublicationID = @publicationID AND WarehouseLocation = @warehouseLocation;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddOrder' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddOrder AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddOrder
( @customerID INT)
AS
IF EXISTS (SELECT * FROM dbo.Customer WHERE CustomerID = @customerID)
BEGIN
  INSERT INTO dbo.[Order] (CustomerID, OrderDate, [Status])
  SELECT @customerID, GETDATE(), 'New';
  SELECT SCOPE_IDENTITY() AS OrderID;
END;
ELSE
BEGIN
    RAISERROR('The indicated customer was not found in the system. Order failed to create.', 16, 1)
END;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateOrderStatus' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateOrderStatus AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdateOrderStatus
( @orderID INT
, @newStatus CHAR(20))
AS
IF EXISTS (SELECT * FROM dbo.[Order] WHERE OrderID = @orderID)
BEGIN
  UPDATE dbo.[Order] 
  SET [Status] = @newStatus
  WHERE OrderID = @orderID;
END;
ELSE
BEGIN
    RAISERROR('The indicated order was not found in the system. Order unable to be updated.', 16, 1)
END;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'AddOrderDetail' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.AddOrderDetail AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.AddOrderDetail
( @orderID INT
, @publicationID UNIQUEIDENTIFIER
, @purchasePrice DECIMAL(5,2)
, @purchaseQuantity SMALLINT)
AS
IF EXISTS (SELECT * FROM dbo.[Order] WHERE OrderID = @orderID)
    AND EXISTS (SELECT * FROM dbo.Publication WHERE PublicationID = @publicationID)
BEGIN
    INSERT INTO dbo.OrderDetail (OrderID, PublicationID, PurchasePrice, PurchaseQuantity)
    SELECT @orderID, @publicationID, @purchasePrice, @purchaseQuantity;
END;
ELSE
BEGIN
    RAISERROR('Either the indicated order or the indicated publication was not found in the system. Order detail unable to be added.', 16, 1)
END;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'UpdateOrderDetail' AND type = 'P')
BEGIN
    EXEC sp_executesql N'CREATE PROCEDURE dbo.UpdateOrderDetail AS RETURN(0);';
END;
GO
ALTER PROCEDURE dbo.UpdateOrderDetail
( @orderID INT
, @publicationID UNIQUEIDENTIFIER
, @purchasePrice DECIMAL(5,2)=NULL
, @purchaseQuantity SMALLINT=NULL
, @shipDate DATETIME=NULL
, @tracking CHAR(20)=NULL)
AS
IF EXISTS (SELECT * FROM dbo.[Order] WHERE OrderID = @orderID)
    AND EXISTS (SELECT * FROM dbo.Publication WHERE PublicationID = @publicationID)
BEGIN
    UPDATE dbo.OrderDetail
    SET PurchasePrice = CASE WHEN @purchasePrice IS NOT NULL THEN @purchasePrice ELSE PurchasePrice END
    , PurchaseQuantity = CASE WHEN @purchaseQuantity IS NOT NULL THEN @purchaseQuantity ELSE PurchaseQuantity END
    , ShippingDate = CASE WHEN @shipDate IS NOT NULL THEN @shipDate ELSE ShippingDate END
    , TrackingNumber = CASE WHEN @tracking IS NOT NULL THEN @tracking ELSE TrackingNumber END
    WHERE OrderID = @orderID AND publicationID = @publicationID
END;
ELSE
BEGIN
    RAISERROR('Either the indicated order or the indicated publication was not found in the system. Order detail unable to be added.', 16, 1)
END;
GO


