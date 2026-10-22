-- Pehli branch aur warehouse (Owner baad mein Branches page se naam/code badal sakta hai)
INSERT dbo.Branches (Code, Name) VALUES (N'MAIN', N'Main Branch');
GO

INSERT dbo.Warehouses (BranchId, Name, IsDefault)
SELECT Id, N'Main Warehouse', 1 FROM dbo.Branches WHERE Code = N'MAIN';
GO

INSERT dbo.Roles (Name, IsSystem) VALUES (N'Owner', 1), (N'Staff', 0), (N'Accountant', 0);
GO

INSERT dbo.Permissions (Code, Module, Description) VALUES
 (N'Customer.View',    N'Customer',  N'Customers dekhna'),
 (N'Customer.Manage',  N'Customer',  N'Customer add/edit'),
 (N'Product.View',     N'Product',   N'Products dekhna'),
 (N'Product.Manage',   N'Product',   N'Product, brand, category add/edit'),
 (N'Sale.View',        N'Sale',      N'Sales dekhna'),
 (N'Sale.Create',      N'Sale',      N'Naya sale / qist plan'),
 (N'Payment.Receive',  N'Payment',   N'Qist wasool karna'),
 (N'Payment.Reverse',  N'Payment',   N'Payment reverse karna'),
 (N'Contract.View',    N'Contract',  N'Plan ki detail dekhna'),
 (N'Contract.Settle',  N'Contract',  N'Jaldi settlement / chhoot'),
 (N'Contract.Cancel',  N'Contract',  N'Plan cancel karna'),
 (N'Contract.Amend',   N'Contract',  N'Plan mein baad ki tabdeeli'),
 (N'Markup.Manage',    N'Markup',    N'Markup rules ka intezam'),
 (N'Supplier.Manage',  N'Purchase',  N'Suppliers add/edit'),
 (N'Purchase.View',    N'Purchase',  N'Purchases dekhna'),
 (N'Purchase.Create',  N'Purchase',  N'Maal ki kharid'),
 (N'Stock.View',       N'Stock',     N'Stock dekhna'),
 (N'Stock.Adjust',     N'Stock',     N'Stock adjustment'),
 (N'Stock.Transfer',   N'Stock',     N'Branches ke darmiyan stock transfer'),
 (N'Return.Create',    N'Return',    N'Sale ki wapsi'),
 (N'Expense.Manage',   N'Expense',   N'Expenses'),
 (N'Report.View',      N'Report',    N'Reports dekhna'),
 (N'FollowUp.Manage',  N'FollowUp',  N'Wasooli ka rabta / wada'),
 (N'Settings.Edit',    N'Admin',     N'Shop Profile aur Settings badalna'),
 (N'User.Manage',      N'Admin',     N'Users'),
 (N'Role.Manage',      N'Admin',     N'Roles aur permissions'),
 (N'Branch.Manage',    N'Admin',     N'Branches aur warehouses'),
 (N'Branch.ViewAll',   N'Admin',     N'Sab branches ka data dekhna');
GO

-- Owner: sab permissions
INSERT dbo.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id FROM dbo.Roles r CROSS JOIN dbo.Permissions p WHERE r.Name = N'Owner';
GO

-- Staff: customer add, naya plan, qist wasool, receipt
INSERT dbo.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id FROM dbo.Roles r JOIN dbo.Permissions p ON p.Code IN
 (N'Customer.View', N'Customer.Manage', N'Product.View', N'Sale.View', N'Sale.Create',
  N'Payment.Receive', N'Contract.View', N'Stock.View', N'FollowUp.Manage')
WHERE r.Name = N'Staff';
GO

-- Accountant: reports, purchase, stock
INSERT dbo.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id FROM dbo.Roles r JOIN dbo.Permissions p ON p.Code IN
 (N'Customer.View', N'Product.View', N'Sale.View', N'Contract.View', N'Supplier.Manage',
  N'Purchase.View', N'Purchase.Create', N'Stock.View', N'Expense.Manage', N'Report.View', N'Branch.ViewAll')
WHERE r.Name = N'Accountant';
GO

INSERT dbo.PaymentMethods (Name, [Type]) VALUES
 (N'Cash', N'Cash'), (N'Bank Transfer', N'Bank'), (N'JazzCash', N'Wallet'), (N'EasyPaisa', N'Wallet');
GO

-- Placeholder naam: Owner pehli baar Shop Profile se apni dukaan ka naam likhega
INSERT dbo.ShopProfile (ShopName, ReceiptFooter) VALUES (N'My Shop', N'Shukriya, qist waqt par ada karein');
GO

INSERT dbo.Settings ([Key], [Value]) VALUES
 (N'MarkupBase',         N'Balance'),     -- FullPrice | Balance
 (N'RoundTo',            N'100'),         -- 0 / 10 / 50 / 100
 (N'RoundOffset',        N'0'),           -- 0 ya 1
 (N'DefaultFrequency',   N'Monthly'),     -- Weekly | Fortnightly | Monthly | Custom
 (N'DefaultMarkupType',  N'Rule'),
 (N'DefaultMarkupValue', N'0'),
 (N'OtherChargesEnabled',N'0'),
 (N'LateFeeType',        N'None'),        -- None | FixedOnce | PercentOnce | PerDay
 (N'LateFeeValue',       N'0'),
 (N'MaxLateFee',         NULL),
 (N'GraceDays',          N'0'),
 (N'LateFeeFirst',       N'0'),
 (N'AllowNegativeStock', N'0');
GO
