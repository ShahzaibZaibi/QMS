-- Password ka muqabla C# (PasswordHasher) karta hai; SP user, hash aur permissions wapas karta hai.
CREATE OR ALTER PROCEDURE dbo.usp_Auth_Login
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId INT = (SELECT Id FROM dbo.Users WHERE Username = @Username);
    EXEC dbo.usp_Auth_GetUser @UserId = @UserId;
END
GO
