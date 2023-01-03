using ImGui;
using System;
using GlitchyEngine.Collections;
using GlitchyEngine.Content;
using System.Reflection;
using GlitchyEngine;
using GlitchyEditor.Assets;

namespace GlitchyEditor.EditWindows;

class PropertiesWindow : EditorWindow
{
	private AssetPropertiesEditor _currentPropertiesEditor ~ delete _;

	public this(Editor editor)
	{
		_editor = editor;
	}

	protected override void InternalShow()
	{
		defer { ImGui.End(); }
		if(!ImGui.Begin("Properties", &_open, .None))
			return;

		ShowAssetProperties();
	}

	/// Gets the AssetFile for the asset currently selected in the ContentBrowserWindow
	/// @returns the AssetFile for the currently selected asset of null, if no file is selected.
	private AssetFile GetCurrentAssetFile()
	{
		StringView selectedFileName = _editor.ContentBrowserWindow.SelectedFile;

		Result<TreeNode<AssetNode>> treeNode = _editor.ContentManager.AssetHierarchy.GetNodeFromPath(selectedFileName);

		if (treeNode case .Ok(let assetNode))
			return assetNode->AssetFile;
		
		return null;
	}

	private void ShowAssetProperties()
	{
		AssetFile assetFile = GetCurrentAssetFile();

		if (_currentPropertiesEditor?.Asset != assetFile)
		{
			delete _currentPropertiesEditor;
			_currentPropertiesEditor = _editor.ContentManager.GetNewPropertiesEditor(assetFile);
		}	 

		if (assetFile == null)
			return;

		// TODO: allow changing AssetLoader
		// assetFile.AssetConfig.AssetLoade

		// TODO: ignore file
		/*ImGui.Checkbox("Ignore", &assetFile.AssetConfig.IgnoreFile);
		
		if (ImGui.IsItemHovered())
			ImGui.SetTooltip("If checked this file will be ignored and not treated as an asset.");*/

		ShowPropertiesEditor(assetFile);
	}

	private void ShowPropertiesEditor(AssetFile assetFile)
	{
		if (_currentPropertiesEditor == null)
			return;
		
		_currentPropertiesEditor.ShowEditor();

		if (!assetFile.AssetConfig.Config.Changed)
		{
			ImGui.BeginDisabled();
			defer:: { ImGui.EndDisabled(); }
		}
		
		ImGui.Separator();

		if (ImGui.Button("Apply"))
			assetFile.SaveAssetConfig();
	}
}
