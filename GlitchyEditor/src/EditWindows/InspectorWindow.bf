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
using GlitchyEngine.Renderer;
using GlitchyEditor.Assets.Editors;

namespace GlitchyEditor.EditWindows;

enum SelectedObject
{
	case None;
	case Asset(AssetHandle AssetHandle);
	case Entity(UUID entityId);
	case Component(UUID entityId, Type componentType);
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
				_selectedObject = .Entity(selectedEntity.UUID);
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

		DeselectIfInvalid();

		ShowSelectedObject(_selectedObject, _editor);
	}

	private void DeselectIfInvalid()
	{
		if (_selectedObject case .Entity(let entityId) &&
			_editor.CurrentScene.GetEntityByID(entityId) case .Err)
		{
			_selectedObject = .None;
		}
		else if (_selectedObject case .Asset(let assetHandle) &&
			_editor.ContentManager.AssetHierarchy.GetNodeFromAssetHandle(assetHandle) case .Err)
		{
			_selectedObject = .None;
		}
	}

	public static void ShowSelectedObject(SelectedObject object, Editor editor)
	{
		if (object case .Asset(let assetHandle))
		{
			ShowAssetProperties(assetHandle, editor);
		}
		else if (object case .Entity(let entityId))
		{
			ShowEntityProperties(entityId, editor);
		}
		else if (object case .Component(let entityId, let componentType))
		{
			ShowEntityProperties(entityId, editor, componentType);
		}
	}

	private static void ShowAssetProperties(AssetHandle assetHandle, Editor editor)
	{
		Result<TreeNode<AssetNode>> assetNode = editor.ContentManager.AssetHierarchy.GetNodeFromAssetHandle(assetHandle);

		if (assetNode case .Err)
		{
			ImGui.TextWrapped($"ERROR!\n\nAsset {assetHandle} doesn't exist.");

			return;
		}

		AssetFile assetFile = assetNode->Value.AssetFile;

		// TODO: assetFile.loadedAsset has the asset
		// TODO: we need to manually load it
		// TODO: if available, show editor for asset
		// TODO: if asset changed, show save button?

		if (ImGui.BeginPropertyTable("asset_properties", ImGui.GetID("asset_properties")))
		{
			assetFile.AssetConfig?.ImporterConfig?.ShowEditor(assetFile);
			assetFile.AssetConfig?.ProcessorConfig?.ShowEditor(assetFile);
			assetFile.AssetConfig?.ExporterConfig?.ShowEditor(assetFile);

			if (assetFile.LoadedAsset != null)
			{
				// TODO: Where do we get the asset editor from?
				if (let mat = assetFile.LoadedAsset as Material)
				{
					MaterialEditor.ShowEditor(assetFile);
					//ImGui.TextUnformatted(assetFile.LoadedAsset.Identifier);
				}
			}

			ImGui.EndTable();
			
			ImGui.Separator();
		}

		bool hasChanges = (assetFile.AssetConfig?.ImporterConfig?.Changed == true) ||
			(assetFile.AssetConfig?.ProcessorConfig?.Changed == true) ||
			(assetFile.AssetConfig?.ExporterConfig?.Changed == true);

		ImGui.BeginDisabled(!hasChanges);

		if (ImGui.Button("Apply"))
		{
			assetFile.SaveAssetConfigIfChanged();
		}

		ImGui.EndDisabled();
	}

	private static void ShowEntityProperties(UUID entityId, Editor editor, Type componentType = null)
	{
		Result<Entity> entityResult = editor.CurrentScene.GetEntityByID(entityId);

		if (entityResult case .Ok(let entity))
		{
			ComponentEditWindow.ShowComponents(entity, componentType);
		}
		else
		{
			ImGui.TextWrapped($"ERROR!\n\nEntity {entityId} doesn't exist.");
		}
	}
}
