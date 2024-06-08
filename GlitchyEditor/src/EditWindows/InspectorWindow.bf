using ImGui;
using System;
using GlitchyEngine.Collections;
using GlitchyEngine.Content;
using System.Reflection;
using GlitchyEngine;
using GlitchyEditor.Assets;
using GlitchyEngine.Core;
using System.Collections;
using GlitchyEngine.World;

namespace GlitchyEditor.EditWindows;

enum SelectedObject
{
	case None;
	case Asset(AssetHandle AssetHandle);
	case Entity(Entity entity);
}

class InspectorWindow : EditorWindow
{
	public const String s_WindowTitle = "Inspector";

	private bool _lockCurrentSelection;

	private SelectedObject _selectedObject = .None;

	public this(Editor editor)
	{
		_editor = editor;

		_editor.ContentBrowserWindow.OnFileSelected.Add(new => SetSelectedAsset);
		_editor.EntityHierarchyWindow.SelectionChanged.Add(new => SetSelectedEntities);
	}

	private void SetSelectedAsset(Object sender, StringView fullFileName)
	{
		if (_lockCurrentSelection)
			return;

		Result<TreeNode<AssetNode>> treeNode = _editor.ContentManager.AssetHierarchy.GetNodeFromPath(fullFileName);
		
		if (treeNode case .Ok(let assetNode))
		{
			AssetHandle? assetHandle = assetNode->AssetFile?.AssetConfig?.AssetHandle;

			if (assetHandle != null)
			{
				_selectedObject = .Asset(assetHandle.Value);
				return;
			}
		}

		_selectedObject = .None;
	}
	
	private void SetSelectedEntities(Object sender, List<UUID> selectedEntities)
	{
		if (_lockCurrentSelection)
			return;

		if (selectedEntities.Count > 0)
		{
			Result<Entity> entityResult = _editor.EntityHierarchyWindow.GetSelectedEntity(0);

			if (entityResult case .Ok(let selectedEntity))
			{
				_selectedObject = .Entity(selectedEntity);
				return;
			}
		}

		_selectedObject = .None;
	}

	protected override void InternalShow()
	{
		//ImGui.SetNextWindowSizeConstraints(.(200, 200), .(-1, -1));

		defer
		{
			//ImGui.PopStyleVar();
			ImGui.End();
		}

		if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			return;

		// TODO: make a little button in title bar?
		ImGui.Checkbox("Lock", &_lockCurrentSelection);
		ImGui.Separator();

		ShowSelectedObject(_selectedObject, _editor);
	}

	public static void ShowSelectedObject(SelectedObject object, Editor editor)
	{
		if (object case .Asset(let assetHandle))
		{
			ShowAssetProperties(assetHandle, editor);
		}
		else if (object case .Entity(let entity))
		{
			ShowEntityProperties(entity);
		}
	}

	private static void ShowAssetProperties(AssetHandle assetHandle, Editor editor)
	{
		TreeNode<AssetNode> assetNode = TrySilent!(editor.ContentManager.AssetHierarchy.GetNodeFromAssetHandle(assetHandle));

		AssetFile assetFile = assetNode->AssetFile;

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

	private static void ShowEntityProperties(Entity entity)
	{
		ComponentEditWindow.ShowComponents(entity);
	}
}
