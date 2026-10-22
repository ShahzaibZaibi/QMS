using System.Security.Claims;

namespace QMS.Security;

public static class ClaimsExtensions
{
    public static int GetUserId(this ClaimsPrincipal user) =>
        int.TryParse(user.FindFirst(ClaimNames.UserId)?.Value, out var id) ? id : 0;

    public static int GetBranchId(this ClaimsPrincipal user) =>
        int.TryParse(user.FindFirst(ClaimNames.Branch)?.Value, out var id) ? id : 0;
}
