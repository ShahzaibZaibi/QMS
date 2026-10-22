CREATE TABLE dbo.PaymentMethods (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentMethods PRIMARY KEY,
    Name        NVARCHAR(50)  NOT NULL,
    [Type]      NVARCHAR(10)  NOT NULL CONSTRAINT CK_PaymentMethods_Type CHECK ([Type] IN (N'Cash', N'Bank', N'Wallet')),
    IsActive    BIT           NOT NULL CONSTRAINT DF_PaymentMethods_IsActive  DEFAULT (1),
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_PaymentMethods_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy   INT           NULL,
    ModifiedAt  DATETIME2(0)  NULL,
    ModifiedBy  INT           NULL,
    CONSTRAINT UQ_PaymentMethods_Name UNIQUE (Name)
);
GO

-- Receipt/Sale/... numbers (branch + saal ke hisaab se). usp_Number_Next lock ke saath barhata hai.
CREATE TABLE dbo.NumberSequences (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_NumberSequences PRIMARY KEY,
    BranchId    INT           NOT NULL CONSTRAINT FK_NumberSequences_Branches REFERENCES dbo.Branches (Id),
    SeqType     NVARCHAR(20)  NOT NULL CONSTRAINT CK_NumberSequences_SeqType CHECK (SeqType IN
                    (N'Receipt', N'Sale', N'Contract', N'Purchase', N'Return', N'SupplierPayment', N'PurchaseReturn')),
    Prefix      NVARCHAR(30)  NOT NULL,
    [Year]      INT           NOT NULL,
    LastNumber  INT           NOT NULL CONSTRAINT DF_NumberSequences_LastNumber DEFAULT (0),
    Padding     TINYINT       NOT NULL CONSTRAINT DF_NumberSequences_Padding    DEFAULT (6),
    CONSTRAINT UQ_NumberSequences UNIQUE (BranchId, SeqType, [Year])
);
GO

-- Sirf ek row (Id = 1). Naam, logo, receipt ki tafseel yahin se aati hai, code mein kuch fixed nahi.
CREATE TABLE dbo.ShopProfile (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ShopProfile PRIMARY KEY,
    ShopName        NVARCHAR(100) NOT NULL,
    LogoPath        NVARCHAR(250) NULL,
    Address         NVARCHAR(250) NULL,
    Phone           NVARCHAR(30)  NULL,
    Email           NVARCHAR(100) NULL,
    RegistrationNo  NVARCHAR(50)  NULL,
    ReceiptHeader   NVARCHAR(250) NULL,
    ReceiptFooter   NVARCHAR(250) NULL,
    CurrencySymbol  NVARCHAR(10)  NOT NULL CONSTRAINT DF_ShopProfile_Currency DEFAULT (N'Rs'),
    DefaultLanguage NVARCHAR(10)  NOT NULL CONSTRAINT DF_ShopProfile_Language DEFAULT (N'RomanUrdu'),
    CreatedAt       DATETIME2(0)  NOT NULL CONSTRAINT DF_ShopProfile_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy       INT           NULL,
    ModifiedAt      DATETIME2(0)  NULL,
    ModifiedBy      INT           NULL,
    CONSTRAINT CK_ShopProfile_SingleRow CHECK (Id = 1),
    CONSTRAINT CK_ShopProfile_Language  CHECK (DefaultLanguage IN (N'RomanUrdu', N'English'))
);
GO

CREATE TABLE dbo.Settings (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Settings PRIMARY KEY,
    [Key]       NVARCHAR(60)  NOT NULL,
    [Value]     NVARCHAR(500) NULL,
    ModifiedAt  DATETIME2(0)  NULL,
    ModifiedBy  INT           NULL,
    CONSTRAINT UQ_Settings_Key UNIQUE ([Key])
);
GO

-- Sirf-jama: is table mein update/delete kabhi nahi
CREATE TABLE dbo.AuditLog (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLog PRIMARY KEY,
    UserId      INT           NULL,
    Action      NVARCHAR(50)  NOT NULL,
    EntityName  NVARCHAR(60)  NOT NULL,
    EntityId    INT           NULL,
    Details     NVARCHAR(MAX) NULL,
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_AuditLog_CreatedAt DEFAULT (dbo.fn_PktNow())
);
GO

CREATE INDEX IX_AuditLog_Entity    ON dbo.AuditLog (EntityName, EntityId);
CREATE INDEX IX_AuditLog_CreatedAt ON dbo.AuditLog (CreatedAt);
GO

-- RequestKey ek random text hai (GUID column nahi); double-submit se bachao
CREATE TABLE dbo.IdempotencyKeys (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_IdempotencyKeys PRIMARY KEY,
    RequestKey  NVARCHAR(64)  NOT NULL,
    Endpoint    NVARCHAR(100) NOT NULL,
    UserId      INT           NULL,
    ResultRef   NVARCHAR(200) NULL,
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_IdempotencyKeys_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CONSTRAINT UQ_IdempotencyKeys UNIQUE (RequestKey, Endpoint)
);
GO
