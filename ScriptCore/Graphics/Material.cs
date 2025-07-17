using System.Diagnostics.SymbolStore;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// An <see cref="Asset"/> that represents how a surface should be rendered.
/// </summary>
public class Material : Asset
{
    [EngineClass("GlitchyEngine.Renderer.ShaderVariableType")]
    internal enum ShaderVariableType : byte
    {
        Bool,
        Float,
        Int,
        UInt
    }

    public void SetVariable(string name, float4 value)
    {
        unsafe
        {
            ScriptGlue.Material_SetVariable(_uuid, name, ShaderVariableType.Float, 1, 4, 1, &value, sizeof(float4));
        }
    }

    public void ResetVariable(string name)
    {
        ScriptGlue.Material_ResetVariable(_uuid, name);
    }

    public void SetTexture(string name, Texture? texture)
    {
        ScriptGlue.Material_SetTexture(_uuid, name, texture?._uuid ?? UUID.Zero);
    }

    public Texture? GetTexture(string name)
    {
        ScriptGlue.Material_GetTexture(_uuid, name, out UUID textureId);

        // TODO: Support different texture types?
        return new Texture
        {
            _uuid = textureId
        };
    }

    public void ResetTexture(string name)
    {
        ScriptGlue.Material_ResetTexture(_uuid, name);
    }
}
