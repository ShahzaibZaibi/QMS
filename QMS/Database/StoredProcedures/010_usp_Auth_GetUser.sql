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
