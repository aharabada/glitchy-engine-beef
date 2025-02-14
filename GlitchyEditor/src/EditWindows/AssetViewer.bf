using ImGui;
using System;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
namespace GlitchyEditor.EditWindows;

class AssetViewer : EditorWindow
{
	public const String s_WindowTitle = "Asset Viewer";

	public EditorContentManager _manager;

	private AssetHandle _selectedAsset;

	append TextureViewer _textureViewer = .();

	public this(EditorContentManager contentManager)
	{
		_manager = contentManager;
	}

	protected override void InternalShow()
	{
		if(!ImGui.Begin(s_WindowTitle, &_open, .None))
		{
			ImGui.End();
			return;
		}

		ImGui.PushStyleVar(.CellPadding, .(0, 0));

		bool alt_pressed = ImGui.GetIO().KeyAlt;

		if (ImGui.BeginTable("AssetViewerTable", 2, .BordersInnerV | .Resizable | .Reorderable | .NoPadOuterX))
		{
			if (alt_pressed)
			{
				// Header anzeigen, damit sie neu angeordnet werden können
				ImGui.TableSetupColumn("Assets");
				ImGui.TableSetupColumn("Viewer");
				ImGui.TableHeadersRow();
			}
			
		    ImGui.TableNextRow();
		    ImGui.TableSetColumnIndex(0);

			if (ImGui.BeginChild("Assets"))
				DrawAssetList();

			ImGui.EndChild();
			
			ImGui.TableNextColumn();
			
			if (ImGui.BeginChild("Files"))
				DrawAssetViewer();

			ImGui.EndChild();

			ImGui.EndTable();
		}

		ImGui.PopStyleVar(1);

		ImGui.End();
	}

	void DrawAssetList()
	{
		for (let (handle, asset) in _manager.[Friend]_handleToAsset)
		{
			// TODO: gucken, was der Typ ist

			String name = scope String();

			if (asset.Identifier.IsWhiteSpace)
				name.Append("Unnamed");
			else
				name.Append(asset.Identifier);
			
			name.Append(" (");
			asset.GetType().GetName(name);
			name.Append(") [");
			name.AppendF($"{handle.ID}]");

			name.TrimStart();
			
			ImGui.TreeNodeFlags flags = .Leaf;
			
			if(handle == _selectedAsset)
				flags |= .Selected;

			if (ImGui.TreeNodeEx(name, flags, name))
			{
				if (ImGui.IsItemClicked(.Left))
					_selectedAsset = handle;

				ImGui.TreePop();
			}
		}
	}

	void DrawAssetViewer()
	{
		if (_selectedAsset.IsInvalid)
		{
			ImGui.Text("Select an asset to view it.");
			return;
		}

		Asset asset = _selectedAsset.Get<Asset>();

		/*if (!asset.Complete)
		{
			ImGui.Text("Loading asset...");
			return;
		}*/

		/*switch (asset.GetType())
		{
		case typeof(RenderTargetGroup):
			DrawRenderTargetGroupViewer((RenderTargetGroup)asset);
		case typeof(Texture):
			_textureViewer.ViewTexture((Texture)asset);
			
		}*/

		if (var texture = asset as Texture)
			_textureViewer.ViewTexture(texture);
		if (var texture = asset as RenderTargetGroup)
			_textureViewer.ViewTexture(texture);
	}
}

class TextureViewer
{
	enum BackgroundMode : int32
	{
		White,
		Black,
		Pink,
		Checkerboard,
		CustomColor
	}

	enum SampleMode : int32
	{
		Point,
		Linear
	}

	enum ColorChannelSwizzle : int32
	{
		None,
		R,
		G,
		B,
		A
	}

	AssetHandle<Effect> _effect;
	//AssetHandle<Effect> _renderTargetEffect;
	Material _renderTargetMaterial ~ _.ReleaseRef();

	float _zoom = 1.0f;

	BackgroundMode _backgroundMode = .Checkerboard;
	ColorRGBA _backgroundColor;

	SampleMode _sampleMode = .Linear;

	RenderTargetGroup _targets ~ _?.ReleaseRef();
	/*RenderTarget2D _target ~ _?.ReleaseRef();
	RenderTarget2D _idTarget ~ _?.ReleaseRef();
	// TODO: we don't need depth!
	DepthStencilTarget _depth ~ _?.ReleaseRef();*/

	public this()
	{
		_effect = Content.LoadAsset("Resources/Shaders/textureViewerShader.fx", null, true);
		AssetHandle<Effect> effect = Content.LoadAsset("Resources/Shaders/RenderTargetGroupViewer.fx", null, true);

		_renderTargetMaterial = new Material(effect);

		_targets = new RenderTargetGroup(.(){
			Width = 100,
			Height = 100,
			ColorTargetDescriptions = TargetDescription[](
				.(.R8G8B8A8_UNorm, clearColor: .Color(ColorRGBA.Pink), ownDebugName: new $"Color"),
				.(.R32_UInt, ownDebugName: new $"Enity ID (Unused)")
			),
			DepthTargetDescription = .(.D24_UNorm_S8_UInt, ownDebugName: new $"Depth Stencil")
		});
		_targets.[Friend]Identifier = "Asset Viewer";
	}
	
	float2 _position;

	bool _moving;

	float _colorOffset = 0;
	float _colorScale = 1;
	float _alphaOffset = 0;
	float _alphaScale = 1;
	
	int32 _mipLevel = 0;
	int32 _arraySlice = 0;
	int32 _groupIndex = 0;

	ColorChannelSwizzle _swizzleR = .R;
	ColorChannelSwizzle _swizzleG = .G;
	ColorChannelSwizzle _swizzleB = .B;
	ColorChannelSwizzle _swizzleA = .A;
	
	public void ShowSettings(float width, float height, int maxMips, int arraySize, RenderTargetGroup rtGroup)
	{
		char8*[] items = scope .("White", "Black", "Pink", "Checkerboard", "Custom Color");
		
		if (ImGui.CollapsingHeader("View"))
		{
			ImGui.SliderFloat("Zoom", &_zoom, 0.01f, 100.0f);
			
			float maxDimension = max(width, height);

			ImGui.SliderFloat2("Position", ref *(float[2]*)&_position, 2 * -maxDimension * _zoom, 2 * maxDimension * _zoom);

			ImGui.Separator();

			ImGui.Combo("Background", (.)&_backgroundMode, items.Ptr, (.)items.Count);

			if (_backgroundMode == .CustomColor)
			{
				ImGui.ColorPicker3("Color", ref _backgroundColor);
				_backgroundColor.A = 1.0f;
			}
		}
			
		if (ImGui.CollapsingHeader("Sampling"))
		{
			items = scope .("Point", "Linear");

			ImGui.Combo("Sampler", (.)&_sampleMode, items.Ptr, (.)items.Count);

			ImGui.SliderInt("Mip Level", &_mipLevel, 0, (int32)maxMips);
			ImGui.SliderInt("Array Slice", &_arraySlice, 0, (int32)arraySize);

			ImGui.BeginDisabled(rtGroup == null);

			ImGui.SliderInt("Group Target", &_groupIndex, (rtGroup?.HasDepth == true) ? -1 : 0, (int32)(rtGroup?.ColorTargetCount ?? 1) - 1);

			ImGui.TextUnformatted(scope $"Target name: {(rtGroup?.GetTargetDescription(_groupIndex).DebugName ?? "???")}");

			ImGui.EndDisabled();
		}

		if (ImGui.CollapsingHeader("Color and Transparency"))
		{
			ImGui.TextUnformatted("Channel Swizzle:");

			if (ImGui.BeginTable("ColorAndAlpha", 4))
			{
				ImGui.TableNextRow();
				ImGui.TableSetColumnIndex(0);
				
				ImGui.PushID("Color");

				ImGui.TextUnformatted("Color:");
				ImGui.TableNextColumn();
				ImGui.DragFloat("Offset", &_colorOffset, 0.1f);

				ImGui.TableNextColumn();
				ImGui.DragFloat("Scale", &_colorScale, 0.1f);
				ImGui.TableNextColumn();
				
				if (ImGui.Button("Reset"))
				{
					_colorOffset = 0.0f;
					_colorScale = 1.0f;
				}
				ImGui.SameLine();
				ImGui.BeginDisabled();
				if (ImGui.Button("Auto"))
				{
					Runtime.NotImplemented();
				}
				ImGui.EndDisabled();

				ImGui.PopID();

				ImGui.TableNextRow();
				ImGui.TableSetColumnIndex(0);
				
				ImGui.PushID("Alpha");

				ImGui.TextUnformatted("Alpha:");
				ImGui.TableNextColumn();
				ImGui.DragFloat("Offset", &_alphaOffset, 0.1f);
				ImGui.TableNextColumn();
				ImGui.DragFloat("Scale", &_alphaScale, 0.1f);
				ImGui.TableNextColumn();

				if (ImGui.Button("Reset"))
				{
					_alphaOffset = 0.0f;
					_alphaScale = 1.0f;
				}

				ImGui.PopID();

				ImGui.EndTable();
			}
			
			ImGui.Separator();

			ImGui.TextUnformatted("Channel Swizzle:");

			if (ImGui.BeginTable("SwizzleTable", 9))
			{
			    ImGui.TableNextRow();
			    ImGui.TableSetColumnIndex(0);
	
				SwizzleCombo("R", ref _swizzleR);
				ImGui.TableNextColumn();
				SwizzleCombo("G", ref _swizzleG);
				ImGui.TableNextColumn();
				SwizzleCombo("B", ref _swizzleB);
				ImGui.TableNextColumn();
				SwizzleCombo("A", ref _swizzleA);
	
				ImGui.TableNextColumn();
	
				if (ImGui.Button("Reset swizzle"))
				{
					_swizzleR = .R;
					_swizzleG = .G;
					_swizzleB = .B;
					_swizzleA = .A;
				}
	
				ImGui.EndTable();
			}
		}
	}

	private void SwizzleCombo(StringView text, ref ColorChannelSwizzle swizzle)
	{
		ImGui.TextUnformatted(text);
		
		ImGui.TableNextColumn();
		
		if (ImGui.BeginCombo(scope $"##swizzle{text}", scope $"{swizzle}"))
		{
			if (ImGui.Selectable("R", swizzle == .R))
				swizzle = .R;

			if (ImGui.Selectable("G", swizzle == .G))
				swizzle = .G;

			if (ImGui.Selectable("B", swizzle == .B))
				swizzle = .B;

			if (ImGui.Selectable("A", swizzle == .A))
				swizzle = .A;

			if (ImGui.Selectable("None", swizzle == .None))
				swizzle = .None;

			ImGui.EndCombo();
		}
	}
	
	public void ViewTexture(RenderTargetGroup texture)
	{
		ShowSettings(texture.Width, texture.Height, texture.MipLevels - 1, texture.ArraySize - 1, texture);
		
		if (ImGui.BeginChild("imageChild"))
		{
			UpdateInput();
	
			var viewportSize = ImGui.GetContentRegionAvail();
	
			viewportSize.x = Math.Max(viewportSize.x, 1);
			viewportSize.y = Math.Max(viewportSize.y, 1);

			if (_targets.Width != viewportSize.x || _targets.Height != viewportSize.y)
			{
				_targets.Resize((.)viewportSize.x, (.)viewportSize.y);
			}

			RenderBackground();

			RenderTexture(texture);

			ImGui.Image(_targets.GetViewBinding(0), viewportSize);

			ImGui.EndChild();
		}
	}

	public void ViewTexture(Texture texture)
	{
		ShowSettings(texture.Width, texture.Height, texture.MipLevels - 1, texture.ArraySize - 1, null);
		
		if (ImGui.BeginChild("imageChild"))
		{
			UpdateInput();

			var viewportSize = ImGui.GetContentRegionAvail();

			viewportSize.x = Math.Max(viewportSize.x, 1);
			viewportSize.y = Math.Max(viewportSize.y, 1);

			if (_targets.Width != viewportSize.x || _targets.Height != viewportSize.y)
			{
				_targets.Resize((.)viewportSize.x, (.)viewportSize.y);
			}
			
			RenderBackground();

			RenderTexture(texture);
			
			ImGui.Image(_targets.GetViewBinding(0), viewportSize);

			ImGui.EndChild();
		}
	}

	float lastWheel;

	private void UpdateInput()
	{
		var windowPos = ImGui.GetWindowPos();
		var mousePos = ImGui.GetIO().MousePos;
		float2 mouseInWindow = .(mousePos.x - windowPos.x, mousePos.y - windowPos.y);

		bool windowHovered = ImGui.IsWindowHovered();

		if(windowHovered && Input.IsMouseButtonPressing(.MiddleButton))
		{
			_moving = true;
		}
		else if(Input.IsMouseButtonReleased(.MiddleButton))
		{
			_moving = false;
		}

		if(windowHovered || _moving)
		{
			float mouseWheel = ImGui.GetIO().MouseWheel;

			float delta = mouseWheel - lastWheel;

			if(delta != 0)
			{
				_position -= mouseInWindow;
				_position /= _zoom;

				_zoom *= Math.Pow(1.1f, delta);
				
				_position *= _zoom;
				_position += mouseInWindow;
			}

		}

		if(_moving)
		{
			int2 movement = Input.GetMouseMovement();

			_position.X += movement.X;
			_position.Y += movement.Y;
		}
	}

	OrthographicCamera _camera = new OrthographicCamera() ~ delete _;

	private void RenderBackground()
	{
		Viewport vp = .(0, 0, _targets.Width, _targets.Height);
		RenderCommand.SetViewport(vp);

		RenderCommand.Clear(_targets, .ColorDepth);
		// TODO: don't clear pink!
		//RenderCommand.Clear(_target, .Pink);
		//RenderCommand.Clear(_depth, .Depth, 1.0f, 0);

		//_target.Bind();
		RenderCommand.SetRenderTargetGroup(_targets);
		//RenderCommand.SetRenderTarget(_idTarget, 1);
		//RenderCommand.SetDepthStencilTarget(_depth);
		RenderCommand.BindRenderTargets();

		float2 targetSize = float2(_targets.Width, _targets.Height);

		_camera.Left = 0;
		_camera.Top = 0;
		_camera.Right = targetSize.X;
		_camera.Bottom = -targetSize.Y;
		_camera.NearPlane = -5;
		_camera.FarPlane = 5;
		_camera.Update();

		Renderer2D.BeginScene(_camera);

		switch(_backgroundMode)
		{
		case .Black:
			Renderer2D.DrawQuadPivotCorner(float3(0, 0, 1), targetSize, 0, .Black);
		case .White:
			Renderer2D.DrawQuadPivotCorner(float3(0, 0, 1), targetSize, 0, .White);
		case .Pink:
			Renderer2D.DrawQuadPivotCorner(float3(0, 0, 1), targetSize, 0, .HotPink);
		case .CustomColor:
			Renderer2D.DrawQuadPivotCorner(float3(0, 0, 1), targetSize, 0, _backgroundColor);
		case .Checkerboard:
			float quadSize = 50.0f;

			float2 numQuads = (targetSize / 500f) * 10f;

			for(float x = 0; x < numQuads.X; x++)
			{
				for(float y = 0; y < numQuads.Y; y++)
				{
					Renderer2D.DrawQuadPivotCorner(float3(x * quadSize, -y * quadSize, 1), quadSize.XX, 0, ((x + y) % 2 == 0) ? .White : .Gray);
				}
			}
			break;
		}

		Renderer2D.EndScene();
	}

	private void RenderTexture(Asset textureAsset, float2 textureSize, Format format, int32? groupTargetIndex = null)
	{
		float2 mippedTextureSize = float2((int)textureSize.X >> _mipLevel, (int)textureSize.X >> _mipLevel);

		// Sicherstellen, dass die Auflösung nicht 0 wird
		mippedTextureSize = max(mippedTextureSize, 1);

		//float2 textureSize = float2(viewedTexture.Width, viewedTexture.Height);
		float2 zoomedTextureSize = textureSize * _zoom;

		// TODO: Sampler state for rt group
		//var sampler = viewedTexture.SamplerState;

		/*switch(_sampleMode)
		{
		case .Point:
			viewedTexture.SamplerState = SamplerStateManager.PointClamp;
		case .Linear:
			viewedTexture.SamplerState = SamplerStateManager.LinearClamp;
		}*/

		//Renderer2D.BeginScene(_camera, .SortByTexture, _effect);

		// float3(_position * .(1, -1), 0)
		//RenderCommand.Clear(_depth, .Depth, 1.0f, 0);
		RenderCommand.Clear(_targets, .Depth);

		Matrix matrix = .Translation(float3(_position * .(1, -1), 0)) * .Scaling(float3(zoomedTextureSize, 1));

		// TODO: ViewProjection kommt nicht korrekt an?
		_renderTargetMaterial.SetVariable("WorldViewProjection", _camera.ViewProjection * matrix);
		_renderTargetMaterial.SetVariable("ColorOffset", _colorOffset);
		_renderTargetMaterial.SetVariable("ColorScale", _colorScale);
		_renderTargetMaterial.SetVariable("AlphaOffset", _alphaOffset);
		_renderTargetMaterial.SetVariable("AlphaScale", _alphaScale);
		/*_renderTargetEffect.Variables["WorldViewProjection"].SetData(_camera.ViewProjection * matrix);
		_renderTargetEffect.Variables["ColorOffset"].SetData(_colorOffset);
		_renderTargetEffect.Variables["ColorScale"].SetData(_colorScale);
		_renderTargetEffect.Variables["AlphaOffset"].SetData(_alphaOffset);
		_renderTargetEffect.Variables["AlphaScale"].SetData(_alphaScale);*/

		//_renderTargetEffect.Variables["Texels"].SetData(mippedTextureSize); 
		_renderTargetMaterial.SetVariable("Texels", mippedTextureSize);

		//_renderTargetEffect.Variables["MipLevel"].SetData((float)_mipLevel);  
		_renderTargetMaterial.SetVariable("MipLevel", (float)_mipLevel);

		//_renderTargetEffect.Variables["Swizzle"].SetData(int4((int32)_swizzleR, (int32)_swizzleG, (int32)_swizzleB, (int32)_swizzleA));
		_renderTargetMaterial.SetVariable("Swizzle", int4((int32)_swizzleR, (int32)_swizzleG, (int32)_swizzleB, (int32)_swizzleA));

		int textureSlot = -1;

		if (format.IsInt())
		{
			// Int Texture 
			_renderTargetMaterial.SetVariable("Mode", 1);
			textureSlot = _renderTargetMaterial.Effect.Textures["IntTexture"].PsSlot.Index;
		}
		else if (format.IsUInt())
		{
			// UInt Texture
			_renderTargetMaterial.SetVariable("Mode", 2);
			textureSlot = _renderTargetMaterial.Effect.Textures["UIntTexture"].PsSlot.Index;
		}
		else
		{
			// Float Texture
			_renderTargetMaterial.SetVariable("Mode", 0);
			textureSlot = _renderTargetMaterial.Effect.Textures["Texture"].PsSlot.Index;
		}

		//_renderTargetMaterial.ApplyChanges();
		_renderTargetMaterial.Bind();

		if (let renderTargetGroup = textureAsset as RenderTargetGroup)
		{
			using (let viewBinding = renderTargetGroup.GetViewBinding((.)groupTargetIndex))
			{
				RenderCommand.BindTexture(viewBinding, textureSlot, .Pixel);
			}
		}
		else if (let texture = textureAsset as Texture)
		{
			using (let viewBinding = texture.GetViewBinding())
			{
				RenderCommand.BindTexture(viewBinding, textureSlot, .Pixel);
			}
		}

		Quad.Draw();
	}

	private void RenderTexture(RenderTargetGroup viewedTexture)
	{
		var desc = _groupIndex >= 0 ? viewedTexture.[Friend]_colorTargetDescriptions[_groupIndex] : viewedTexture.[Friend]_depthTargetDescription;

		RenderTexture(viewedTexture, float2(viewedTexture.Width, viewedTexture.Height), (.)desc.Format.GetShaderViewFormat(), _groupIndex);
	}

	private void RenderTexture(Texture viewedTexture)
	{
		RenderTexture(viewedTexture, float2(viewedTexture.Width, viewedTexture.Height), viewedTexture.Format, -1);
	}
}
