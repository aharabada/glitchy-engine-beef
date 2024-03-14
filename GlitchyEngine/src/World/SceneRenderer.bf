using GlitchyEngine.Renderer;
using GlitchyEngine.Content;
using GlitchyEngine.Math;
using System;
using GlitchyEngine.World.Components;
using GlitchyEngine.Renderer.Text;

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

	private AssetHandle<Effect> _gammaCorrectEffect;

	public RenderTargetGroup CompositeTarget => _compositeTarget;

	Font _font ~ _.ReleaseRef();

	FontRenderer.PreparedText _smallLinesInfo;

	public this()
	{
		RenderTargetGroupDescription desc = .(100, 100,
			TargetDescription[](
				.(.R16G16B16A16_Float, ownDebugName: new String("Color")),
				.(.R32_UInt) {ClearColor = .UInt(uint32.MaxValue), DebugName = new String("EntityId")}
			),
			TargetDescription(.D24_UNorm_S8_UInt, clearColor: ClearColor.DepthStencil(0.0f, 0)));
		_compositeTarget = new RenderTargetGroup(desc);
		_compositeTarget.[Friend]Identifier = "Composite Target";

		_cameraTarget = new RenderTargetGroup(.(){
				Width = 100,
				Height = 100,
				ColorTargetDescriptions = TargetDescription[](
					.(.R16G16B16A16_Float, ownDebugName: new String("Color")),
					.(.R32_UInt) {ClearColor = .UInt(uint32.MaxValue), DebugName = new String("EntityId")}
				),
				DepthTargetDescription = .(.D24_UNorm_S8_UInt, clearColor: ClearColor.DepthStencil(0.0f, 0))
			});
		_cameraTarget.[Friend]Identifier = "Camera Target";

		_gammaCorrectEffect = Content.LoadAsset("Resources/Shaders/GammaCorrect.hlsl");

		_font = new Font(@"C:\Windows\Fonts\arial.ttf", 24);
	}

	/// Sets the size of the viewport into which the scene will be rendered.
	public void SetViewportSize(uint32 width, uint32 height)
	{
		if (_viewportWidth == width && _viewportHeight == height)
			return;

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
		
		RenderCommand.Clear(_compositeTarget, .ColorDepth);

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

		for (var (entity, transform, mesh, meshRenderer, editorFlags) in Scene._ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent, EditorFlagsComponent>())
		{
			if (editorFlags.Flags.HasFlag(.HideInScene))
				continue;

			if (mesh.Mesh == .Invalid || meshRenderer.Material == .Invalid)
				continue;

			Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
		}

		for (var (entity, transform, light, editorFlags) in Scene._ecsWorld.Enumerate<TransformComponent, LightComponent, EditorFlagsComponent>())
		{
			if (editorFlags.Flags.HasFlag(.HideInScene))
				continue;

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

		for (var (entity, transform, sprite, editorFlags) in Scene._ecsWorld.Enumerate<TransformComponent, SpriteRendererComponent, EditorFlagsComponent>())
		{
			if (editorFlags.Flags.HasFlag(.HideInScene))
				continue;

			Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
		}

		for (var (entity, transform, circle, editorFlags) in Scene._ecsWorld.Enumerate<TransformComponent, CircleRendererComponent, EditorFlagsComponent>())
		{
			if (editorFlags.Flags.HasFlag(.HideInScene))
				continue;

			Renderer2D.DrawCircle(transform.WorldTransform, circle, entity.Index);
		}
		
		for (var (entity, transform, text, editorFlags) in Scene._ecsWorld.Enumerate<TransformComponent, TextRendererComponent, EditorFlagsComponent>())
		{
			if (editorFlags.Flags.HasFlag(.HideInScene))
				continue;
			
			_smallLinesInfo = FontRenderer.PrepareText(_font, text.Text, 24, .Black);

			FontRenderer.DrawText(_smallLinesInfo, transform.WorldTransform * Matrix.Scaling(1.0f / 24.0f));

			_smallLinesInfo.ReleaseRef();
		}
		
		//FontRenderer.DrawText(_smallLinesInfo, 0, 0);

		Renderer2D.EndScene();

		Renderer2D.BeginScene(camera, .BackToFront);

		DrawDebug2D();

		if (Scene._physicsWorld2D != null)
			Box2D.World.DebugDraw(Scene._physicsWorld2D);

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
