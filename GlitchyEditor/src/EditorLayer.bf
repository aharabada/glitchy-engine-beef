using GlitchyEditor.EditWindows;
using GlitchyEngine;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.World;
using ImGui;

namespace GlitchyEditor
{
	class EditorLayer : Layer
	{
		RasterizerState _rasterizerState ~ _?.ReleaseRef();
		RasterizerState _rasterizerStateClockWise ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();
		
		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();
		
		EcsWorld _world = new EcsWorld() ~ delete _;

		Editor _editor = new Editor(_world) ~ delete _;

		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;
			
			InitGraphics();
			InitEcs();
		}

		private void InitGraphics()
		{
			_context = Application.Get().Window.Context..AddRef();
			
			_depthTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);
			
			RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(_context, rsDesc);

			rsDesc.FrontCounterClockwise = false;
			_rasterizerStateClockWise = new RasterizerState(_context, rsDesc);

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(_context, blendDesc);
			_opaqueBlendState = new BlendState(_context, .Default);
		}

		private void InitEcs()
		{
			_world.Register<DebugNameComponent>();
			_world.Register<TransformComponent>();
			_world.Register<ParentComponent>();
			_world.Register<MeshComponent>();
			_world.Register<MeshRendererComponent>();
			_world.Register<SkinnedMeshRendererComponent>();
			_world.Register<CameraComponent>();
			_world.Register<AnimationComponent>();
		}

		public override void Update(GameTime gameTime)
		{
			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			_depthTarget.Clear(1.0f, 0, .Depth);

			_context.SetRenderTarget(null);
			_depthTarget.Bind();
			_context.BindRenderTargets();
			
			_context.SetViewport(_context.SwapChain.BackbufferViewport);
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent event)
		{
			_editor.Update();

			return false;
		}
	}
}
