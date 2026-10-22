using QMS.Infrastructure;
using QMS.Models.DTOs;
using QMS.Repositories;

namespace QMS.Services;

public interface IShopProfileService
{
    Task<ShopProfileDto> GetAsync(CancellationToken ct = default);
    Task<PublicShopProfileDto> GetPublicAsync(CancellationToken ct = default);
    Task<ShopProfileDto> SaveAsync(ShopProfileDto dto, int userId, CancellationToken ct = default);
    Task<string> SaveLogoAsync(IFormFile file, int userId, CancellationToken ct = default);
}

public sealed class ShopProfileService : IShopProfileService
{
    private const long MaxLogoBytes = 1 * 1024 * 1024;
    private static readonly Dictionary<string, string> AllowedTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".png"] = "image/png",
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".webp"] = "image/webp"      // SVG jaan boojh kar nahi: us mein script ho sakti hai
    };

    private readonly ISpExecutor _db;
    private readonly IWebHostEnvironment _env;

    public ShopProfileService(ISpExecutor db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    public async Task<ShopProfileDto> GetAsync(CancellationToken ct = default) =>
        await _db.QueryFirstOrDefaultAsync<ShopProfileDto>("usp_ShopProfile_Get", null, ct)
        ?? throw new BusinessException("Shop Profile nahi mila (seed script chali nahi).");

    public async Task<PublicShopProfileDto> GetPublicAsync(CancellationToken ct = default) =>
        await _db.QueryFirstOrDefaultAsync<PublicShopProfileDto>("usp_ShopProfile_GetPublic", null, ct)
        ?? new PublicShopProfileDto { ShopName = "QMS" };

    public async Task<ShopProfileDto> SaveAsync(ShopProfileDto dto, int userId, CancellationToken ct = default)
    {
        await _db.ExecuteAsync("usp_ShopProfile_Save", new
        {
            dto.ShopName, dto.Address, dto.Phone, dto.Email, dto.RegistrationNo,
            dto.ReceiptHeader, dto.ReceiptFooter, dto.CurrencySymbol, dto.DefaultLanguage, UserId = userId
        }, ct);
        return await GetAsync(ct);
    }

    public async Task<string> SaveLogoAsync(IFormFile file, int userId, CancellationToken ct = default)
    {
        if (file.Length == 0) throw new BusinessException("File khali hai.");
        if (file.Length > MaxLogoBytes) throw new BusinessException("Logo 1 MB se chhota hona chahiye.");

        var extension = Path.GetExtension(file.FileName);
        if (!AllowedTypes.TryGetValue(extension, out var contentType) ||
            !string.Equals(file.ContentType, contentType, StringComparison.OrdinalIgnoreCase))
            throw new BusinessException("Sirf PNG, JPG ya WEBP logo chalega.");

        var folder = Path.Combine(_env.WebRootPath, "uploads");
        Directory.CreateDirectory(folder);

        var fileName = $"logo-{DateTime.UtcNow:yyyyMMddHHmmssfff}{extension.ToLowerInvariant()}";
        await using (var stream = File.Create(Path.Combine(folder, fileName)))
            await file.CopyToAsync(stream, ct);

        var newPath = "/uploads/" + fileName;
        var oldPath = await _db.QueryFirstOrDefaultAsync<string?>("usp_ShopProfile_SetLogo",
            new { LogoPath = newPath, UserId = userId }, ct);

        DeleteOldLogo(folder, oldPath);
        return newPath;
    }

    private static void DeleteOldLogo(string folder, string? oldPath)
    {
        if (string.IsNullOrWhiteSpace(oldPath) || !oldPath.StartsWith("/uploads/logo-", StringComparison.Ordinal)) return;
        try
        {
            var file = Path.Combine(folder, Path.GetFileName(oldPath));   // GetFileName: path traversal se bachao
            if (File.Exists(file)) File.Delete(file);
        }
        catch (IOException) { /* purani file na mitay to koi masla nahi */ }
    }
}
