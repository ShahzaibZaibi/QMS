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
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken ct)
    {
        var result = await _auth.LoginAsync(request, ct);
        if (result is null) return Unauthorized(new { message = "Username ya password ghalat hai." });
        return result;
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    [EnableRateLimiting("login")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request, CancellationToken ct)
    {
        var result = await _auth.RefreshAsync(request.RefreshToken, ct);
        if (result is null) return Unauthorized(new { message = "Session khatam ho gaya, dobara login karein." });
        return result;
    }

    [HttpPost("logout")]
    [AllowAnonymous]
    public async Task<IActionResult> Logout(RefreshRequest request, CancellationToken ct)
    {
        await _auth.LogoutAsync(request.RefreshToken, ct);
        return NoContent();
    }

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
