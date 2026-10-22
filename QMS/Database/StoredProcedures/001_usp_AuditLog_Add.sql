CREATE OR ALTER PROCEDURE dbo.usp_AuditLog_Add
    @UserId     INT = NULL,
    @Action     NVARCHAR(50),
    @EntityName NVARCHAR(60),
    @EntityId   INT = NULL,
    @Details    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.AuditLog (UserId, Action, EntityName, EntityId, Details)
    VALUES (@UserId, @Action, @EntityName, @EntityId, @Details);
END
GO
