using GlitchyEngine.World;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine;
using System;
using ImGui;

namespace GlitchyEditor.History;

class ChangePropertyCommand : IHistorizableCommand
{
	ImGui.ID _widgetId;
	Scene _scene;
	UUID _entityId;
	float3 _oldPosition;
	float3 _newPosition;

	public ImGui.ID WidgetId => _widgetId;

	public float3 NewPosition
	{
		get => _newPosition;
		set => _newPosition = value;
	}

	public this(ImGui.ID widgetId, Scene scnene, UUID entityId, float3 newPosition, float3 oldPosition)
	{
		_widgetId = widgetId;
		_scene = scnene;
		_entityId = entityId;
		_newPosition = newPosition;
		_oldPosition = oldPosition;
	}

	public void Do()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}
		
		let transformComponent = entity.GetComponent<TransformComponent>();

		//_oldPosition = transformComponent.Position;
		transformComponent.Position = _newPosition;

		// if necessary reposition Rigidbody2D
		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetPosition(_newPosition.XY);
		}
	}

	public void Undo()
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}
		
		let transformComponent = entity.GetComponent<TransformComponent>();

		transformComponent.Position = _oldPosition;

		// if necessary reposition Rigidbody2D
		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetPosition(_oldPosition.XY);
		}
	}
	
	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: Change Position
				- Scene: {_scene}
				- Entity: {_entityId}
				- Old Position: {_oldPosition}
				- New Position: {_newPosition}
			""");
	}
}