/*
  Marhala 1 (izafa) - PASSWORD badalne ki procedure
  01, 02, 03 chal chuki hon to sirf ye chalayein. Ye jitni baar chahein chala sakte hain (CREATE OR ALTER).
*/
USE QistDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_SetPassword
    @UserId       INT,
    @PasswordHash NVARCHAR(500),
    @ActorUserId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISNULL(@PasswordHash, N'') = N'' THROW 50028, N'Password khali nahi ho sakta.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId) THROW 50027, N'User nahi mila.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.Users
           SET PasswordHash = @PasswordHash,
               ModifiedAt   = dbo.fn_PktNow(),
               ModifiedBy   = @ActorUserId
         WHERE Id = @UserId;

        -- Password ya hash kabhi log nahi hota, sirf ye ke kis ka badla
        EXEC dbo.usp_AuditLog_Add @UserId = @ActorUserId, @Action = N'User.PasswordChange',
             @EntityName = N'User', @EntityId = @UserId, @Details = NULL;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
