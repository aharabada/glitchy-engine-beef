#define EDITOR

cbuffer Constants : register(b0)
{
    float4x4 ViewProjection;
};

struct VS_Input
{
    float4 Position : POSITION;
    float4 Color    : COLOR;
#ifdef EDITOR
    uint EntityId   : ENTITYID;
#endif
};

typedef struct PS_Input
{
    float4 Position : SV_Position;
    float4 Color    : COLOR;
#ifdef EDITOR
    nointerpolation uint EntityId : ENTITYID;
#endif
} VS_Output;

VS_Output VS(VS_Input input)
{
    VS_Output output;

    output.Position = mul(ViewProjection, input.Position);
    output.Color = input.Color;

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

struct PS_Output
{
    float4 Color : SV_TARGET0;
#ifdef EDITOR
    uint EntityId : SV_TARGET1;
#endif
};

PS_Output PS(PS_Input input)
{
    PS_Output output;

    output.Color = input.Color;

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

#pragma Effect[VS=VS; PS=PS]