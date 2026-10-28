using System;
using GlitchyEngine;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.History;

class ChangeEntityParentCommand : IHistorizableCommand
{
	private Scene _scene;

	private UUID _entityId;
	private UUID _oldParentId;
	private UUID _newParentId;

	public Scene Scene => _scene;
	public UUID EntityId => _entityId;
	public UUID OldParentId => _newParentId;
	public UUID NewParentId => _oldParentId;

	/// Creates a new instance of a "Reparent Entity" command.
	public this(Scene scene, UUID entityId, UUID newParentId)
	{
		_scene = scene;

		_entityId = entityId;
		_newParentId = newParentId;
	}

	public void Do()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}

		// Remember the old parents Id for the undo command.
		_oldParentId = entity.Parent?.UUID ?? .Zero;

		if (_newParentId == .Zero)
		{
			entity.Parent = null;
		}
		else
		{
			if (_scene.GetEntityByID(_newParentId) case .Ok(let newParentEntity))
			{
				entity.Parent = newParentEntity;
			}
			else
			{
				Log.EngineLogger.Error($"The required new parent Entity doesn't exist. ({this})");
			}
		}
	}

	public void Undo()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}

		if (_oldParentId == .Zero)
		{
			entity.Parent = null;
		}
		else
		{
			if (_scene.GetEntityByID(_oldParentId) case .Ok(let oldParentEntity))
			{
				entity.Parent = oldParentEntity;
			}
			else
			{
				Log.EngineLogger.Error($"The required old parent Entity doesn't exist. ({this})");
			}
		}
	}

	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: ReparentEntity
				- Scene: {_scene.Name}
				- Entity: {_entityId}
				- Old Parent: {_oldParentId}
				- New Parent: {_newParentId}
			""");
	}
}
