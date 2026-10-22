using System.ComponentModel.DataAnnotations;

namespace QMS.Models.DTOs;

public sealed class LoginRequest
{
    [Required, MaxLength(50)] public string Username { get; set; } = "";
    [Required, MaxLength(200)] public string Password { get; set; } = "";
}

public sealed class RefreshRequest
{
    [Required] public string RefreshToken { get; set; } = "";
}

public sealed record AuthUser(
    int Id,
    string Username,
    string FullName,
    int BranchId,
    IReadOnlyList<string> Roles,
    IReadOnlyList<string> Permissions);

public sealed record AuthResponse(
    string AccessToken,
    DateTime AccessTokenExpiresAtUtc,
    string RefreshToken,
    AuthUser User);
