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
SELECT p.PublicationID, p.Title, p.Genre, CONCAT(a.FirstName, ' ', LastName) AS AuthorName, p.Rating
    , CASE WHEN SUM(i.Quantity) IS NULL THEN 'Out of Stock' ELSE CAST(SUM(i.Quantity) AS VARCHAR) + ' available' END AS QuantityAvailable
FROM dbo.Publication p 
INNER JOIN dbo.Author a ON p.AuthorID = a.AuthorID
LEFT JOIN dbo.Inventory i ON p.publicationid = i.PublicationID 
WHERE (CONCAT(a.FirstName, ' ', LastName) LIKE '%' + @authorName + '%' OR @authorName IS NULL)
AND (p.Title LIKE '%' + @title + '%' OR @title IS NULL)
AND Genre = CASE WHEN @genre IS NOT NULL THEN @genre ELSE Genre END
AND Rating = CASE WHEN @rating IS NOT NULL THEN @rating ELSE Rating END
AND ((i.Quantity IS NOT NULL AND @hasInventory = 1) OR (@hasInventory = 0 AND i.Quantity IS NULL) OR (@hasInventory IS NULL))
GROUP BY p.PublicationID, p.Title, p.Genre, CONCAT(FirstName, ' ', LastName), p.Rating;

IF @@ROWCOUNT = 0
BEGIN
    SELECT 'No publications have been found for the selected criteria.' AS Message;
END;
/*****************************************************************************************
Created: 2024-08-08 lmesa
Purpose: To return Publication information based on various search criteria
*****************************************************************************************/
GO

EXEC SearchPublicationInfoWithInventory;

EXEC SearchPublicationInfoWithInventory @title = 'felis';

EXEC SearchPublicationInfoWithInventory @title = 'enim', @genre = 'Satire';

EXEC SearchPublicationInfoWithInventory @authorName = 'Fidel', @hasInventory=0;

EXEC SearchPublicationInfoWithInventory @hasInventory=1;

EXEC SearchPublicationInfoWithInventory @rating=5;

EXEC SearchPublicationInfoWithInventory @rating=5, @authorName = 'Alex', @title='sapien';

EXEC SearchPublicationInfoWithInventory @title = 'nonc', @rating = 4, @hasInventory = 1, @genre = 'Self-Help';

DBCC FREEPROCCACHE WITH NO_INFOMSGS;

