using Microsoft.AspNetCore.Identity;
using QMS.Models;
using QMS.Models.DTOs;
using QMS.Repositories;
using QMS.Security;

namespace QMS.Services;

public sealed class AuthService : IAuthService
{
    private readonly ISpExecutor _db;
    private readonly ITokenService _tokens;
    private readonly IPasswordHasher<AppUser> _hasher;
    private readonly JwtSettings _jwt;

    public AuthService(ISpExecutor db, ITokenService tokens, IPasswordHasher<AppUser> hasher, JwtSettings jwt)
    {
        _db = db;
        _tokens = tokens;
        _hasher = hasher;
        _jwt = jwt;
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var loaded = await LoadUserAsync("usp_Auth_Login", new { Username = request.Username.Trim() }, ct);
        if (loaded is null || !loaded.Row.IsActive) return null;

        var check = _hasher.VerifyHashedPassword(new AppUser(), loaded.Row.PasswordHash, request.Password);
        if (check == PasswordVerificationResult.Failed) return null;

        var refreshToken = _tokens.CreateRefreshToken();
        await _db.ExecuteAsync("usp_RefreshToken_Create",
            new { UserId = loaded.Row.Id, TokenHash = _tokens.Hash(refreshToken), ValidHours = _jwt.RefreshTokenHours }, ct);

        return BuildResponse(loaded.User, refreshToken);
    }

    public async Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken ct = default)
    {
        var newToken = _tokens.CreateRefreshToken();
        var userId = await _db.QueryFirstOrDefaultAsync<int?>("usp_RefreshToken_Rotate",
            new { OldHash = _tokens.Hash(refreshToken), NewHash = _tokens.Hash(newToken), ValidHours = _jwt.RefreshTokenHours }, ct);
        if (userId is null) return null;

        // Permissions dobara DB se: role badla ho to naya access token mein naye ikhtiyarat aate hain
        var loaded = await LoadUserAsync("usp_Auth_GetUser", new { UserId = userId.Value }, ct);
        if (loaded is null || !loaded.Row.IsActive) return null;

        return BuildResponse(loaded.User, newToken);
    }

    public Task LogoutAsync(string refreshToken, CancellationToken ct = default) =>
        _db.ExecuteAsync("usp_RefreshToken_Revoke", new { TokenHash = _tokens.Hash(refreshToken) }, ct);

    private AuthResponse BuildResponse(AuthUser user, string refreshToken)
    {
        var (token, expires) = _tokens.CreateAccessToken(user);
        return new AuthResponse(token, expires, refreshToken, user);
    }

    private sealed record LoadedUser(UserRow Row, AuthUser User);

    private Task<LoadedUser?> LoadUserAsync(string procedure, object parameters, CancellationToken ct) =>
        _db.QueryMultipleAsync<LoadedUser?>(procedure, parameters, async grid =>
        {
            var row = await grid.ReadFirstOrDefaultAsync<UserRow>();
            var roles = (await grid.ReadAsync<string>()).ToList();
            var permissions = (await grid.ReadAsync<string>()).ToList();
            return row is null
                ? null
                : new LoadedUser(row, new AuthUser(row.Id, row.Username, row.FullName, row.BranchId, roles, permissions));
        }, ct);
}
