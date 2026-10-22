using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using QMS.Models.DTOs;
using QMS.Security;
using QMS.Services;

namespace QMS.Controllers;

[ApiController]
[Route("api/shop-profile")]
public sealed class ShopProfileController : ControllerBase
{
    private readonly IShopProfileService _service;

    public ShopProfileController(IShopProfileService service) => _service = service;

    /// <summary>Login page ke liye (bina login): sirf naam, logo, zabaan.</summary>
    [HttpGet("public")]
    [AllowAnonymous]
    public Task<PublicShopProfileDto> GetPublic(CancellationToken ct) => _service.GetPublicAsync(ct);

    [HttpGet]
    [Authorize]
    public Task<ShopProfileDto> Get(CancellationToken ct) => _service.GetAsync(ct);

    [HttpPut]
    [HasPermission(Permissions.SettingsEdit)]
    public Task<ShopProfileDto> Save(ShopProfileDto dto, CancellationToken ct) =>
        _service.SaveAsync(dto, User.GetUserId(), ct);

    [HttpPost("logo")]
    [HasPermission(Permissions.SettingsEdit)]
    [RequestSizeLimit(2 * 1024 * 1024)]
    public async Task<ActionResult<object>> UploadLogo(IFormFile file, CancellationToken ct)
    {
        var path = await _service.SaveLogoAsync(file, User.GetUserId(), ct);
        return new { logoPath = path };
    }
}
