using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using QMS.Models.DTOs;
using QMS.Security;
using QMS.Services;

namespace QMS.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth) => _auth = auth;

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting("login")]
    public async Task<ActionResult<AuthUser>> Login(LoginRequest request, CancellationToken ct)
    {
        var user = await _auth.LoginAsync(request, ct);
        if (user is null) return Unauthorized(new { message = "Username ya password ghalat hai." });

        await HttpContext.SignInAsync(PrincipalFactory.Scheme, PrincipalFactory.Minimal(user.Id));
        return user;
    }

    [HttpPost("change-password")]
    [Authorize]
    [EnableRateLimiting("login")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken ct)
    {
        await _auth.ChangePasswordAsync(User.GetUserId(), request.CurrentPassword, request.NewPassword, ct);
        return NoContent();
    }

    [HttpPost("logout")]
    [AllowAnonymous]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(PrincipalFactory.Scheme);
        return NoContent();
    }

    /// <summary>Login hai to uski tafseel aur permissions, warna 401. Har page isi se menu banata hai.</summary>
    [HttpGet("me")]
    [Authorize]
    public ActionResult<object> Me() => new
    {
        id = User.GetUserId(),
        username = User.FindFirst(ClaimNames.UserName)?.Value,
        fullName = User.FindFirst(ClaimNames.FullName)?.Value,
        branchId = User.GetBranchId(),
        roles = User.FindAll(ClaimNames.Role).Select(c => c.Value),
        permissions = User.FindAll(ClaimNames.Permission).Select(c => c.Value)
    };
}
