using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using QMS.Infrastructure;
using QMS.Models;
using QMS.Repositories;
using QMS.Security;
using QMS.Services;
using QMS.Startup;

var builder = WebApplication.CreateBuilder(args);

// ---- Layers: Controller -> Service -> Repository (Dapper SP) ----
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<ISpExecutor, SpExecutor>();
builder.Services.AddSingleton<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IShopProfileService, ShopProfileService>();
builder.Services.AddTransient<OwnerBootstrapper>();

// ---- Login: cookie (HttpOnly, SameSite=Strict). Cookie mein sirf user Id; permissions har request par DB se ----
var sessionHours = builder.Configuration.GetValue("Auth:SessionHours", 10);
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "qms.auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Strict;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;   // HTTPS par Secure, LAN ke http par bhi chale
        options.ExpireTimeSpan = TimeSpan.FromHours(sessionHours);
        options.SlidingExpiration = false;                                // ek session = ek kaam ka din
        // API hai: login page par redirect nahi, seedha 401 / 403
        options.Events.OnRedirectToLogin = ctx => { ctx.Response.StatusCode = StatusCodes.Status401Unauthorized; return Task.CompletedTask; };
        options.Events.OnRedirectToAccessDenied = ctx => { ctx.Response.StatusCode = StatusCodes.Status403Forbidden; return Task.CompletedTask; };
        options.Events.OnValidatePrincipal = SessionValidator.ValidateAsync;
    });
builder.Services.AddAuthorization();
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddSingleton<IAuthorizationHandler, PermissionHandler>();

// ---- Login par koshishon ki had: ek IP se 1 minute mein 5 ----
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, ct) =>
        await context.HttpContext.Response.WriteAsJsonAsync(
            new { message = "Bohat zyada koshishein. Ek minute baad dobara try karein." }, ct);
    options.AddPolicy("login", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});

builder.Services.AddControllers();
builder.Services.AddHealthChecks().AddCheck<DbHealthCheck>("database");

var app = builder.Build();

// ---- Pehla Owner (sirf jab koi user nahi). Database scripts aap SSMS mein khud chalate hain. ----
// Password bhool jayein:  dotnet run -- --reset-owner-password
var resetOwner = args.Contains("--reset-owner-password");
using (var scope = app.Services.CreateScope())
{
    try
    {
        var bootstrapper = scope.ServiceProvider.GetRequiredService<OwnerBootstrapper>();
        if (resetOwner)
        {
            await bootstrapper.ResetOwnerPasswordAsync();
            return;   // password badal kar app band, server shuru nahi hota
        }
        await bootstrapper.RunAsync();
    }
    catch (SqlException ex)
    {
        app.Logger.LogError(ex,
            "Database se kaam nahi ho saka. Check karein: connection string sahi hai, aur SSMS mein " +
            "Database/Phase1 ki scripts 01, 02, 03, 04 tarteeb se chal chuki hain.");
        if (resetOwner) return;
    }
}

// ---- Pipeline ----
app.UseMiddleware<ExceptionHandlingMiddleware>();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseHttpsRedirection();
app.UseDefaultFiles();   // / par index.html
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
