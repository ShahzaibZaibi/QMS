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
