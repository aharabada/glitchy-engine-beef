using System;
using GlitchyEngine;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.History;

class RemoveComponentCommand<TComponent> : IHistorizableCommand where TComponent: struct, new, IComponent<TComponent>
{
	private Scene _scene;

	private UUID _entityId;

	private TComponent _component;

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

		TComponent.Copy(entity.GetComponent<TComponent>(), &_component);

		entity.RemoveComponent<TComponent>();
	}

	public void Undo()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}

		entity.AddComponent<TComponent>(_component);
	}

	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: Remove <{typeof(TComponent)}> component
				- Scene: {_scene.Name}
				- Entity: {_entityId}
				- Component: {_component}
			""");
	}
}
