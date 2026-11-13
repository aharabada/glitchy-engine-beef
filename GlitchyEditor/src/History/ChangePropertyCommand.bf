using GlitchyEngine.World;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine;
using System;
using ImGui;

namespace GlitchyEditor.History;

class ChangeComponentPropertyCommand<TComponent, TValue> : IHistorizableCommand where TComponent: struct, new
{
	public function void ApplyValueFunction(Entity entity, TComponent* component, TValue newValue);

	ImGui.ID _widgetId;
	Scene _scene;
	UUID _entityId;
	protected TValue _oldValue;
	protected TValue _newValue;
	ApplyValueFunction _applyValue;
	
	public ImGui.ID WidgetId => _widgetId;
	
	public TValue NewValue
	{
		get => _newValue;
		set => _newValue = value;
	}

	public this(ImGui.ID widgetId, Scene scene, UUID entityId, TValue newValue, TValue oldValue, ApplyValueFunction applyValue)
	{
		_widgetId = widgetId;
		_scene = scene;
		_entityId = entityId;
		_newValue = newValue;
		_oldValue = oldValue;
		_applyValue = applyValue;
	}

	public void Do()
	{
		ApplyValue(_newValue);
	}

	public void Undo()
	{
		ApplyValue(_oldValue);
	}

	private void ApplyValue(TValue value)
	{
		if (_scene.GetEntityByID(_entityId) not case .Ok(let entity))
		{
			Log.EngineLogger.Error($"The required Entity doesn't exist. ({this})");
			return;
		}

		TComponent* component = entity.GetComponent<TComponent>();

		_applyValue(entity, component, value);
	}
	
	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: Change {typeof(TComponent)}
				- WidgetId: {_widgetId}
				- Scene: {_scene}
				- Entity: {_entityId}
				- Old Value: {_oldValue}
				- New Value: {_newValue}
			""");
	}
}

extension ChangeComponentPropertyCommand<TComponent, TValue>
	where TComponent: struct, new
	where TValue: String, delete
{
	public new StringView NewValue
	{
		get => _newValue;
		set => _newValue.Set(value);
	}
	
	public this(ImGui.ID widgetId, Scene scene, UUID entityId, StringView newValue, StringView oldValue, ApplyValueFunction applyValue):
		[NoExtension]this(widgetId, scene, entityId, new String(newValue), new String(oldValue), applyValue)
	{
	}

	public ~this()
	{
		delete _oldValue;
		delete _newValue;
	}
}
