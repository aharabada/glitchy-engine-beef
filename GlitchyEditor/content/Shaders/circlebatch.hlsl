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
    float InnerRadius   : TEXCOORD2;
};

struct PS_Input
{
    float4 Position     : SV_Position;
    float2 RawPos       : TEXCOORD0;
    float2 Texcoord     : TEXCOORD1;
    float4 Color        : COLOR;
    float InnerRadius   : TEXCOORD2;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(ViewProjection, mul(input.Transform, float4(input.Position, 0.0f, 1.0f)));
    output.Texcoord = input.UVTransform.xy + input.UVTransform.zw * input.Texcoord;
    output.RawPos = input.Position;
    output.Color = input.Color;
    output.InnerRadius = input.InnerRadius;

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    float2 uv = input.RawPos * 2;

    float distance = 1.0f - length(uv);

    // Smoothing edges based on derivative (not sure if RawPos is the best value for this)
    float f = fwidth(input.RawPos.x) + fwidth(input.RawPos.y);

    float amount = smoothstep(0.0f, f, distance);
    amount *= smoothstep(input.InnerRadius + f, input.InnerRadius, distance);

    // Discard invisible pixels
    clip(amount - 0.5f);

    float4 color = Texture.Sample(Sampler, input.Texcoord) * input.Color;
    color.a *= amount;

    return color;
}

#effect[VS=VS, PS=PS]