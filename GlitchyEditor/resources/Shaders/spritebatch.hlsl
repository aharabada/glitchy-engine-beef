#define EDITOR

#include "GlitchyEngine2D.hlsl"
#include "ShaderHelpers.hlsl"

Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

VS_Output VS(VS_Input input)
{
    VS_Output output;

    output.Position = mul(ViewProjection, mul(input.Transform, float4(input.Position, 0.0f, 1.0f)));
    output.Texcoord = TransformTexcoords(input.Texcoord, input.UVTransform);
    output.Color = input.Color;

    // Premultiply Alpha
    output.Color.rgb *= output.Color.a;

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

struct PS_Output
{
    float4 Color : SV_Target0;
#ifdef EDITOR
    uint EntityId : SV_TARGET1;
#endif
};

PS_Output PS(PS_Input input)
{
    PS_Output output;

    output.Color = Texture.Sample(Sampler, input.Texcoord) * input.Color;
    
    clip(output.Color.a - 0.001f);

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

#pragma Effect[VS = VS; PS = PS]
