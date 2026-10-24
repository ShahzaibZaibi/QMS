using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.Cookies;
using QMS.Models.DTOs;

namespace QMS.Security;

public static class PrincipalFactory
{
    public const string Scheme = CookieAuthenticationDefaults.AuthenticationScheme;

    /// <summary>Cookie mein sirf user ka Id jata hai. Role/permissions har request par DB se taza lagte hain.</summary>
    public static ClaimsPrincipal Minimal(int userId) =>
        new(new ClaimsIdentity(new[] { new Claim(ClaimNames.UserId, userId.ToString()) }, Scheme));

    public static ClaimsPrincipal Full(AuthUser user)
    {
        var claims = new List<Claim>
        {
            new(ClaimNames.UserId, user.Id.ToString()),
            new(ClaimNames.UserName, user.Username),
            new(ClaimNames.FullName, user.FullName),
            new(ClaimNames.Branch, user.BranchId.ToString())
        };
        claims.AddRange(user.Roles.Select(r => new Claim(ClaimNames.Role, r)));
        claims.AddRange(user.Permissions.Select(p => new Claim(ClaimNames.Permission, p)));
        return new ClaimsPrincipal(new ClaimsIdentity(claims, Scheme, ClaimNames.UserName, ClaimNames.Role));
    }
}
