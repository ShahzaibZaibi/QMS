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

-- Token khud DB mein nahi, sirf uska SHA-256 hash (64 hex chars)
CREATE TABLE dbo.RefreshTokens (
    Id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshTokens PRIMARY KEY,
    UserId     INT          NOT NULL CONSTRAINT FK_RefreshTokens_Users REFERENCES dbo.Users (Id),
    TokenHash  CHAR(64)     NOT NULL,
    ExpiresAt  DATETIME2(0) NOT NULL,
    RevokedAt  DATETIME2(0) NULL,
    CreatedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT (dbo.fn_PktNow()),
    CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE (TokenHash)
);
GO

CREATE INDEX IX_RefreshTokens_UserId ON dbo.RefreshTokens (UserId);
GO
