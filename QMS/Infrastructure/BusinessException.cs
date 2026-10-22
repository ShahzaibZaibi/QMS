namespace QMS.Infrastructure;

/// <summary>Aisi ghalti jo user ko saaf message ke saath dikhani hai (HTTP 400).</summary>
public sealed class BusinessException : Exception
{
    public BusinessException(string message) : base(message) { }
}
