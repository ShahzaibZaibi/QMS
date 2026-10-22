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
