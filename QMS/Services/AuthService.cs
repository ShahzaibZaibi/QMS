using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Caching.Memory;
using QMS.Models;
using QMS.Models.DTOs;
using QMS.Repositories;

namespace QMS.Services;

public sealed class AuthService : IAuthService
{
    private static readonly TimeSpan CacheFor = TimeSpan.FromSeconds(20);

    private readonly ISpExecutor _db;
    private readonly IPasswordHasher<AppUser> _hasher;
    private readonly IMemoryCache _cache;

    public AuthService(ISpExecutor db, IPasswordHasher<AppUser> hasher, IMemoryCache cache)
    {
        _db = db;
        _hasher = hasher;
        _cache = cache;
    }

    public async Task<AuthUser?> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var loaded = await LoadUserAsync("usp_Auth_Login", new { Username = request.Username.Trim() }, ct);
        if (loaded is null || !loaded.Row.IsActive) return null;

        var check = _hasher.VerifyHashedPassword(new AppUser(), loaded.Row.PasswordHash, request.Password);
        return check == PasswordVerificationResult.Failed ? null : loaded.User;
    }

    public async Task<AuthUser?> GetActiveUserAsync(int userId, CancellationToken ct = default)
    {
        var key = $"authuser:{userId}";
        if (_cache.TryGetValue(key, out AuthUser? cached) && cached is not null) return cached;

        var loaded = await LoadUserAsync("usp_Auth_GetUser", new { UserId = userId }, ct);
        if (loaded is null || !loaded.Row.IsActive) return null;

        _cache.Set(key, loaded.User, CacheFor);
        return loaded.User;
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
