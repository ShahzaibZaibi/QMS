using System.Buffers.Text;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using QMS.Models.DTOs;

namespace QMS.Security;

public interface ITokenService
{
    (string Token, DateTime ExpiresAtUtc) CreateAccessToken(AuthUser user);
    string CreateRefreshToken();
    string Hash(string token);
}

public sealed class TokenService : ITokenService
{
    private readonly JwtSettings _settings;
    private readonly SigningCredentials _credentials;
    private readonly JsonWebTokenHandler _handler = new();

    public TokenService(JwtSettings settings)
    {
        _settings = settings;
        _credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Key)), SecurityAlgorithms.HmacSha256);
    }

    public (string Token, DateTime ExpiresAtUtc) CreateAccessToken(AuthUser user)
    {
        var expires = DateTime.UtcNow.AddMinutes(_settings.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(ClaimNames.UserId, user.Id.ToString()),
            new(ClaimNames.UserName, user.Username),
            new(ClaimNames.FullName, user.FullName),
            new(ClaimNames.Branch, user.BranchId.ToString())
        };
        claims.AddRange(user.Roles.Select(r => new Claim(ClaimNames.Role, r)));
        claims.AddRange(user.Permissions.Select(p => new Claim(ClaimNames.Permission, p)));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _settings.Issuer,
            Audience = _settings.Audience,
            Expires = expires,
            SigningCredentials = _credentials
        };

        return (_handler.CreateToken(descriptor), expires);
    }

    // 48 random bytes => lamba, andaza na lagne wala text (GUID nahi)
    public string CreateRefreshToken() => Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(48));

    // DB mein sirf hash jata hai (CHAR(64) hex)
    public string Hash(string token) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
