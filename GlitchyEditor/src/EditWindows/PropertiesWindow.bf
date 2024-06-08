using ImGui;
using System;
using GlitchyEngine.Collections;
using GlitchyEngine.Content;
using System.Reflection;
using GlitchyEngine;
using GlitchyEditor.Assets;
using GlitchyEngine.Core;

namespace GlitchyEditor.EditWindows;

class PropertiesWindow : EditorWindow
{
	public const String s_WindowTitle = "Properties";

	private AssetPropertiesEditor _currentPropertiesEditor ~ delete _;

	private bool _lockCurrentAsset;

	private bool _selectedNewAsset;

	private append String _selectedFileName = .();

	private AssetHandle _currentAssetHandle;

	private SelectedObject _selectedObject;

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

		if (assetFile == null)
			return;

		if (ImGui.BeginPropertyTable("asset_properties", ImGui.GetID("asset_properties")))
		{
			assetFile.AssetConfig?.ImporterConfig?.ShowEditor();
			assetFile.AssetConfig?.ProcessorConfig?.ShowEditor();
			assetFile.AssetConfig?.ExporterConfig?.ShowEditor();

			ImGui.EndTable();
			
			ImGui.Separator();
		}

		bool hasChanges = (assetFile.AssetConfig?.ImporterConfig?.Changed ?? false) || (assetFile.AssetConfig?.ProcessorConfig?.Changed ?? false) || (assetFile.AssetConfig?.ExporterConfig?.Changed ?? false);

		if (!hasChanges)
			ImGui.BeginDisabled();

		if (ImGui.Button("Apply"))
		{
			assetFile.SaveAssetConfig();
		}

		if (!hasChanges)
			ImGui.EndDisabled();
	}
}
