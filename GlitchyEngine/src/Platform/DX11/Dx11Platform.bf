using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3D11.SDKLayers;

namespace GlitchyEngine.Platform.DX11
{
	static
	{
		/// Gets whether or not the DX11 device is initialized.
		protected internal static bool IsDx11Initialized => NativeDevice != null;
		protected internal static ID3D11Device* NativeDevice;
		protected internal static ID3D11DeviceContext* NativeContext;

		protected internal static ID3D11Debug* DebugDevice;

		internal static void Dx11Init()
		{
			if(!IsDx11Initialized)
			{
				Log.EngineLogger.Trace("Creating D3D11 Device and Context...");
				
				DeviceCreationFlags deviceFlags = .None;
	#if DEBUG
				deviceFlags |= .Debug;
	#endif
	
				FeatureLevel[] levels = scope .(.Level_11_0);
	
				FeatureLevel deviceLevel = ?;
				var deviceResult = D3D11.CreateDevice(null, .Hardware, 0, deviceFlags, levels, &NativeDevice, &deviceLevel, &NativeContext);
				Log.EngineLogger.Assert(deviceResult.Succeeded, scope $"Failed to create D3D11 Device. Message({(int32)deviceResult}): {deviceResult}");
	
	#if DEBUG	
				if(NativeDevice.QueryInterface<ID3D11Debug>(out DebugDevice).Succeeded)
				{
					ID3D11InfoQueue* infoQueue;
					if(NativeDevice.QueryInterface<ID3D11InfoQueue>(out infoQueue).Succeeded)
					{
						infoQueue.SetBreakOnSeverity(.Corruption, true);
						infoQueue.SetBreakOnSeverity(.Error, true);
	
						infoQueue.Release();
					}
				}
	#endif
	
				Log.EngineLogger.Trace($"D3D11 Device and Context created (Feature level: {deviceLevel})");
			}
			else
			{
				// We created a second GraphicsContext (for some reason?) just increment references.
				NativeDevice.AddRef();
				NativeContext.AddRef();
				DebugDevice.AddRef();
			}
		}

		internal static void Dx11Release()
		{
			NativeDevice.Release();
			NativeContext.Release();
			DebugDevice.ReportLiveDeviceObjects(.Detail);
			DebugDevice.Release();
		}
	}
}
