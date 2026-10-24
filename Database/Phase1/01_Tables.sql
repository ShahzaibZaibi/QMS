/*
  Marhala 1 - TABLES (aur 2 chhote functions)
  SSMS mein poori script ek saath chalayein (F5). Sab se pehle chalayein.
  Database ka naam QistDB hai; doosra naam chahiye to neeche CREATE DATABASE aur USE dono mein badlein.
  Ye script dobara chal jaye to khud ruk jati hai (tables pehle se hon to kuch nahi badalti).
*/
IF DB_ID(N'QistDB') IS NULL CREATE DATABASE QistDB;
GO
USE QistDB;
GO

IF OBJECT_ID(N'dbo.Branches', N'U') IS NOT NULL
BEGIN
    RAISERROR(N'Marhala 1 ke tables pehle se bane hue hain. Ye script dobara chalane ki zaroorat nahi.', 16, 1);
    SET NOEXEC ON;
END
GO

-- PKT (UTC+5): "aaj" aur "abhi" ka ek hi source. Baqi sab SPs/defaults yehi functions istemal karein.
CREATE OR ALTER FUNCTION dbo.fn_PktNow()
RETURNS DATETIME2(0)
AS
BEGIN
    RETURN CAST(DATEADD(HOUR, 5, SYSUTCDATETIME()) AS DATETIME2(0));
END
GO

CREATE OR ALTER FUNCTION dbo.fn_PktToday()
RETURNS DATE
AS
BEGIN
    RETURN CAST(DATEADD(HOUR, 5, SYSUTCDATETIME()) AS DATE);
END
GO

CREATE TABLE dbo.Branches (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Branches PRIMARY KEY,
    Code        NVARCHAR(10)  NOT NULL,
    Name        NVARCHAR(100) NOT NULL,
    Address     NVARCHAR(250) NULL,
    Phone       NVARCHAR(30)  NULL,
    IsActive    BIT           NOT NULL CONSTRAINT DF_Branches_IsActive  DEFAULT (1),
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_Branches_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy   INT           NULL,
    ModifiedAt  DATETIME2(0)  NULL,
    ModifiedBy  INT           NULL,
    CONSTRAINT UQ_Branches_Code UNIQUE (Code)
);
GO

CREATE TABLE dbo.Warehouses (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Warehouses PRIMARY KEY,
    BranchId    INT           NOT NULL CONSTRAINT FK_Warehouses_Branches REFERENCES dbo.Branches (Id),
    Name        NVARCHAR(100) NOT NULL,
    IsDefault   BIT           NOT NULL CONSTRAINT DF_Warehouses_IsDefault DEFAULT (0),
    IsActive    BIT           NOT NULL CONSTRAINT DF_Warehouses_IsActive  DEFAULT (1),
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_Warehouses_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy   INT           NULL,
    ModifiedAt  DATETIME2(0)  NULL,
    ModifiedBy  INT           NULL,
    CONSTRAINT UQ_Warehouses_Branch_Name UNIQUE (BranchId, Name)
);
GO

-- Har branch ka sirf ek default warehouse
CREATE UNIQUE INDEX UX_Warehouses_OneDefaultPerBranch ON dbo.Warehouses (BranchId) WHERE IsDefault = 1;
GO

CREATE TABLE dbo.Roles (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    Name        NVARCHAR(50)  NOT NULL,
    IsSystem    BIT           NOT NULL CONSTRAINT DF_Roles_IsSystem  DEFAULT (0),  -- system role delete/rename nahi hota
    IsActive    BIT           NOT NULL CONSTRAINT DF_Roles_IsActive  DEFAULT (1),
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy   INT           NULL,
    ModifiedAt  DATETIME2(0)  NULL,
    ModifiedBy  INT           NULL,
    CONSTRAINT UQ_Roles_Name UNIQUE (Name)
);
GO

CREATE TABLE dbo.Permissions (
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Permissions PRIMARY KEY,
    Code        NVARCHAR(60)  NOT NULL,   -- jaise Payment.Reverse
    Module      NVARCHAR(40)  NOT NULL,
    Description NVARCHAR(200) NULL,
    CONSTRAINT UQ_Permissions_Code UNIQUE (Code)
);
GO

CREATE TABLE dbo.RolePermissions (
    Id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RolePermissions PRIMARY KEY,
    RoleId       INT NOT NULL CONSTRAINT FK_RolePermissions_Roles       REFERENCES dbo.Roles (Id),
    PermissionId INT NOT NULL CONSTRAINT FK_RolePermissions_Permissions REFERENCES dbo.Permissions (Id),
    CONSTRAINT UQ_RolePermissions UNIQUE (RoleId, PermissionId)
);
GO

CREATE TABLE dbo.Users (
    Id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    Username     NVARCHAR(50)  NOT NULL,
    PasswordHash NVARCHAR(500) NOT NULL,
    FullName     NVARCHAR(100) NOT NULL,
    BranchId     INT           NOT NULL CONSTRAINT FK_Users_Branches REFERENCES dbo.Branches (Id),
    IsActive     BIT           NOT NULL CONSTRAINT DF_Users_IsActive  DEFAULT (1),
    CreatedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CreatedBy    INT           NULL,
    ModifiedAt   DATETIME2(0)  NULL,
    ModifiedBy   INT           NULL,
    CONSTRAINT UQ_Users_Username UNIQUE (Username)
);
GO

CREATE TABLE dbo.UserRoles (
    Id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserRoles PRIMARY KEY,
    UserId   INT NOT NULL CONSTRAINT FK_UserRoles_Users REFERENCES dbo.Users (Id),
    RoleId   INT NOT NULL CONSTRAINT FK_UserRoles_Roles REFERENCES dbo.Roles (Id),
    CONSTRAINT UQ_UserRoles UNIQUE (UserId, RoleId)
);
GO


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

SET NOEXEC OFF;
GO
