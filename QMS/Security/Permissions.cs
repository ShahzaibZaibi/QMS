namespace QMS.Security;

/// <summary>Seed script (Database/Seed/001_Base_Data.sql) ke permission codes ke saath bilkul mel khane chahiye.</summary>
public static class Permissions
{
    public const string CustomerView = "Customer.View";
    public const string CustomerManage = "Customer.Manage";
    public const string ProductView = "Product.View";
    public const string ProductManage = "Product.Manage";
    public const string SaleView = "Sale.View";
    public const string SaleCreate = "Sale.Create";
    public const string PaymentReceive = "Payment.Receive";
    public const string PaymentReverse = "Payment.Reverse";
    public const string ContractView = "Contract.View";
    public const string ContractSettle = "Contract.Settle";
    public const string ContractCancel = "Contract.Cancel";
    public const string ContractAmend = "Contract.Amend";
    public const string MarkupManage = "Markup.Manage";
    public const string SupplierManage = "Supplier.Manage";
    public const string PurchaseView = "Purchase.View";
    public const string PurchaseCreate = "Purchase.Create";
    public const string StockView = "Stock.View";
    public const string StockAdjust = "Stock.Adjust";
    public const string StockTransfer = "Stock.Transfer";
    public const string ReturnCreate = "Return.Create";
    public const string ExpenseManage = "Expense.Manage";
    public const string ReportView = "Report.View";
    public const string FollowUpManage = "FollowUp.Manage";
    public const string SettingsEdit = "Settings.Edit";
    public const string UserManage = "User.Manage";
    public const string RoleManage = "Role.Manage";
    public const string BranchManage = "Branch.Manage";
    public const string BranchViewAll = "Branch.ViewAll";
}
