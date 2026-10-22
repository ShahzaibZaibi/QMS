using QMS.Models.DTOs;

namespace QMS.Services;

public interface IAuthService
{
    /// <returns>null: username/password ghalat ya user band</returns>
    Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken ct = default);

    /// <returns>null: refresh token ghalat/expire/radd</returns>
    Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken ct = default);

    Task LogoutAsync(string refreshToken, CancellationToken ct = default);
}
