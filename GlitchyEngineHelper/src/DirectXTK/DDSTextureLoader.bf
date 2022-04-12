using DirectX.Common;
using DirectX.D3D11;
using System;
using System.Interop;

namespace DirectXTK
{
	enum DdsAlphaMode : uint32
	{
	    Unknown       = 0,
	    Straight      = 1,
	    Premultiplied = 2,
	    Opaque        = 3,
	    Custom        = 4,
	}

	public static class DDSTextureLoader
	{
		// Standard version
		[LinkName("DirectXTK_CreateDDSTextureFromMemory"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromMemory(
		    ID3D11Device* d3dDevice,
		    uint8* ddsData,
		    c_size ddsDataSize,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    c_size maxsize = 0,
		    DdsAlphaMode* alphaMode = null);
		
		[LinkName("DirectXTK_CreateDDSTextureFromFile"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromFile(
		    ID3D11Device* d3dDevice,
		    c_wchar* szFileName,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    c_size maxsize = 0,
		    DdsAlphaMode* alphaMode = null);

		// Standard version with optional auto-gen mipmap support
		[LinkName("DirectXTK_CreateDDSTextureFromMemoryMip"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromMemory(
		    ID3D11Device* d3dDevice,
		    ID3D11DeviceContext* d3dContext,
		    uint8* ddsData,
		    c_size ddsDataSize,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    c_size maxsize = 0,
		    DdsAlphaMode* alphaMode = null);
		
		[LinkName("DirectXTK_CreateDDSTextureFromFileMip"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromFile(
		    ID3D11Device* d3dDevice,
		    ID3D11DeviceContext* d3dContext,
		    c_wchar* szFileName,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    c_size maxsize = 0,
		    DdsAlphaMode* alphaMode = null);

		// Extended version
		[LinkName("DirectXTK_CreateDDSTextureFromMemoryEx"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromMemoryEx(
		    ID3D11Device* d3dDevice,
		    uint8* ddsData,
		    c_size ddsDataSize,
		    c_size maxsize,
		    Usage usage,
		    BindFlags bindFlags,
		    CpuAccessFlags cpuAccessFlags,
		    ResourceMiscFlags miscFlags,
		    bool forceSRGB,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    DdsAlphaMode* alphaMode = null);
		
		[LinkName("DirectXTK_CreateDDSTextureFromFileEx"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromFileEx(
		    ID3D11Device* d3dDevice,
		    c_wchar* szFileName,
		    c_size maxsize,
		    Usage usage,
		    BindFlags bindFlags,
		    CpuAccessFlags cpuAccessFlags,
		    ResourceMiscFlags miscFlags,
		    bool forceSRGB,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    DdsAlphaMode* alphaMode = null);

		// Extended version with optional auto-gen mipmap support
		[LinkName("DirectXTK_CreateDDSTextureFromMemoryExMip"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromMemoryEx(
		    ID3D11Device* d3dDevice,
		    ID3D11DeviceContext* d3dContext,
		    uint8* ddsData,
		    c_size ddsDataSize,
		    c_size maxsize,
		    Usage usage,
		    BindFlags bindFlags,
		    CpuAccessFlags cpuAccessFlags,
		    ResourceMiscFlags miscFlags,
		    bool forceSRGB,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    DdsAlphaMode* alphaMode = null);
		
		[LinkName("DirectXTK_CreateDDSTextureFromFileExMip"), CallingConvention(.Cdecl)]
		public static extern HResult CreateDDSTextureFromFileEx(
		    ID3D11Device* d3dDevice,
		    ID3D11DeviceContext* d3dContext,
		    c_wchar* szFileName,
		    c_size maxsize,
		    Usage usage,
		    BindFlags bindFlags,
		    CpuAccessFlags cpuAccessFlags,
		    ResourceMiscFlags miscFlags,
		    bool forceSRGB,
		    ID3D11Resource** texture,
		    ID3D11ShaderResourceView** textureView,
		    DdsAlphaMode* alphaMode = null);
	}
}