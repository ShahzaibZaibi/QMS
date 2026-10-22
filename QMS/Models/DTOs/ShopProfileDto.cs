using System.ComponentModel.DataAnnotations;

namespace QMS.Models.DTOs;

public sealed class ShopProfileDto
{
    [Required, MaxLength(100)] public string ShopName { get; set; } = "";
    public string? LogoPath { get; set; }              // sirf parhne ke liye; logo alag endpoint se badalta hai
    [MaxLength(250)] public string? Address { get; set; }
    [MaxLength(30)]  public string? Phone { get; set; }
    [MaxLength(100), EmailAddress] public string? Email { get; set; }
    [MaxLength(50)]  public string? RegistrationNo { get; set; }
    [MaxLength(250)] public string? ReceiptHeader { get; set; }
    [MaxLength(250)] public string? ReceiptFooter { get; set; }
    [Required, MaxLength(10)] public string CurrencySymbol { get; set; } = "Rs";
    [Required, RegularExpression("^(RomanUrdu|English)$", ErrorMessage = "Zabaan RomanUrdu ya English honi chahiye.")]
    public string DefaultLanguage { get; set; } = "RomanUrdu";
}

public sealed class PublicShopProfileDto
{
    public string ShopName { get; set; } = "";
    public string? LogoPath { get; set; }
    public string DefaultLanguage { get; set; } = "RomanUrdu";
}
