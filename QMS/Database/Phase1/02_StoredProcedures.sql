/*
  Marhala 1 - STORED PROCEDURES
  01_Tables.sql ke baad chalayein. Ye script jitni baar chahein chala sakte hain (CREATE OR ALTER).
*/
USE QistDB;
GO

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

-- Receipt / Sale / Contract ... ka agla number, jaise MAIN-R-2026-000123.
-- Dusre SPs ke transaction ke andar bhi chal sakta hai (apna transaction sirf tab kholta hai jab koi khula na ho).
CREATE OR ALTER PROCEDURE dbo.usp_Number_Next
    @BranchId INT,
    @SeqType  NVARCHAR(20),
    @Number   NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Letter NVARCHAR(3) = CASE @SeqType
        WHEN N'Receipt'         THEN N'R'
        WHEN N'Sale'            THEN N'S'
        WHEN N'Contract'        THEN N'C'
        WHEN N'Purchase'        THEN N'P'
        WHEN N'Return'          THEN N'RT'
        WHEN N'SupplierPayment' THEN N'SP'
        WHEN N'PurchaseReturn'  THEN N'PR'
    END;
    IF @Letter IS NULL THROW 50010, N'Number ki qism sahi nahi.', 1;

    DECLARE @Year    INT = YEAR(dbo.fn_PktToday());
    DECLARE @Last    INT;
    DECLARE @Prefix  NVARCHAR(30);
    DECLARE @Padding TINYINT;
    DECLARE @OwnTran BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        IF @OwnTran = 1 BEGIN TRAN;

        -- UPDLOCK + HOLDLOCK: do users ek hi waqt aayein to bhi number dohra nahi hoga
        UPDATE dbo.NumberSequences WITH (UPDLOCK, HOLDLOCK)
           SET @Last = LastNumber = LastNumber + 1,
               @Prefix = Prefix,
               @Padding = Padding
         WHERE BranchId = @BranchId AND SeqType = @SeqType AND [Year] = @Year;

        IF @@ROWCOUNT = 0
        BEGIN
            DECLARE @BranchCode NVARCHAR(10) = (SELECT Code FROM dbo.Branches WHERE Id = @BranchId);
            IF @BranchCode IS NULL THROW 50011, N'Branch nahi mili.', 1;

            SET @Prefix  = @BranchCode + N'-' + @Letter;
            SET @Padding = 6;
            SET @Last    = 1;

            INSERT dbo.NumberSequences (BranchId, SeqType, Prefix, [Year], LastNumber, Padding)
            VALUES (@BranchId, @SeqType, @Prefix, @Year, @Last, @Padding);
        END

        DECLARE @Digits NVARCHAR(10) = CAST(@Last AS NVARCHAR(10));
        SET @Number = @Prefix + N'-' + CAST(@Year AS NVARCHAR(4)) + N'-'
                    + CASE WHEN LEN(@Digits) >= @Padding THEN @Digits
                           ELSE RIGHT(REPLICATE(N'0', @Padding) + @Digits, @Padding) END;

        IF @OwnTran = 1 COMMIT;
    END TRY
    BEGIN CATCH
        IF @OwnTran = 1 AND @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- Teen result sets: (1) user, (2) roles ke naam, (3) permission codes
CREATE OR ALTER PROCEDURE dbo.usp_Auth_GetUser
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.Id, u.Username, u.PasswordHash, u.FullName, u.BranchId, u.IsActive
      FROM dbo.Users u
     WHERE u.Id = @UserId;

    SELECT r.Name
      FROM dbo.UserRoles ur
      JOIN dbo.Roles r ON r.Id = ur.RoleId AND r.IsActive = 1
     WHERE ur.UserId = @UserId
     ORDER BY r.Name;

    SELECT DISTINCT p.Code
      FROM dbo.UserRoles ur
      JOIN dbo.Roles r            ON r.Id = ur.RoleId AND r.IsActive = 1
      JOIN dbo.RolePermissions rp ON rp.RoleId = r.Id
      JOIN dbo.Permissions p      ON p.Id = rp.PermissionId
     WHERE ur.UserId = @UserId
     ORDER BY p.Code;
END
GO

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

CREATE OR ALTER PROCEDURE dbo.usp_ShopProfile_Get
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) ShopName, LogoPath, Address, Phone, Email, RegistrationNo,
                   ReceiptHeader, ReceiptFooter, CurrencySymbol, DefaultLanguage
      FROM dbo.ShopProfile
     ORDER BY Id;
END
GO

-- Login page ke liye (bina login): sirf naam, logo, zabaan
CREATE OR ALTER PROCEDURE dbo.usp_ShopProfile_GetPublic
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) ShopName, LogoPath, DefaultLanguage
      FROM dbo.ShopProfile
     ORDER BY Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ShopProfile_Save
    @ShopName        NVARCHAR(100),
    @Address         NVARCHAR(250) = NULL,
    @Phone           NVARCHAR(30)  = NULL,
    @Email           NVARCHAR(100) = NULL,
    @RegistrationNo  NVARCHAR(50)  = NULL,
    @ReceiptHeader   NVARCHAR(250) = NULL,
    @ReceiptFooter   NVARCHAR(250) = NULL,
    @CurrencySymbol  NVARCHAR(10),
    @DefaultLanguage NVARCHAR(10),
    @UserId          INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ShopName       = LTRIM(RTRIM(ISNULL(@ShopName, N'')));
    SET @CurrencySymbol = LTRIM(RTRIM(ISNULL(@CurrencySymbol, N'')));

    IF @ShopName = N''       THROW 50030, N'Dukaan ka naam likhna zaroori hai.', 1;
    IF @CurrencySymbol = N'' THROW 50031, N'Currency symbol likhna zaroori hai.', 1;
    IF @DefaultLanguage NOT IN (N'RomanUrdu', N'English')
        THROW 50032, N'Zabaan RomanUrdu ya English honi chahiye.', 1;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Id INT = (SELECT TOP (1) Id FROM dbo.ShopProfile ORDER BY Id);
        DECLARE @Old NVARCHAR(MAX) = (SELECT ShopName, Address, Phone, Email, RegistrationNo, ReceiptHeader,
                                             ReceiptFooter, CurrencySymbol, DefaultLanguage
                                        FROM dbo.ShopProfile WHERE Id = @Id
                                         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        UPDATE dbo.ShopProfile
           SET ShopName        = @ShopName,
               Address         = NULLIF(LTRIM(RTRIM(@Address)), N''),
               Phone           = NULLIF(LTRIM(RTRIM(@Phone)), N''),
               Email           = NULLIF(LTRIM(RTRIM(@Email)), N''),
               RegistrationNo  = NULLIF(LTRIM(RTRIM(@RegistrationNo)), N''),
               ReceiptHeader   = NULLIF(LTRIM(RTRIM(@ReceiptHeader)), N''),
               ReceiptFooter   = NULLIF(LTRIM(RTRIM(@ReceiptFooter)), N''),
               CurrencySymbol  = @CurrencySymbol,
               DefaultLanguage = @DefaultLanguage,
               ModifiedAt      = dbo.fn_PktNow(),
               ModifiedBy      = @UserId
         WHERE Id = @Id;

        DECLARE @New NVARCHAR(MAX) = (SELECT ShopName, Address, Phone, Email, RegistrationNo, ReceiptHeader,
                                             ReceiptFooter, CurrencySymbol, DefaultLanguage
                                        FROM dbo.ShopProfile WHERE Id = @Id
                                         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @Details NVARCHAR(MAX) = CONCAT(N'{"old":', @Old, N',"new":', @New, N'}');
        EXEC dbo.usp_AuditLog_Add @UserId = @UserId, @Action = N'ShopProfile.Update',
             @EntityName = N'ShopProfile', @EntityId = @Id, @Details = @Details;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- Naya logo path set karta hai aur purana path wapas deta hai (taake C# purani file mita sake)
CREATE OR ALTER PROCEDURE dbo.usp_ShopProfile_SetLogo
    @LogoPath NVARCHAR(250) = NULL,
    @UserId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Id INT = (SELECT TOP (1) Id FROM dbo.ShopProfile ORDER BY Id);

    UPDATE dbo.ShopProfile
       SET LogoPath   = @LogoPath,
           ModifiedAt = dbo.fn_PktNow(),
           ModifiedBy = @UserId
    OUTPUT deleted.LogoPath AS OldLogoPath
     WHERE Id = @Id;

    EXEC dbo.usp_AuditLog_Add @UserId = @UserId, @Action = N'ShopProfile.Logo',
         @EntityName = N'ShopProfile', @EntityId = @Id, @Details = @LogoPath;
END
GO
