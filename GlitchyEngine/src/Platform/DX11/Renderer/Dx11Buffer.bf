#if GE_GRAPHICS_DX11

using System.Diagnostics;
using System;
using DirectX.D3D11;

using internal GlitchyEngine.Renderer;

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension BufferDescription
	{
		public static operator DirectX.D3D11.BufferDescription(Self desc)
		{
			DirectX.D3D11.BufferDescription result;

			result.ByteWidth = desc.Size;
			result.Usage = (.)desc.Usage;

			result.CpuAccessFlags = (.)desc.CPUAccess;

			result.BindFlags = .None;
			if(desc.BindFlags.HasFlag(.Constant))
			{
				result.BindFlags |= .ConstantBuffer;
			}
			if(desc.BindFlags.HasFlag(.Index))
			{
				result.BindFlags |= .IndexBuffer;
			}
			if(desc.BindFlags.HasFlag(.Vertex))
			{
				result.BindFlags |= .VertexBuffer;
			}

			result.MiscFlags = .None;
			result.StructureByteStride = 0;

			return result;
		}
	}

	public extension MapType
	{
		public static explicit operator DirectX.D3D11.MapType(Self mapType)
		{
			return (.)(uint32)mapType;
		}
	}

	public extension Buffer
	{
		// Todo: nativeBuffer contains exactly that!
		internal DirectX.D3D11.BufferDescription nativeDescription;

		internal ID3D11Buffer* nativeBuffer ~ _?.Release();

		private Result<void> InternalCreateBuffer(void* data, uint32 byteLength, uint32 dstByteOffset)
		{
			Debug.Profiler.ProfileResourceFunction!();

			nativeDescription = (.)_description;

			uint8* byteData = (.)data;

			if(dstByteOffset == 0)
			{
				byteData = new uint8[nativeDescription.ByteWidth]*;
				defer:: delete byteData;
				Internal.MemCpy(byteData + dstByteOffset, data, Math.Min(nativeDescription.ByteWidth, byteLength));
			}

			SubresourceData srData = .(byteData, byteLength, 0);
			var result = NativeDevice.CreateBuffer(ref nativeDescription, &srData, &nativeBuffer);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create buffer. Message({(int)result}):{result}");
				return .Err;
			}

			return .Ok;
		}

		protected override Result<void> PlatformSetData(void* data, uint32 byteLength, uint32 dstByteOffset, Renderer.MapType mapType)
		{
			Debug.Profiler.ProfileResourceFunction!();

			if(nativeBuffer == null)
			{
				// We can pass the data while creating the buffer, so we can return here.
				return InternalCreateBuffer(data, byteLength, dstByteOffset);
			}

			Debug.Assert(dstByteOffset + byteLength <= _description.Size, "The destination offset and byte length are too long for the target buffer.");
			
			switch(nativeDescription.Usage)
			{
			case .Default:
				Box dataBox = .(dstByteOffset, 0, 0, dstByteOffset + byteLength, 1, 1);
				using (ContextMonitor.Enter())
				{
					NativeContext.UpdateSubresource(nativeBuffer, 0, &dataBox, data, byteLength, byteLength);
				}
			case .Dynamic:
				Log.EngineLogger.Assert(mapType == .WriteDiscard || mapType == .WriteNoOverwrite, scope $"When writing to dynamic resources the map type must be {nameof(Renderer.MapType.WriteDiscard)} or {nameof(Renderer.MapType.WriteNoOverwrite)}.");
				// Todo: DoNotWaitFlag
				MappedSubresource map = ?;
				using (ContextMonitor.Enter())
				{
					NativeContext.Map(nativeBuffer, 0, (.)mapType, .None, &map);
				}
				Internal.MemCpy(((uint8*)map.Data) + dstByteOffset, data, byteLength);
				
				using (ContextMonitor.Enter())
				{
					NativeContext.Unmap(nativeBuffer, 0);
				}
			case .Immutable:
				Log.EngineLogger.Error("Can't set the data of an immutable resource.");
				return .Err;
			default:
				Log.EngineLogger.Error($"Unknown resource usage: engine={_description.Usage}, native={nativeDescription.Usage}");
				return .Err;
			}

			return .Ok;
		}
	}
}

#endif
