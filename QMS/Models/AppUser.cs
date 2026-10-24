namespace QMS.Models;

/// <summary>PasswordHasher&lt;T&gt; ko ek type chahiye hota hai; default hasher is object ko istemal nahi karta.</summary>
public sealed class AppUser { }

/// <summary>usp_Auth_GetUser ka pehla result set (PasswordHash kabhi client ko nahi jata).</summary>
public sealed class UserRow
{
    public int Id { get; set; }
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string FullName { get; set; } = "";
    public int BranchId { get; set; }
    public bool IsActive { get; set; }
}
