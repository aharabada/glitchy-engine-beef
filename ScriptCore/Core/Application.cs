namespace GlitchyEngine.Core;

/// <summary>
/// Contains information about the application runtime and methods to control it.
/// </summary>
public static class Application
{
    /// <summary>
    /// Returns <see langword="true"/> when the application is running in the editor (any mode e.g. edit mode or play mode).
    /// </summary>
    /// <seealso cref="IsPlayer"/>
    /// <seealso cref="IsInEditMode"/>
    /// <seealso cref="IsInPlayMode"/>
    public static bool IsEditor => ScriptGlue.Application_IsEditor();

    /// <summary>
    /// Returns <see langword="true"/> when the application is running in the dedicated player.
    /// </summary>
    /// <seealso cref="IsEditor"/>
    public static bool IsPlayer => ScriptGlue.Application_IsPlayer();

    /// <summary>
    /// Returns <see langword="true"/> when the application is running in the editor and the editor is in edit mode.<br/>
    /// If <see cref="IsEditor"/> is <see langword="false"/> (i.e. the application is not running in the editor), <see cref="IsInEditMode"/> will always be <see langword="false"/>.
    /// </summary>
    /// <seealso cref="IsEditor"/>
    /// <seealso cref="IsInPlayMode"/>
    public static bool IsInEditMode => ScriptGlue.Application_IsInEditMode();

    /// <summary>
    /// Returns <see langword="true"/> when the application is running in the editor (<see cref="IsEditor"/> = <see langword="true"/>) and the editor is in play mode. Or when the application in running in the dedicated player (<see cref="IsPlayer"/> = <see langword="true"/>)<br/>
    /// </summary>
    /// <seealso cref="IsEditor"/>
    /// <seealso cref="IsPlayer"/>
    /// <seealso cref="IsInEditMode"/>
    public static bool IsInPlayMode => ScriptGlue.Application_IsInPlayMode();
}
