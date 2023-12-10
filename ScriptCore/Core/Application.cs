namespace GlitchyEngine.Core;

public class Application
{
    /// <summary>
    /// Returns true when the script is running in edit mode.
    /// </summary>
    /// <seealso cref="IsPlaying"/>
    public bool IsEditor = false;
    /// <summary>
    /// Returns true when the script is running in play mode or in the player.
    /// </summary>
    /// <seealso cref="IsEditor"/>
    public bool IsPlaying = false;
}
