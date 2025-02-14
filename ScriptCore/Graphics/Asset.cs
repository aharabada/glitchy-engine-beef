using GlitchyEngine.Core;

namespace GlitchyEngine.Graphics;

/// <summary>
/// The base class for all assets.
/// </summary>
public class Asset : EngineObject
{
    /// <summary>
    /// Gets or sets the Identifier of the asset.
    /// </summary>
    public string Identifier
    {
        get
        {
            ScriptGlue.Asset_GetIdentifier(_uuid, out string identifier);
            return identifier;
        }
        set => ScriptGlue.Asset_SetIdentifier(_uuid, value);
    }
}
