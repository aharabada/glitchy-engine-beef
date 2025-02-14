using System.Diagnostics.SymbolStore;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// An <see cref="Asset"/> that represents how a surface should be rendered.
/// </summary>
public class Material : Asset
{
    public void SetVariable(string name, float4 value)
    {
        unsafe
        {
            ScriptGlue.Material_SetVariable(_uuid, name, ScriptGlue.ShaderVariableType.Float, 1, 4, 1, &value, sizeof(float4));
        }
    }

    public void ResetVariable(string name)
    {
        ScriptGlue.Material_ResetVariable(_uuid, name);
    }
}
