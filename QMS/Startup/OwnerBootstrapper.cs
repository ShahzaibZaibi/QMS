using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using QMS.Models;
using QMS.Repositories;

namespace QMS.Startup;

/// <summary>
/// Pehle Owner user ka intezam.
///  - App pehli baar chale (koi user nahi): Owner "owner" ban jata hai. Password Bootstrap:OwnerPassword se, warna
///    app khud ek random password banati hai aur console mein sirf ek baar dikha deti hai.
///  - Password bhool jayein: dotnet run -- --reset-owner-password (naya random password console mein, app band).
/// Password kabhi file ya database script mein nahi likha jata (DB mein sirf hash).
/// </summary>
public sealed class OwnerBootstrapper
{
    // Milte-julte harf (0/O, 1/l/I) nikal diye taake parhna aasan ho
    private const string Alphabet = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";

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

    private string OwnerUsername =>
        string.IsNullOrWhiteSpace(_configuration["Bootstrap:OwnerUsername"]) ? "owner" : _configuration["Bootstrap:OwnerUsername"]!.Trim();

    public async Task RunAsync(CancellationToken ct = default)
    {
        var total = await _db.QueryFirstOrDefaultAsync<int>("usp_User_Count", null, ct);
        if (total > 0) return;

        var fullName = _configuration["Bootstrap:OwnerFullName"];
        var configured = _configuration["Bootstrap:OwnerPassword"];

        if (!string.IsNullOrWhiteSpace(configured) && configured.Length < 8)
        {
            _logger.LogError("Bootstrap:OwnerPassword kam az kam 8 harf ka hona chahiye. Owner nahi banaya gaya.");
            return;
        }

        var generated = string.IsNullOrWhiteSpace(configured);
        var password = generated ? GeneratePassword() : configured!;

        var id = await _db.QueryFirstOrDefaultAsync<int>("usp_Bootstrap_CreateOwner", new
        {
            Username = OwnerUsername,
            PasswordHash = _hasher.HashPassword(new AppUser(), password),
            FullName = string.IsNullOrWhiteSpace(fullName) ? "Owner" : fullName.Trim()
        }, ct);

        if (id <= 0) return;

        if (generated) LogCredentials("PEHLA OWNER USER BAN GAYA", OwnerUsername, password);
        else _logger.LogInformation("Owner user '{Username}' ban gaya (password wohi jo Bootstrap:OwnerPassword mein tha).", OwnerUsername);
    }

    /// <returns>true: password badal diya, false: owner user mila nahi</returns>
    public async Task<bool> ResetOwnerPasswordAsync(CancellationToken ct = default)
    {
        var user = await _db.QueryFirstOrDefaultAsync<UserRow>("usp_Auth_Login", new { Username = OwnerUsername }, ct);
        if (user is null)
        {
            _logger.LogError("User '{Username}' nahi mila. Agar Owner ka username alag hai to Bootstrap:OwnerUsername set karein.", OwnerUsername);
            return false;
        }

        var password = GeneratePassword();
        await _db.ExecuteAsync("usp_User_SetPassword", new
        {
            UserId = user.Id,
            PasswordHash = _hasher.HashPassword(new AppUser(), password),
            ActorUserId = (int?)null
        }, ct);

        LogCredentials("OWNER KA PASSWORD RESET HO GAYA", user.Username, password);
        return true;
    }

    private void LogCredentials(string title, string username, string password) =>
        _logger.LogWarning(
            "\n==============================================\n" +
            " {Title}\n" +
            "   Username : {Username}\n" +
            "   Password : {Password}\n" +
            " Ye password sirf ab dikhaya ja raha hai.\n" +
            " Login ke baad menu se \"Password badlein\" use karein.\n" +
            "==============================================",
            title, username, password);

    private static string GeneratePassword()
    {
        var chars = new char[12];
        for (var i = 0; i < chars.Length; i++) chars[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        return new string(chars);
    }
}
