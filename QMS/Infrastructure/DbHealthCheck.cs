using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace QMS.Infrastructure;

/// <summary>/health: app chal rahi hai aur database tak pohanch hai.</summary>
public sealed class DbHealthCheck : IHealthCheck
{
    private readonly string _connectionString;

    public DbHealthCheck(IConfiguration configuration) =>
        _connectionString = configuration.GetConnectionString("Default") ?? "";

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(ct);
            await using var command = new SqlCommand("SELECT 1", connection);
            await command.ExecuteScalarAsync(ct);
            return HealthCheckResult.Healthy();
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database se rabta nahi ho raha.", ex);
        }
    }
}
