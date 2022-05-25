cbuffer Constants : register(b0)
{
    uint ClearValue;
}

float4 VS(float2 input : POSITION) : SV_Position
{
    return float4(input, 0.0f, 1.0f);
}

uint PS(float4 input : SV_Position) : SV_Target0
{
    return ClearValue;
}

#effect[VS = VS, PS = PS]