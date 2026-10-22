CREATE OR ALTER PROCEDURE dbo.usp_RefreshToken_Create
    @UserId     INT,
    @TokenHash  CHAR(64),
    @ValidHours INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Purane (expire/revoke hue, 7 din se zyada) tokens ki safai
    DELETE FROM dbo.RefreshTokens
     WHERE UserId = @UserId
       AND (ExpiresAt < DATEADD(DAY, -7, dbo.fn_PktNow()) OR RevokedAt < DATEADD(DAY, -7, dbo.fn_PktNow()));

    INSERT dbo.RefreshTokens (UserId, TokenHash, ExpiresAt)
    VALUES (@UserId, @TokenHash, DATEADD(HOUR, @ValidHours, dbo.fn_PktNow()));
END
GO

-- Purana token radd karke naya banata hai. Token ghalat/expire/revoked ya user band ho to koi row wapas nahi.
CREATE OR ALTER PROCEDURE dbo.usp_RefreshToken_Rotate
    @OldHash    CHAR(64),
    @NewHash    CHAR(64),
    @ValidHours INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @UserId = t.UserId
          FROM dbo.RefreshTokens t WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Users u ON u.Id = t.UserId AND u.IsActive = 1
         WHERE t.TokenHash = @OldHash
           AND t.RevokedAt IS NULL
           AND t.ExpiresAt > dbo.fn_PktNow();

        IF @UserId IS NULL
        BEGIN
            ROLLBACK;
            SELECT CAST(NULL AS INT) AS UserId WHERE 1 = 0;
            RETURN;
        END

        UPDATE dbo.RefreshTokens SET RevokedAt = dbo.fn_PktNow() WHERE TokenHash = @OldHash;

        INSERT dbo.RefreshTokens (UserId, TokenHash, ExpiresAt)
        VALUES (@UserId, @NewHash, DATEADD(HOUR, @ValidHours, dbo.fn_PktNow()));

        COMMIT;
        SELECT @UserId AS UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshToken_Revoke
    @TokenHash CHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.RefreshTokens SET RevokedAt = dbo.fn_PktNow()
     WHERE TokenHash = @TokenHash AND RevokedAt IS NULL;
END
GO
