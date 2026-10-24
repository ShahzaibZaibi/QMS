using QMS.Models.DTOs;

namespace QMS.Services;

public interface IAuthService
{
    /// <returns>null: username/password ghalat ya user band</returns>
    Task<AuthUser?> LoginAsync(LoginRequest request, CancellationToken ct = default);

    /// <returns>null: user nahi mila ya band hai</returns>
    Task<AuthUser?> GetActiveUserAsync(int userId, CancellationToken ct = default);
}
