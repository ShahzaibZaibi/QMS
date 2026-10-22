CREATE OR ALTER PROCEDURE dbo.usp_User_Count
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS Total FROM dbo.Users;
END
GO

-- Sirf pehli baar: koi user na ho to Owner bana deta hai (branch = pehli active branch, role = Owner)
CREATE OR ALTER PROCEDURE dbo.usp_Bootstrap_CreateOwner
    @Username     NVARCHAR(50),
    @PasswordHash NVARCHAR(500),
    @FullName     NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM dbo.Users WITH (UPDLOCK, HOLDLOCK))
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS INT) AS UserId;
            RETURN;
        END

        DECLARE @BranchId INT = (SELECT TOP (1) Id FROM dbo.Branches WHERE IsActive = 1 ORDER BY Id);
        DECLARE @RoleId   INT = (SELECT Id FROM dbo.Roles WHERE Name = N'Owner');
        IF @BranchId IS NULL OR @RoleId IS NULL
            THROW 50001, N'Seed data mukammal nahi (branch ya Owner role nahi mila).', 1;

        INSERT dbo.Users (Username, PasswordHash, FullName, BranchId)
        VALUES (@Username, @PasswordHash, @FullName, @BranchId);
        DECLARE @UserId INT = SCOPE_IDENTITY();

        INSERT dbo.UserRoles (UserId, RoleId) VALUES (@UserId, @RoleId);

        EXEC dbo.usp_AuditLog_Add @UserId = @UserId, @Action = N'User.Bootstrap',
             @EntityName = N'User', @EntityId = @UserId, @Details = N'Pehla Owner user bana';

        COMMIT;
        SELECT @UserId AS UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- Naya ya edit (@Id NULL = naya). @RoleIds comma wali list: '1,3'.
-- Edit mein @PasswordHash khali ho to purana password rehta hai.
-- User band karne, role ya password badalne par uske refresh tokens radd ho jate hain.
CREATE OR ALTER PROCEDURE dbo.usp_User_Save
    @Id           INT = NULL,
    @Username     NVARCHAR(50),
    @PasswordHash NVARCHAR(500) = NULL,
    @FullName     NVARCHAR(100),
    @BranchId     INT,
    @IsActive     BIT = 1,
    @RoleIds      NVARCHAR(200),
    @ActorUserId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Username     = LTRIM(RTRIM(ISNULL(@Username, N'')));
    SET @FullName     = LTRIM(RTRIM(ISNULL(@FullName, N'')));
    SET @PasswordHash = NULLIF(@PasswordHash, N'');

    IF @Username = N'' THROW 50020, N'Username likhna zaroori hai.', 1;
    IF @FullName = N'' THROW 50021, N'Poora naam likhna zaroori hai.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Id = @BranchId AND IsActive = 1)
        THROW 50022, N'Branch sahi nahi.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username AND (@Id IS NULL OR Id <> @Id))
        THROW 50023, N'Ye username pehle se maujood hai.', 1;
    IF @Id IS NULL AND @PasswordHash IS NULL
        THROW 50024, N'Naye user ke liye password zaroori hai.', 1;

    DECLARE @Roles TABLE (RoleId INT PRIMARY KEY);
    INSERT @Roles (RoleId)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM([value])) AS INT)
      FROM STRING_SPLIT(ISNULL(@RoleIds, N''), N',')
     WHERE LTRIM(RTRIM([value])) <> N'' AND TRY_CAST(LTRIM(RTRIM([value])) AS INT) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Roles) THROW 50025, N'Kam az kam ek role chunein.', 1;
    IF EXISTS (SELECT 1 FROM @Roles r WHERE NOT EXISTS
               (SELECT 1 FROM dbo.Roles x WHERE x.Id = r.RoleId AND x.IsActive = 1))
        THROW 50026, N'Role sahi nahi.', 1;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @RolesChanged BIT = 0;

        IF @Id IS NULL
        BEGIN
            INSERT dbo.Users (Username, PasswordHash, FullName, BranchId, IsActive, CreatedBy)
            VALUES (@Username, @PasswordHash, @FullName, @BranchId, @IsActive, @ActorUserId);
            SET @Id = SCOPE_IDENTITY();

            INSERT dbo.UserRoles (UserId, RoleId) SELECT @Id, RoleId FROM @Roles;
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @Id) THROW 50027, N'User nahi mila.', 1;

            IF EXISTS (SELECT RoleId FROM @Roles EXCEPT SELECT RoleId FROM dbo.UserRoles WHERE UserId = @Id)
               OR EXISTS (SELECT RoleId FROM dbo.UserRoles WHERE UserId = @Id EXCEPT SELECT RoleId FROM @Roles)
                SET @RolesChanged = 1;

            UPDATE dbo.Users
               SET Username     = @Username,
                   FullName     = @FullName,
                   BranchId     = @BranchId,
                   IsActive     = @IsActive,
                   PasswordHash = ISNULL(@PasswordHash, PasswordHash),
                   ModifiedAt   = dbo.fn_PktNow(),
                   ModifiedBy   = @ActorUserId
             WHERE Id = @Id;

            IF @RolesChanged = 1
            BEGIN
                DELETE FROM dbo.UserRoles WHERE UserId = @Id;
                INSERT dbo.UserRoles (UserId, RoleId) SELECT @Id, RoleId FROM @Roles;
            END

            IF @IsActive = 0 OR @RolesChanged = 1 OR @PasswordHash IS NOT NULL
                UPDATE dbo.RefreshTokens SET RevokedAt = dbo.fn_PktNow()
                 WHERE UserId = @Id AND RevokedAt IS NULL;
        END

        EXEC dbo.usp_AuditLog_Add @UserId = @ActorUserId, @Action = N'User.Save',
             @EntityName = N'User', @EntityId = @Id,
             @Details = @Username;   -- password/hash kabhi log nahi hota

        COMMIT;
        SELECT @Id AS Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
