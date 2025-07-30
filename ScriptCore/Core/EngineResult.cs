using System;
using System.Runtime.CompilerServices;
using System.Security.Cryptography.X509Certificates;

namespace GlitchyEngine.Core;

[EngineClass("GlitchyEngine.Scripting.ScriptGlue.EngineResult")]
internal enum EngineResult
{
    Ok = 0, // Success, can mean True
    False = 1, // Success, can mean False
    Error = -1,
    NotImplemented = -2,
    ArgumentError = -3,

    // Entity Errors:
    EntityNotFound = -4, // The entity doesn't exist or was deleted.
    EntityDoesntHaveComponent = -5, // The entity has no component of type {typeof(T)} or it was deleted.
    AssetNotFound = -6, // No asset exists for AssetHandle \"{assetId}\".
    CustomError = 1 << 31
}

public class EngineException(string message) : Exception(message);

public class EntityNotFoundException(string? message = null) : Exception(message);

public class ComponentNotFoundException(string? message = null) : Exception(message);

public class AssetNotFoundException(string? message = null) : Exception(message);

internal static class EngineErrors
{
    public static void ThrowIfError(EngineResult result, [CallerMemberName]string callerName = "")
    {
        if (result >= 0)
            return;

        string engineMessage = ScriptGlue.GetLastExceptionMessage();

        switch (result)
        {
            case EngineResult.Error:
                throw new EngineException(engineMessage ?? $"Unspecified engine excepiton in {callerName}");
            case EngineResult.NotImplemented:
                throw new NotImplementedException(engineMessage ?? $"Function {callerName} is not implemented in the engine.");
            case EngineResult.ArgumentError:
                throw new ArgumentException(engineMessage ?? $"An argument passed to {callerName} is invalid.");
            case EngineResult.EntityNotFound:
                throw new EntityNotFoundException(engineMessage);
            case EngineResult.EntityDoesntHaveComponent:
                throw new ComponentNotFoundException(engineMessage);
            case EngineResult.AssetNotFound:
                throw new AssetNotFoundException(engineMessage);
            default:
                throw new EngineException(engineMessage ?? $"Unknown engine excepiton in {callerName}");
        }
    }
}
