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
	public const String s_WindowTitle = "Properties";

	private AssetPropertiesEditor _currentPropertiesEditor ~ delete _;

	private bool _lockCurrentAsset;

	private bool _selectedNewAsset;

	private append String _selectedFileName = .();

	private AssetHandle _currentAssetHandle;

	public this(Editor editor)
	{
		_editor = editor;
	}

	protected override void InternalShow()
	{
		defer { ImGui.End(); }
		if(!ImGui.Begin(s_WindowTitle, &_open, .None))
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
		
		Asset asset = _editor.ContentManager.GetAsset(null, _currentAssetHandle);

		// We need the actual asset for preview and sometimes for editing
		if (asset?.Identifier != assetFile.AssetFile.Identifier)
		{
			_currentAssetHandle = _editor.ContentManager.LoadAsset(assetFile.AssetFile.Identifier);
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
		return;

		if (_currentPropertiesEditor == null)
			return;
		
		_currentPropertiesEditor.ShowEditor();

		bool assetConfigChanged = assetFile.AssetConfig.Config.Changed;
		bool hasAssetSaver = (_editor.ContentManager.[Friend]GetAssetLoader(assetFile) is IAssetSaver);

		// If the asset can't be saved and it's config didn't change disable save button
		if (!hasAssetSaver && !assetConfigChanged)
		{
			ImGui.BeginDisabled();
			defer:: { ImGui.EndDisabled(); }
		}

		if (ImGui.Button("Save"))
		{
			// Only save config if it changed
			if (assetConfigChanged)
			{
				assetFile.SaveAssetConfig();
			}

			// If the asset type has an asset saver, also save the asset
			// TODO: Check whether or not the asset was changed?
			if (hasAssetSaver)
			{
				Asset asset = _editor.ContentManager.GetAsset(null, _currentAssetHandle);
				_editor.ContentManager.SaveAsset(asset);
			}
		}
	}
}
