using System;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.World;
using ImGuizmo;
using GlitchyEngine.Events;

namespace GlitchyEditor.EditWindows
{
	class GameViewportWindow : EditorWindow
	{
		public const String s_WindowTitle = "Game";

		private float2 _availableViewportSize = .(100, 100);
		private float2 _renderedViewportSize = .(100, 100);
		private bool _viewPortChanged;

		private bool _visible;

		private RenderTargetGroup _renderTarget ~ _?.ReleaseRef();

		public float2 AvailableViewportSize => _availableViewportSize;
		public float2 RenderedViewportSize => _renderedViewportSize;

		// Occurs when the viewport is resized.
		public Event<EventHandler<float2>> ViewportSizeChanged ~ _.Dispose();
		// Occurs when an entity was clicked.
		public Event<EventHandler<uint32>> EntityClicked ~ _.Dispose();

		/// The render target that is shown in the viewport window.
		public RenderTargetGroup RenderTarget
		{
			get => _renderTarget;
			set
			{
				if(_renderTarget == value)
					return;

				SetReference!(_renderTarget, value);
			}
		}

		public bool Visible => _visible;

		public this(Editor editor)
		{
			_editor = editor;
		}

		protected override void InternalShow()
		{
			ImGui.PushStyleVar(.WindowPadding, ImGui.Vec2(1, 1));
			defer ImGui.PopStyleVar();

			if(!ImGui.Begin(s_WindowTitle, &_open, .NoScrollbar | .MenuBar))
			{
				ImGui.End();

				_visible = false;
				return;
			}

			_visible = true;

			let viewportSize = ImGui.GetContentRegionAvail();

			if(ImGui.IsWindowHovered() && Input.IsMouseButtonPressing(.RightButton))
			{
				let currentWindow = ImGui.GetCurrentWindow();
				ImGui.FocusWindow(currentWindow);
			}

			_hasFocus = ImGui.IsWindowFocused();
			
			ShowMenuBar();

			if(_renderTarget != null)
			{
				float2 scalingFactor = CalculateFitScalingFactor(_availableViewportSize, _renderedViewportSize);

				float2 previewResolution = scalingFactor * _renderedViewportSize;

				float2 position = max(0.0f, _availableViewportSize / 2.0f - previewResolution / 2.0f) + (float2)ImGui.GetCursorPos();
				ImGui.SetCursorPos((ImGui.Vec2)position);

				ImGui.Image(_renderTarget.GetViewBinding(0), (ImGui.Vec2)previewResolution);
			}

			ImGui.End();

			SetAvailableViewportSize((float2)viewportSize);
		}

		/// Provides the ImGui Drop target and handles dropped payload.
		private void HandleDropTarget()
		{
			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					StringView path = .((char8*)payload.Data, (int)payload.DataSize);
					_editor.RequestOpenScene(this, path);
				}

				ImGui.EndDragDropTarget();
			}
		}

		private void SetAvailableViewportSize(float2 viewportSize)
		{
			if(any(_availableViewportSize != viewportSize))
			{
				_availableViewportSize = viewportSize;
				
				UpdateCustomResolution();
			}
		}

		private void UpdateCustomResolution()
		{
			float2 newRenderViewport = _renderedViewportSize;

			switch (resolutionMode)
			{
			case .Window:
				newRenderViewport = _availableViewportSize;
			case .CustomAspect:
				float scalingFactor = CalculateFitScalingFactor(_availableViewportSize, _customAspectRatio);
				newRenderViewport = max(ceil(_customAspectRatio * scalingFactor), 16);
			case .CustomResolution:
				newRenderViewport = _customResolution;
			case .SixteenToNine:
			case .FullHd:
				newRenderViewport = .(1920, 1080);
			case .WQHD:
				newRenderViewport = .(2560, 1440);
			case .UltraHd:
				newRenderViewport = .(3840, 2160);
			}

			if (any(newRenderViewport != _renderedViewportSize))
			{
				_viewPortChanged = true;
				_renderedViewportSize = newRenderViewport;
				ViewportSizeChanged.Invoke(this, (float2)_renderedViewportSize);
			}
		}

		private float CalculateFitScalingFactor(float2 outerBox, float2 innerBox)
		{
			float outerAspectRatio = outerBox.X / outerBox.Y;
			float innerAspectRatio = innerBox.X / innerBox.Y;

			float scalingFactor;

			// If our target shape is wider than our viewport shape, we have to fit in x-direction
			// otherwise fit in y-direction
			if (innerAspectRatio > outerAspectRatio)
			{
				scalingFactor = outerBox.X / innerBox.X;
			}
			else
			{
				scalingFactor = outerBox.Y / innerBox.Y;
			}

			return scalingFactor;
		}

		private enum ResolutionMode
		{
			case Window;
			case CustomAspect;
			case CustomResolution;
			case SixteenToNine;
			case FullHd;
			case WQHD;
			case UltraHd;

			public StringView GetPreviewName()
			{
				switch (this)
				{
				case .Window:
					return "Window";
				case .CustomAspect:
					return "Custom Aspect Ratio";
				case .CustomResolution:
					return "Custom Resolution";
				case .SixteenToNine:
					return "16:9";
				case .FullHd:
					return "1080p (Full HD)";
				case .WQHD:
					return "1440p (WQHD)";
				case .UltraHd:
					return "2160p (4k)";
				}
			}
		}

		private float2 _customAspectRatio = .(16, 9);
		private float2 _customResolution = .(-1, -1);

		ResolutionMode resolutionMode = .Window;

		private void ShowMenuBar()
		{
			if (ImGui.BeginMenuBar())
			{
				ImGui.TextUnformatted("Resolution: ");
				if (ImGui.BeginCombo("##resolution", resolutionMode.GetPreviewName().ToScopeCStr!(), .WidthFitPreview))
				{
					for (ResolutionMode mode in Enum.EnumValuesEnumerator<ResolutionMode>())
					{
						if (ImGui.Selectable(mode.GetPreviewName().ToScopeCStr!(), mode == resolutionMode))
						{
							resolutionMode = mode;

							if (mode == .CustomResolution && any(_customResolution == -1))
							{
								_customResolution = _availableViewportSize;
							}

							UpdateCustomResolution();
						}
					}

					ImGui.EndCombo();
				}
				
				float itemWidth = ImGui.CalcTextSize("5.1234").x;
				ImGui.PushItemWidth(itemWidth);

				if (resolutionMode == .CustomAspect)
				{
					if (ImGui.DragFloat("##aspectX", &_customAspectRatio.X, 1, 1.0f, 16384.0f, format: "%.4g"))
					{
						UpdateCustomResolution();
					}
					if (ImGui.DragFloat("##aspectY", &_customAspectRatio.Y, 1, 1.0f, 16384.0f, format: "%.4g"))
					{
						UpdateCustomResolution();
					}
					
					ImGui.TextUnformatted(scope $"({_renderedViewportSize.X}px x {_renderedViewportSize.Y}px)");
				}
				else if (resolutionMode == .CustomResolution)
				{
					int32 resX = (int32)_customResolution.X;
					if (ImGui.DragInt("##resolutionX", &resX, 1, 1))
					{
						_customResolution.X = resX;
						UpdateCustomResolution();

					}
					int32 resY = (int32)_customResolution.Y;
					if (ImGui.DragInt("##resolutionY", &resY, 1, 1))
					{
						_customResolution.Y = resY;
						UpdateCustomResolution();
					}

					int gcd = gcd((int)_customResolution.X, (int)_customResolution.Y);

					ImGui.TextUnformatted(scope $"({_customResolution.X / gcd}:{_customResolution.Y / gcd})");
				}
				else
				{
					ImGui.TextUnformatted(scope $"({_renderedViewportSize.X}px x {_renderedViewportSize.Y}px)");
				}

				ImGui.PopItemWidth();
				
				ImGui.EndMenuBar();
			}
		}
	}
}
