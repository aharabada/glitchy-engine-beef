// GlitchyEngineHelper.cpp : Defines the entry point for the application.
//

#include "GlitchyEngineHelper.h"

using namespace std;

GE_EXPORT int GE_CALLTYPE test(int x, int y)
{
	return x + y;
}

GE_EXPORT XXH64_hash_t bla(void* buffer, size_t size, XXH64_hash_t seed)
{
	return XXH64(buffer, size, seed);
}

// Standard version
GE_EXPORT HRESULT GE_CALLTYPE DirectXTK_CreateDDSTextureFromMemory(
    _In_ ID3D11Device* d3dDevice,
    _In_reads_bytes_(ddsDataSize) const uint8_t* ddsData,
    _In_ size_t ddsDataSize,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _In_ size_t maxsize,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromMemory(d3dDevice, ddsData, ddsDataSize, texture, textureView, maxsize, alphaMode);
}

GE_EXPORT HRESULT GE_CALLTYPE DirectXTK_CreateDDSTextureFromFile(
    _In_ ID3D11Device* d3dDevice,
    _In_z_ const wchar_t* szFileName,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _In_ size_t maxsize,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromFile(d3dDevice, szFileName, texture, textureView, maxsize, alphaMode);
}

// Standard version with optional auto-gen mipmap support
GE_EXPORT HRESULT GE_CALLTYPE DirectXTK_CreateDDSTextureFromMemoryMip(
#if defined(_XBOX_ONE) && defined(_TITLE)
    _In_ ID3D11DeviceX* d3dDevice,
    _In_opt_ ID3D11DeviceContextX* d3dContext,
#else
    _In_ ID3D11Device* d3dDevice,
    _In_opt_ ID3D11DeviceContext* d3dContext,
#endif
    _In_reads_bytes_(ddsDataSize) const uint8_t* ddsData,
    _In_ size_t ddsDataSize,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _In_ size_t maxsize,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromMemory(d3dDevice, d3dContext, ddsData, ddsDataSize, texture, textureView, maxsize, alphaMode);
}

GE_EXPORT HRESULT GE_CALLTYPE DirectXTK_CreateDDSTextureFromFileMip(
#if defined(_XBOX_ONE) && defined(_TITLE)
    _In_ ID3D11DeviceX* d3dDevice,
    _In_opt_ ID3D11DeviceContextX* d3dContext,
#else
    _In_ ID3D11Device* d3dDevice,
    _In_opt_ ID3D11DeviceContext* d3dContext,
#endif
    _In_z_ const wchar_t* szFileName,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _In_ size_t maxsize,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromFile(d3dDevice, d3dContext, szFileName, texture, textureView, maxsize, alphaMode);
}

// Extended version
HRESULT __cdecl DirectXTK_CreateDDSTextureFromMemoryEx(
    _In_ ID3D11Device* d3dDevice,
    _In_reads_bytes_(ddsDataSize) const uint8_t* ddsData,
    _In_ size_t ddsDataSize,
    _In_ size_t maxsize,
    _In_ D3D11_USAGE usage,
    _In_ unsigned int bindFlags,
    _In_ unsigned int cpuAccessFlags,
    _In_ unsigned int miscFlags,
    _In_ bool forceSRGB,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromMemoryEx(d3dDevice, ddsData, ddsDataSize, maxsize, usage, bindFlags, cpuAccessFlags, miscFlags, forceSRGB, texture, textureView, alphaMode);
}

HRESULT __cdecl DirectXTK_CreateDDSTextureFromFileEx(
    _In_ ID3D11Device* d3dDevice,
    _In_z_ const wchar_t* szFileName,
    _In_ size_t maxsize,
    _In_ D3D11_USAGE usage,
    _In_ unsigned int bindFlags,
    _In_ unsigned int cpuAccessFlags,
    _In_ unsigned int miscFlags,
    _In_ bool forceSRGB,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromFileEx(d3dDevice, szFileName, maxsize, usage, bindFlags, cpuAccessFlags, miscFlags, forceSRGB, texture, textureView, alphaMode);
}

// Extended version with optional auto-gen mipmap support
HRESULT __cdecl DirectXTK_CreateDDSTextureFromMemoryExMip(
#if defined(_XBOX_ONE) && defined(_TITLE)
    _In_ ID3D11DeviceX* d3dDevice,
    _In_opt_ ID3D11DeviceContextX* d3dContext,
#else
    _In_ ID3D11Device* d3dDevice,
    _In_opt_ ID3D11DeviceContext* d3dContext,
#endif
    _In_reads_bytes_(ddsDataSize) const uint8_t* ddsData,
    _In_ size_t ddsDataSize,
    _In_ size_t maxsize,
    _In_ D3D11_USAGE usage,
    _In_ unsigned int bindFlags,
    _In_ unsigned int cpuAccessFlags,
    _In_ unsigned int miscFlags,
    _In_ bool forceSRGB,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromMemoryEx(d3dDevice, d3dContext, ddsData, ddsDataSize, maxsize, usage, bindFlags, cpuAccessFlags, miscFlags, forceSRGB, texture, textureView, alphaMode);
}

HRESULT __cdecl DirectXTK_CreateDDSTextureFromFileExMip(
#if defined(_XBOX_ONE) && defined(_TITLE)
    _In_ ID3D11DeviceX* d3dDevice,
    _In_opt_ ID3D11DeviceContextX* d3dContext,
#else
    _In_ ID3D11Device* d3dDevice,
    _In_opt_ ID3D11DeviceContext* d3dContext,
#endif
    _In_z_ const wchar_t* szFileName,
    _In_ size_t maxsize,
    _In_ D3D11_USAGE usage,
    _In_ unsigned int bindFlags,
    _In_ unsigned int cpuAccessFlags,
    _In_ unsigned int miscFlags,
    _In_ bool forceSRGB,
    _Outptr_opt_ ID3D11Resource** texture,
    _Outptr_opt_ ID3D11ShaderResourceView** textureView,
    _Out_opt_ DirectX::DDS_ALPHA_MODE* alphaMode) noexcept
{
    return DirectX::CreateDDSTextureFromFileEx(d3dDevice, d3dContext, szFileName, maxsize, usage, bindFlags, cpuAccessFlags, miscFlags, forceSRGB, texture, textureView, alphaMode);
}
