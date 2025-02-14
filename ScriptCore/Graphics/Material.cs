using System.Diagnostics.SymbolStore;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

public class Material : Asset
{
    public void SetVariable(string name, float4 value)
    {
        unsafe
        {
            ScriptGlue.Material_SetVariable(_uuid, name, ScriptGlue.ShaderVariableType.Float, 1, 4, 1, &value, sizeof(float4));
        }
    }
}
