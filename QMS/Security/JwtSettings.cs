namespace QMS.Security;

public sealed class JwtSettings
{
    public string Issuer { get; set; } = "QMS";
    public string Audience { get; set; } = "QMS";
    public string Key { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 45;
    public int RefreshTokenHours { get; set; } = 10;

    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(Key) || Key.Length < 32)
            throw new InvalidOperationException(
                "Jwt:Key set nahi hai (kam az kam 32 harf). Development mein: " +
                "dotnet user-secrets set \"Jwt:Key\" \"<lamba random text>\" --project QMS");
        if (AccessTokenMinutes is < 5 or > 240) throw new InvalidOperationException("Jwt:AccessTokenMinutes 5 se 240 ke darmiyan ho.");
        if (RefreshTokenHours is < 1 or > 72)   throw new InvalidOperationException("Jwt:RefreshTokenHours 1 se 72 ke darmiyan ho.");
    }
}
