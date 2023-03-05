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

	private bool _lockCurrentAsset;

	private bool _selectedNewAsset;

	private append String _selectedFileName = .();

	private Asset _currentAsset ~ _?.ReleaseRef();

	public this(Editor editor)
	{
		_editor = editor;
	}

	protected override void InternalShow()
	{
		defer { ImGui.End(); }
		if(!ImGui.Begin("Properties", &_open, .None))
			return;

		// TODO: make a little button in title bar?
		ImGui.Checkbox("Lock", &_lockCurrentAsset);
		ImGui.Separator();

		ShowAssetProperties();
	}

	/// Gets the AssetFile for the asset currently selected in the ContentBrowserWindow
	/// @returns the AssetFile for the currently selected asset of null, if no file is selected.
	private AssetFile GetCurrentAssetFile()
	{
		// Only grab the currently selected file if we aren't locked
		if (!_lockCurrentAsset)
		{
			StringView selectedInFileBrowser = _editor.ContentBrowserWindow.SelectedFile;

			if (_selectedFileName != selectedInFileBrowser)
			{
				_selectedFileName.Set(_editor.ContentBrowserWindow.SelectedFile);
			}
		}

		Result<TreeNode<AssetNode>> treeNode = _editor.ContentManager.AssetHierarchy.GetNodeFromPath(_selectedFileName);

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

		// We need the actual asset for preview and sometimes for editing
		if (_currentAsset?.Identifier != assetFile.Identifier)
		{
			_currentAsset?.ReleaseRef();
			_currentAsset = _editor.ContentManager.LoadAsset(assetFile.Identifier);
		}

		// TODO: allow changing AssetLoader
		// assetFile.AssetConfig.AssetLoade

		// TODO: ignore file
		/*ImGui.Checkbox("Ignore", &assetFile.AssetConfig.IgnoreFile);
		
		if (ImGui.IsItemHovered())
			ImGui.SetTooltip("If checked this file will be ignored and not treated as an asset.");*/

		ShowPropertiesEditor(assetFile);

		ImGui.Separator();

		// TODO: preview asset
	}

	private void ShowPropertiesEditor(AssetFile assetFile)
	{
		if (_currentPropertiesEditor == null)
			return;
		
		_currentPropertiesEditor.ShowEditor();
		
		if (ImGui.Button("Save Asset"))
		{
			_editor.ContentManager.SaveAsset(_currentAsset);
		}

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
