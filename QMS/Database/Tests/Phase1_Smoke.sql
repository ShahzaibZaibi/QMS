-- Haath se chalane ka test (runner isay nahi chalata). QistDB par SSMS mein chalayein.
-- 1) Number generator: pehla number MAIN-R-<saal>-000001, doosra ...000002
DECLARE @n1 NVARCHAR(50), @n2 NVARCHAR(50);
EXEC dbo.usp_Number_Next @BranchId = 1, @SeqType = N'Receipt', @Number = @n1 OUTPUT;
EXEC dbo.usp_Number_Next @BranchId = 1, @SeqType = N'Receipt', @Number = @n2 OUTPUT;
SELECT @n1 AS First, @n2 AS Second;

-- 2) Ghalat qism par error 50010 aana chahiye
BEGIN TRY
    DECLARE @bad NVARCHAR(50);
    EXEC dbo.usp_Number_Next @BranchId = 1, @SeqType = N'Xyz', @Number = @bad OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ExpectedError_50010, ERROR_MESSAGE() AS Msg;
END CATCH;

-- 3) Owner ki permissions (28 honi chahiye)
EXEC dbo.usp_Auth_GetUser @UserId = 1;

-- 4) Shop profile
EXEC dbo.usp_ShopProfile_Get;
