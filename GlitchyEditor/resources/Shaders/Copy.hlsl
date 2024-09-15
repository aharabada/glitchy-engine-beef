Texture2D Texture : register(t0);
SamplerState TextureSampler : register(s0);

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
	return Texture.Sample(TextureSampler, input.TexCoord);
}

#pragma Effect[VS = VS; PS = PS]
