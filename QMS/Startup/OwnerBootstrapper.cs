using Microsoft.AspNetCore.Identity;
using QMS.Models;
using QMS.Repositories;

namespace QMS.Startup;

/// <summary>
/// Pehli baar (jab koi user nahi) Owner user banata hai. Password config se aata hai (User Secrets / environment),
/// code ya script mein kabhi nahi likha jata. Username: Bootstrap:OwnerUsername, password: Bootstrap:OwnerPassword.
/// </summary>
public sealed class OwnerBootstrapper
{
    private readonly ISpExecutor _db;
    private readonly IPasswordHasher<AppUser> _hasher;
    private readonly IConfiguration _configuration;
    private readonly ILogger<OwnerBootstrapper> _logger;

    public OwnerBootstrapper(ISpExecutor db, IPasswordHasher<AppUser> hasher, IConfiguration configuration, ILogger<OwnerBootstrapper> logger)
    {
        _db = db;
        _hasher = hasher;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task RunAsync(CancellationToken ct = default)
    {
        var total = await _db.QueryFirstOrDefaultAsync<int>("usp_User_Count", null, ct);
        if (total > 0) return;

        var username = _configuration["Bootstrap:OwnerUsername"];
        var fullName = _configuration["Bootstrap:OwnerFullName"];
        var password = _configuration["Bootstrap:OwnerPassword"];

        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password) || password.Length < 8)
        {
            _logger.LogWarning(
                "Abhi koi user nahi hai aur Bootstrap:OwnerPassword set nahi (kam az kam 8 harf). " +
                "Owner banane ke liye: dotnet user-secrets set \"Bootstrap:OwnerPassword\" \"<password>\" --project QMS, phir app dobara chalayein.");
            return;
        }

        var hash = _hasher.HashPassword(new AppUser(), password);
        var id = await _db.QueryFirstOrDefaultAsync<int>("usp_Bootstrap_CreateOwner",
            new { Username = username.Trim(), PasswordHash = hash, FullName = string.IsNullOrWhiteSpace(fullName) ? "Owner" : fullName.Trim() }, ct);

        if (id > 0) _logger.LogInformation("Owner user '{Username}' ban gaya. Login ke baad password badal lein.", username);
    }
}
