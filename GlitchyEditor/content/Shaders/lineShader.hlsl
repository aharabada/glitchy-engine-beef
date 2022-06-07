cbuffer Constants : register(b0)
{
    float4x4 ViewProjection;
    float4 Color;
};

struct VS_Input
{
    float4 Position : POSITION;
};

struct PS_Input
{
    float4 Position : SV_Position;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(ViewProjection, input.Position);

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    return Color;
}

#pragma Effect[VS=VS; PS=PS]
