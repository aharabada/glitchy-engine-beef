Texture2D Colors : register(t0);
Texture2D<float3> Normals : register(t1);
Texture2D Positions : register(t2);

SamplerState Sampler : register(s0);

cbuffer Constants
{
    float3 LightDir = float3(0, 1, 0);
}

struct VS_IN
{
    float2 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
    output.Position = float4(input.Position, 0, 1);
    output.TexCoord = input.TexCoord;
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    float4 color = Colors.Sample(Sampler, input.TexCoord);
    float3 normal = Normals.Sample(Sampler, input.TexCoord);

    //float shading = dot(LightDir, normal) + 100;
    float shading = dot(float3(0, 1, 0), normal);
    shading = clamp(shading, 0.0f, 1.0f);

    return float4(color.rgb * shading, 1);
}

#effect[VS=VS,PS=PS]
