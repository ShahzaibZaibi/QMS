using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using QMS.Services;

namespace QMS.Security;

/// <summary>
/// Har request par cookie ke user ko dekhta hai: user band ho gaya ho to session khatam,
/// warna taza roles/permissions principal mein laga deta hai (DB result 20 second cache hota hai).
/// </summary>
public static class SessionValidator
{
    public static async Task ValidateAsync(CookieValidatePrincipalContext context)
    {
        if (!int.TryParse(context.Principal?.FindFirst(ClaimNames.UserId)?.Value, out var userId))
        {
            await Reject(context);
            return;
        }

        var auth = context.HttpContext.RequestServices.GetRequiredService<IAuthService>();
        var user = await auth.GetActiveUserAsync(userId, context.HttpContext.RequestAborted);
        if (user is null)
        {
            await Reject(context);
            return;
        }

        context.ReplacePrincipal(PrincipalFactory.Full(user));
    }

    private static async Task Reject(CookieValidatePrincipalContext context)
    {
        context.RejectPrincipal();
        await context.HttpContext.SignOutAsync(PrincipalFactory.Scheme);
    }
}
