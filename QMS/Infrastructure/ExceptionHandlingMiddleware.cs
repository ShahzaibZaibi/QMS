using Microsoft.Data.SqlClient;

namespace QMS.Infrastructure;

/// <summary>
/// Global error handler. SP ka THROW (error number 50000+) user ko saaf message ke saath 400 banta hai.
/// Baqi har ghalti par user ko generic message, tafseel sirf log mein (stack trace kabhi user ko nahi).
/// </summary>
public sealed class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            // client ne request khud band kar di
        }
        catch (BusinessException ex)
        {
            await WriteAsync(context, StatusCodes.Status400BadRequest, ex.Message);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            await WriteAsync(context, StatusCodes.Status400BadRequest, ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled error: {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteAsync(context, StatusCodes.Status500InternalServerError,
                "Kuch masla aa gaya, dobara koshish karein. Masla barqarar rahe to admin ko batayein.");
        }
    }

    private static async Task WriteAsync(HttpContext context, int status, string message)
    {
        if (context.Response.HasStarted) return;
        context.Response.Clear();
        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new { message });
    }
}
