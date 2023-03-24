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
	class EditorViewportWindow : EditorWindow
	{
		public const String s_WindowTitle = "Scene";

		private ImGui.Vec2 _oldViewportSize = .(100, 100);
		private bool _viewPortChanged;

		/// True if the cursor wrapped from one side of the viewport to the other last frame.
		private bool _wrappedCursor;

		private RenderTargetGroup _renderTarget ~ _?.ReleaseRef();

		private ImGuizmo.OPERATION _gizmoType = .TRANSLATE;
		private ImGuizmo.MODE _gizmoMode = .LOCAL;
		private float _snap = 0.5f;
		private float _angleSnap = 45.0f;
		private bool _doSnap = false;

		private bool _visible;

		public uint32 SelectedEntityId {get; private set; }
		public bool SelectionChanged { get; private set; }

		public Vector2 ViewportSize => (Vector2)_oldViewportSize;
		// Occurs when the viewport is resized.
		public Event<EventHandler<Vector2>> ViewportSizeChanged ~ _.Dispose();
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

		/// Gets or sets whether the editor functionality (gizmo, picking etc.) is enabled.
		public bool EditorMode { get; set; } = true

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
			
			if (_editor.CurrentCamera.[Friend]BindMouse && _hasFocus)
				WrapMouseInViewport();

			// If we wrapped this frame we weren't hovering because the cursor has to be be out of bounds to wrap
			_editor.CurrentCamera.AllowMove = _hasFocus && (ImGui.IsWindowHovered() || _wrappedCursor);

			if (_hasFocus && !_editor.CurrentCamera.InUse)
			{
				if (Input.IsKeyPressing(.Q))
					_gizmoType = .TRANSLATE;
				if (Input.IsKeyPressing(.W))
					_gizmoType = .ROTATE;
				if (Input.IsKeyPressing(.E))
					_gizmoType = .SCALE;

				if (Input.IsKeyPressing(.G))
					_gizmoMode = .WORLD;
				if (Input.IsKeyPressing(.L))
					_gizmoMode = .LOCAL;
			}
			
			if(_renderTarget != null)
			{
				ImGui.Image(_renderTarget.GetViewBinding(0), viewportSize);
				//ImGui.Image(_editor.CurrentCamera.RenderTarget.GetViewBinding(0), viewportSize);
				//ImGui.Image(_editor.CurrentScene.[Friend]_compositeTarget.GetViewBinding(0), viewportSize);
			}

			HandleDropTarget();

			bool gizmoUsed = DrawImGuizmo(viewportSize);

			MousePicking(viewportSize, gizmoUsed);
	
			ImGui.End();

			if(_oldViewportSize != viewportSize)
			{
				ViewportSizeChanged.Invoke(this, (Vector2)viewportSize);
				_viewPortChanged = true;
				_oldViewportSize = viewportSize;
			}
		}

		/// Provides the ImGui Drop target and handles dropped payload.
		private void HandleDropTarget()
		{
			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					StringView path = .((char8*)payload.Data, (int)payload.DataSize);
					_editor.RequestOpenScene(this, path);
				}

				ImGui.EndDragDropTarget();
			}
		}

		/// Wraps the mouse, so that it always stays in the viewport.
		private void WrapMouseInViewport()
		{
			_wrappedCursor = false;

			let mousePos = (Vector2)ImGui.GetMousePos();
			let winPos = (Vector2)ImGui.GetWindowPos();
			let regionMin = winPos + (Vector2)ImGui.GetWindowContentRegionMin();
			let regionMax = winPos + (Vector2)ImGui.GetWindowContentRegionMax();

			ImGui.DrawRect((.)regionMin, (.)regionMax, .(0, 255, 0));

			Vector2 newMousePos = mousePos;

			if (mousePos.X < regionMin.X + 1)
			{
				newMousePos.X = regionMax.X - 2;
			}
			else if (mousePos.X > regionMax.X - 1)
			{
				newMousePos.X = regionMin.X + 2;
			}
			
			if (mousePos.Y < regionMin.Y + 1)
			{
				newMousePos.Y = regionMax.Y - 100;
			}
			else if (mousePos.Y > regionMax.Y - 1)
			{
				newMousePos.Y = regionMin.Y + 10;
			}

			if (newMousePos != mousePos)
			{
				Input.SetMousePosition((Int2)newMousePos);
				// After wrapping the cursor the the other side, the camera controller must not compare the positions,
				// because the delta doesn't represent the correct movement of the cursor.
				// TODO: can be solved by using direct mouse movement instead of comparing positions
				_editor.CurrentCamera.[Friend]MouseCooldown = 2;
				_wrappedCursor = true;
			}
		}

		/// If the user clicks, the entity beneath the cursor will be selected.
		private void MousePicking(ImGui.Vec2 viewportSize, bool gizmoUsed)
		{
			Vector2 relativeMouse = (Vector2)ImGui.GetMousePos() - (Vector2)ImGui.GetItemRectMin();

			int rtWidth = _editor.EditorSceneRenderer.CompositeTarget.Width;
			int rtHeight = _editor.EditorSceneRenderer.CompositeTarget.Height;

			if (Input.IsMouseButtonPressing(.LeftButton) &&
				ImGui.IsWindowHovered() && !gizmoUsed && !_editor.CurrentCamera.InUse && 
				relativeMouse.X >= 0 && relativeMouse.Y >= 0 &&
				relativeMouse.X < viewportSize.x && relativeMouse.Y < viewportSize.y &&
				relativeMouse.X < rtWidth && relativeMouse.Y < rtHeight)
			{
				uint32 id = uint32.MaxValue;

				_editor.EditorSceneRenderer.CompositeTarget.GetData<uint32>(&id, 1, (.)relativeMouse.X, (.)relativeMouse.Y, 1, 1);

				SelectionChanged = true;
				SelectedEntityId = id;

				EntityClicked(this, id);
			}
			else
			{
				SelectionChanged = false;
			}
		}

		private void ShowMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				if (ImGui.RadioButton("Position", _gizmoType.HasFlag(.TRANSLATE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .TRANSLATE;
					else
						_gizmoType = .TRANSLATE;
				}

				if (ImGui.RadioButton("Rotation", _gizmoType.HasFlag(.ROTATE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .ROTATE;
					else
						_gizmoType = .ROTATE;
				}
				
				if (ImGui.RadioButton("Scale", _gizmoType.HasFlag(.SCALE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .SCALE;
					else
						_gizmoType = .SCALE;
				}

				if (ImGui.RadioButton("All", _gizmoType == .TRANSLATE | .ROTATE | .SCALE))
					_gizmoType = .TRANSLATE | .ROTATE | .SCALE;

				// If we scale, the mode must be local otherwise we could skew the matrix.
				if (_gizmoType.HasFlag(.SCALE))
					_gizmoMode = .LOCAL;

				if (ImGui.MenuItem(_gizmoMode == .WORLD ? "Global" : "Local", null, true, !_gizmoType.HasFlag(.SCALE)))
				{
					if (_gizmoMode == .WORLD)
						_gizmoMode = .LOCAL;
					else
						_gizmoMode = .WORLD;
				}

				_doSnap = Input.IsKeyPressed(.Shift);

				ImGui.PushItemWidth(100);

				if (_gizmoType.HasFlag(.ROTATE))
				{
					ImGui.DragFloat("Angle Snap", &_angleSnap, 1.0f, 0.0f, 180.0f);
				}

				if (_gizmoType.HasFlag(.TRANSLATE) || _gizmoType.HasFlag(.SCALE))
				{
					ImGui.DragFloat("Snap", &_snap, 0.1f, 0.0f, float.MaxValue);
				}
				
				ImGui.PopItemWidth();

				ImGui.EndMenuBar();
			}
		}

		private bool DrawImGuizmo(ImGui.Vec2 viewportSize)
		{
			// TODO: Needed if we have a orthographic editor-camera (or support gizmos in the Play-Window, where we can also have ortho projections)
			ImGuizmo.SetOrthographic(false);
			ImGuizmo.SetDrawlist();

			var topLeft = ImGui.GetWindowPos();
			var cntMin = ImGui.GetWindowContentRegionMin();

			topLeft.x += cntMin.x;
			topLeft.y += cntMin.y;
			ImGuizmo.SetRect(topLeft.x, topLeft.y, viewportSize.x, viewportSize.y);

			var view = _editor.CurrentCamera.View;
			var projection = _editor.CurrentCamera.Projection;

			if(_editor.EntityHierarchyWindow.SelectedEntities.Count == 0)
				return false;

			var entity = _editor.EntityHierarchyWindow.SelectedEntities.Back;

			var transformCmp = entity.GetComponent<TransformComponent>();

			var worldTransform = transformCmp.WorldTransform;

			Matrix parentView = .Identity;
			if (transformCmp.Parent != .InvalidEntity)
			{
				var parentTransformCmp = Entity(transformCmp.Parent, entity.Scene).GetComponent<TransformComponent>();
				parentView = parentTransformCmp.WorldTransform.Invert();
			}

			Vector3 snap = .(_snap);
			if (_gizmoType.HasFlag(.ROTATE))
				snap = .(_angleSnap);
			
			if (ImGuizmo.Manipulate((.)&view, (.)&projection, _gizmoType, _gizmoMode, (.)&worldTransform, null, _doSnap ? (.)&snap : null))
			{
				// TODO: Fix when parent is scaled
				// Seems to work fine for parent rotation and translation but scaled parent ruins everything
				// (probably because scaling a rotated matrix results in a skewed matrix, but unity can do it and so should we)
				transformCmp.LocalTransform = parentView * worldTransform;
			}

			return ImGuizmo.IsUsing();
		}
	}
}
