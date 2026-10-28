using System;
using GlitchyEngine;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.History;

class AddComponentCommand<T> : IHistorizableCommand where T: struct, new
{
	private Scene _scene;

	private UUID _entityId;

	public Scene Scene => _scene;
	public UUID EntityId => _entityId;

	/// Creates a new instance of a "Reparent Entity" command.
	public this(Scene scene, UUID entityId)
	{
		_scene = scene;
		_entityId = entityId;
	}

	public void Do()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}
		
		// TODO: Initial data?
		entity.AddComponent<T>();
	}

	public void Undo()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}

		entity.RemoveComponent<T>();
	}

	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: Add <{typeof(T)}> component
				- Scene: {_scene.Name}
				- Entity: {_entityId}
			""");
	}
}
