using ImGui;
using System;
using GlitchyEngine.Collections;
using GlitchyEngine.Content;
using System.Reflection;
using GlitchyEngine;
using GlitchyEditor.Assets;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.EditWindows;

class PropertiesWindow : ClosableWindow
{
	private SelectedObject _selectedObject = .None;

	public this(Editor editor, SelectedObject selectedObject) : base(editor, "Properties")
	{
		_selectedObject = selectedObject;
	}

	protected override void InternalShow()
	{
		UpdateTitle();

		InspectorWindow.ShowSelectedObject(_selectedObject, _editor);
	}

	private void UpdateTitle()
	{
		if (_selectedObject case .Entity(let entityId) &&
			_editor.CurrentScene.GetEntityByID(entityId) case .Ok(let entity))
		{
			WindowTitle = scope $"Properties: {entity.Name}";
		}
		else if (_selectedObject case .Asset(let assetHandle) &&
			_editor.ContentManager.AssetHierarchy.GetNodeFromAssetHandle(assetHandle) case .Ok(let assetNode))
		{
			WindowTitle = scope $"Properties: {assetNode->AssetFile?.AssetFile?.Identifier}";
		}
	}
}
