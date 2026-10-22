using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using QMS.Infrastructure;
using QMS.Models;
using QMS.Repositories;
using QMS.Security;
using QMS.Services;
using QMS.Startup;

var builder = WebApplication.CreateBuilder(args);

// ---- Config (secrets code mein nahi: User Secrets / environment variables) ----
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtSettings>() ?? new JwtSettings();
jwt.Validate();
builder.Services.AddSingleton(jwt);

// ---- Layers: Controller -> Service -> Repository (Dapper SP) ----
builder.Services.AddSingleton<ISpExecutor, SpExecutor>();
builder.Services.AddSingleton<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.AddSingleton<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IShopProfileService, ShopProfileService>();
builder.Services.AddTransient<DbMigrator>();
builder.Services.AddTransient<OwnerBootstrapper>();

// ---- Authentication (JWT) + Permission based authorization ----
builder.Services
    .AddAuthentication(Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = ClaimNames.UserName,
            RoleClaimType = ClaimNames.Role
        };
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

// ---- Database scripts + pehla Owner ----
using (var scope = app.Services.CreateScope())
{
    if (app.Configuration.GetValue<bool>("Database:RunMigrations"))
        await scope.ServiceProvider.GetRequiredService<DbMigrator>().RunAsync();

    await scope.ServiceProvider.GetRequiredService<OwnerBootstrapper>().RunAsync();
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
