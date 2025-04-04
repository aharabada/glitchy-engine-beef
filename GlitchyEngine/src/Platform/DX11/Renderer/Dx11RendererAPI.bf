#if GE_GRAPHICS_DX11

using GlitchyEngine.Math;
using GlitchyEngine.Platform.DX11;
using System;
using GlitchyEngine.Content;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RendererAPI
	{
		private GraphicsContext _context ~ _?.ReleaseRef();

		private AssetHandle<Effect> _clearUintFx;
		private BlendState _nonblendingState ~ _?.ReleaseRef();

		public GraphicsContext Context
		{
			get => _context;
			set => SetReference!(_context, value);
		}

		public static override API Api => .D3D11;

		public override void Init()
		{
			Debug.Profiler.ProfileFunction!();

			_clearUintFx = Content.LoadAsset("Resources/Shaders/ClearUInt.fx", null, true);
			BlendStateDescription desc =.Default;
			desc.RenderTarget[0].BlendEnable = false;
			_nonblendingState = new BlendState(desc);
		}

		private mixin RtOrBackbuffer(RenderTarget2D renderTarget)
		{
			renderTarget ?? _context.SwapChain.BackBuffer
		}

		public override void Clear(RenderTarget2D renderTarget, ColorRGBA color)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			using (ContextMonitor.Enter())
			{
				NativeContext.ClearRenderTargetView(RtOrBackbuffer!(renderTarget)._nativeRenderTargetView, color);
			}
		}

		public override void Clear(DepthStencilTarget target, ClearOptions clearOptions, float depth, uint8 stencil)
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(target == null)
				return;

			DirectX.D3D11.ClearFlag flags = default;
			
			if(clearOptions.HasFlag(.Depth))
			{
				flags |= .Depth;
			}
			
			if(clearOptions.HasFlag(.Stencil))
			{
				flags |= .Stencil;
			}
			
			using (ContextMonitor.Enter())
			{
				NativeContext.ClearDepthStencilView(target.nativeView, flags, depth, stencil);
			}
		}

		private void ClearRtv(DirectX.D3D11.ID3D11RenderTargetView* rtv, ClearColor clearColor)
		{
			using (ContextMonitor.Enter())
			{
				switch(clearColor)
				{
				case .Color(let color):
					NativeContext.ClearRenderTargetView(rtv, color);
				case .UInt(let value):
	#unwarn
					NativeContext.OutputMerger.SetRenderTargets(1, &rtv, null);
	
					using (BlendState lastBlendState = _currentBlendState..AddRef())
					{
						SetBlendState(_nonblendingState);

						var v = _clearUintFx.Get();

						v.Variables["ClearValue"].SetData(value);
						v.ApplyChanges();
						v.Bind();
		
						FullscreenQuad.Draw();
						
						SetBlendState(lastBlendState);
					}
					
					// Rebind the old render targets
					BindRenderTargets();
				default:
					Runtime.NotImplemented();
				}
			}
		}

		public override void Clear(RenderTargetGroup renderTarget, ClearOptions options, ClearColor? color = null, float? depth = null, uint8? stencil = null)
		{
			if (options.HasFlag(.Color) && renderTarget._renderTargetViews != null)
			{
				for (int i < renderTarget._renderTargetViews.Count)
				{
					ClearRtv(renderTarget._renderTargetViews[i], color ?? renderTarget._colorTargetDescriptions[i].ClearColor);
				}
			}

			if (renderTarget._nativeDepthTargetView != null)
			{
				DirectX.D3D11.ClearFlag flags = default;
	
				if(options.HasFlag(.Depth))
				{
					flags |= .Depth;
				}
	
				if(options.HasFlag(.Stencil))
				{
					flags |= .Stencil;
				}
	
				if (flags != default)
				{
					float clearDepth = 0.0f;
					uint8 clearStencil = 0;

					if (renderTarget._depthTargetDescription.ClearColor case .DepthStencil(let d, let s))
					{
						clearDepth = d;
						clearStencil = s;
					}
					else
					{
						Log.EngineLogger.Error("Clear color of depth stencil target must be of type DepthStencil.");
						Log.EngineLogger.AssertDebug(false);
					}

					clearDepth = depth ?? clearDepth;
					clearStencil = stencil ?? clearStencil;

					using (ContextMonitor.Enter())
					{
						NativeContext.ClearDepthStencilView(renderTarget._nativeDepthTargetView, flags, clearDepth, clearStencil);
					}
				}
			}
		}

		public override void SetRenderTarget(RenderTarget2D renderTarget, int slot, bool setDepthBuffer)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.SetRenderTarget(renderTarget, slot, setDepthBuffer);
		}

		public override void SetRenderTargetGroup(RenderTargetGroup renderTarget, bool setDepthBuffer)
		{
			if (renderTarget._renderTargetViews != null)
			{
				for (int i < renderTarget._renderTargetViews.Count)
				{
					_context.SetNativeRenderTargets(renderTarget._renderTargetViews, 0);
				}
			}

			if (setDepthBuffer)
			{
				_context.SetNativeDepthStencilTarget(renderTarget._nativeDepthTargetView);
			}
		}

		public override void SetDepthStencilTarget(DepthStencilTarget target)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.SetDepthStencilTarget(target);
		}

		public override void UnbindRenderTargets()
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.UnbindRenderTargets();
		}

		public override void BindRenderTargets()
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.BindRenderTargets();
		}

		private RasterizerState _currentRasterizerState ~ _?.ReleaseRef();

		public override void SetRasterizerState(RasterizerState rasterizerState)
		{
			Debug.Profiler.ProfileRendererFunction!();

			SetReference!(_currentRasterizerState, rasterizerState);
			using (ContextMonitor.Enter())
			{
				NativeContext.Rasterizer.SetState(_currentRasterizerState.nativeRasterizerState);
			}
		}

		private BlendState _currentBlendState ~ _?.ReleaseRef();

		public override void SetBlendState(BlendState blendState, ColorRGBA blendFactor)
		{
			Debug.Profiler.ProfileRendererFunction!();

			SetReference!(_currentBlendState, blendState);
			
			using (ContextMonitor.Enter())
			{
				NativeContext.OutputMerger.SetBlendState(_currentBlendState.nativeBlendState, blendFactor);
			}
		}
		
		private DepthStencilState _currentDepthStencilState ~ _?.ReleaseRef();

		public override void SetDepthStencilState(DepthStencilState depthStencilState, uint8 stencilReference)
		{
			Debug.Profiler.ProfileRendererFunction!();

			SetReference!(_currentDepthStencilState, depthStencilState);
			
			using (ContextMonitor.Enter())
			{
				NativeContext.OutputMerger.SetDepthStencilState(_currentDepthStencilState.nativeDepthStencilState, stencilReference);
			}
		}

		public override void DrawIndexed(GeometryBinding geometry)
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(geometry.IsIndexed)
				_context.DrawIndexed(geometry.IndexCount, geometry.IndexByteOffset, 0);
			else
				_context.Draw(geometry.VertexCount, 0);
		}

		public override void DrawIndexedInstanced(GeometryBinding geometry)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.DrawIndexedInstanced(geometry.IndexCount, geometry.InstanceCount, geometry.IndexByteOffset, 0, 0);
		}

		public override void SetViewport(Viewport viewport)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_context.SetViewport(viewport);
		}

		public override void UnbindTextures()
		{
			_context.UnbindTextures();
		}

		public override void BindConstantBuffer(Buffer buffer, int slot, ShaderStage stage)
		{
			_context.BindConstantBuffer(buffer, slot, stage);
		}
		
		public override void BindVertexShader(VertexShader vertexShader)
		{
			_context.BindVertexShader(vertexShader);
		}

		public override void BindPixelShader(PixelShader pixelShader)
		{
			_context.BindPixelShader(pixelShader);
		}
	 
		public override void BindConstantBuffers(BufferCollection bufferCollection, ShaderStage shaderStage)
		{
			_context.BindConstantBuffers(bufferCollection, shaderStage);
		}

		public override void BindTexture(TextureViewBinding textureBinding, int slot, ShaderStage shaderStage)
		{
			_context.BindTexture(textureBinding, slot, shaderStage);
		}
	}
}

#endif
