#define EDITOR

Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Constants : register(b0)
{
    float4x4 ViewProjection;
};

struct VS_Input
{
    float2 Position     : POSITION;
    float2 Texcoord     : TEXCOORD0;
    float4x4 Transform  : TRANSFORM;
    float4 Color        : COLOR;
    float4 UVTransform  : TEXCOORD1;
#ifdef EDITOR
    uint EntityId : ENTITYID;
#endif
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 Texcoord : TEXCOORD;
    float4 Color    : COLOR;
#ifdef EDITOR
    nointerpolation uint EntityId : ENTITYID;
#endif
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(ViewProjection, mul(input.Transform, float4(input.Position, 0.0f, 1.0f)));
    output.Texcoord = input.UVTransform.xy + input.UVTransform.zw * input.Texcoord;
    output.Color = input.Color;

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

#effect[VS=VS, PS=PS]