using GlitchyEngine.Renderer;
using GlitchyEngine.Content;
using GlitchyEngine.Math;

namespace GlitchyEngine.World;

using internal GlitchyEngine.World;

class SceneRenderer
{
	public Scene Scene { get; set; }

	private RenderTargetGroup _compositeTarget ~ _.ReleaseRef();
	
	// Temporary target for camera. Needs to change as soon as we support multiple cameras
	private RenderTargetGroup _cameraTarget ~ _.ReleaseRef();

	private uint32 _viewportWidth;
	private uint32 _viewportHeight;

	private AssetHandle _gammaCorrectEffect;

	public RenderTargetGroup CompositeTarget => _compositeTarget;

	public this()
	{
		RenderTargetGroupDescription desc = .(100, 100,
			TargetDescription[](
			RenderTargetFormat.R16G16B16A16_Float,
			.(RenderTargetFormat.R32_UInt) {ClearColor = .UInt(uint32.MaxValue)}),
			RenderTargetFormat.D24_UNorm_S8_UInt);
		_compositeTarget = new RenderTargetGroup(desc);

		_cameraTarget = new RenderTargetGroup(.(){
				Width = 100,
				Height = 100,
				ColorTargetDescriptions = TargetDescription[](
					.(.R16G16B16A16_Float),
					.(.R32_UInt)
				),
				DepthTargetDescription = .(.D24_UNorm_S8_UInt)
			});

		_gammaCorrectEffect = Content.LoadAsset("Shaders/GammaCorrect.hlsl");//Application.Get().EffectLibrary.Load("content/Shaders/GammaCorrect.hlsl");
	}

	/// Sets the size of the viewport into which the scene will be rendered.
	public void OnViewportResize(uint32 width, uint32 height)
	{
		_viewportWidth = width;
		_viewportHeight = height;

		_compositeTarget.Resize(_viewportWidth, _viewportHeight);
		_cameraTarget.Resize(_viewportWidth, _viewportHeight);
	}

	public void RenderRuntime(GameTime gameTime, RenderTargetGroup finalTarget)
	{
		Debug.Profiler.ProfileRendererFunction!();

		// Find camera
		Camera* primaryCamera = null;
		Matrix primaryCameraTransform = default;
		RenderTargetGroup renderTarget = null;

		for (var (entity, transform, camera) in Scene._ecsWorld.Enumerate<TransformComponent, CameraComponent>())
		{
			if (camera.Primary)// && camera.RenderTarget != null)
			{
				primaryCamera = &camera.Camera;
				primaryCameraTransform = transform.WorldTransform;
				// TODO: bind render targets to cameras
				// renderTarget = camera.RenderTarget..AddRef();
			}
		}

		if (primaryCamera == null)
			return;

		finalTarget.AddRef();
		
		renderTarget = _cameraTarget..AddRef();

		// 3D render
		Renderer.BeginScene(*primaryCamera, primaryCameraTransform, renderTarget, _compositeTarget);

		for (var (entity, transform, mesh, meshRenderer) in Scene._ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
		{
			Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
		}

		for (var (entity, transform, light) in Scene._ecsWorld.Enumerate<TransformComponent, LightComponent>())
		{
			Renderer.Submit(light.SceneLight, transform.WorldTransform);
		}

		Renderer.EndScene();

		renderTarget.ReleaseRef();

		// TODO: alphablending (handle in Renderer2D)
		// TODO: 2D-Postprocessing requires rendering into separate target instead of directly into compositeTarget

		RenderCommand.SetRenderTargetGroup(_compositeTarget);
		RenderCommand.BindRenderTargets();

		// Sprite renderer
		Renderer2D.BeginScene(*primaryCamera, primaryCameraTransform, .BackToFront);

		for (var (entity, transform, sprite) in Scene._ecsWorld.Enumerate<TransformComponent, SpriteRendererComponent>())
		{
			Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
		}

		for (var (entity, transform, circle) in Scene._ecsWorld.Enumerate<TransformComponent, CircleRendererComponent>())
		{
			Renderer2D.DrawCircle(transform.WorldTransform, circle, entity.Index);
		}

		Renderer2D.EndScene();

		// Gamma correct composit target and draw it into viewport
		{
			RenderCommand.UnbindRenderTargets();
			RenderCommand.SetRenderTargetGroup(finalTarget, false);
			RenderCommand.BindRenderTargets();

			Effect gammaEffect = Content.GetAsset<Effect>(_gammaCorrectEffect);

			gammaEffect.SetTexture("Texture", _compositeTarget, 0);
			// TODO: iiihhh
			gammaEffect.ApplyChanges();
			gammaEffect.Bind();

			FullscreenQuad.Draw();
		}

		finalTarget.ReleaseRef();
	}

	public void RenderEditor(GameTime gameTime, EditorCamera camera, RenderTargetGroup viewportTarget, delegate void() DebugDraw3D, delegate void() DrawDebug2D)
	{
		Debug.Profiler.ProfileRendererFunction!();

		viewportTarget.AddRef();

		// 3D render
		Renderer.BeginScene(camera, _compositeTarget);

		for (var (entity, transform, mesh, meshRenderer) in Scene._ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
		{
			if (mesh.Mesh == .Invalid || meshRenderer.Material == .Invalid)
				continue;

			Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
		}

		for (var (entity, transform, light) in Scene._ecsWorld.Enumerate<TransformComponent, LightComponent>())
		{
			Renderer.Submit(light.SceneLight, transform.WorldTransform);
		}

		DebugDraw3D();

		Renderer.EndScene();

		// TODO: alphablending (handle in Renderer2D)
		// TODO: 2D-Postprocessing requires rendering into separate target instead of directly into compositeTarget

		RenderCommand.SetRenderTargetGroup(_compositeTarget);
		RenderCommand.BindRenderTargets();

		// Sprite renderer
		Renderer2D.BeginScene(camera, .BackToFront);

		for (var (entity, transform, sprite) in Scene._ecsWorld.Enumerate<TransformComponent, SpriteRendererComponent>())
		{
			Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
		}

		for (var (entity, transform, circle) in Scene._ecsWorld.Enumerate<TransformComponent, CircleRendererComponent>())
		{
			Renderer2D.DrawCircle(transform.WorldTransform, circle, entity.Index);
		}

		Renderer2D.EndScene();

		Renderer2D.BeginScene(camera, .BackToFront);

		DrawDebug2D();

		Renderer2D.EndScene();

		// Gamma correct composit target and draw it into viewport
		{
			RenderCommand.UnbindRenderTargets();
			RenderCommand.SetRenderTargetGroup(viewportTarget, false);
			RenderCommand.BindRenderTargets();
			
			Effect gammaEffect = Content.GetAsset<Effect>(_gammaCorrectEffect);

			gammaEffect.SetTexture("Texture", _compositeTarget, 0);
			// TODO: iiihhh
			gammaEffect.ApplyChanges();
			gammaEffect.Bind();

			FullscreenQuad.Draw();
		}

		viewportTarget.ReleaseRef();
	}
}