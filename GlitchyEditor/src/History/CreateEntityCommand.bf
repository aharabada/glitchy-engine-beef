using System;
using GlitchyEngine;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.History;

class CreateEntityCommand : IHistorizableCommand
{
	private Scene _scene;

	private String _name ~ delete:append _;
	private UUID _entityId;
	private UUID _parentId;

	public Scene Scene => _scene;
	public String EntityName => _name;
	public UUID EntityId => _entityId;
	public UUID ParentId => _parentId;

	/// Creates a new instance of a "Create Entity" command.
	/// @param scene The scene which the entity will be created in.
	/// @param name The name the entity should be created with.
	/// @param entityId The Id of the entity to create.
	///			Use UUID.Zero to define that a random Id should be chosen.
	/// 		(Note: This Id MUST remain reserved in the scene as long as this command exists).
	/// @param parentId The Id of the Entity which will be a parent of the create entity in the hierarchy.
	///			Use UUID.Zero to define that no parent is to be used.
	[AllowAppend]
	public this(Scene scene, StringView name = "", UUID entityId = .Zero, UUID parentId = .Zero)
	{
		String nameBuffer = append String(name);

		_scene = scene;

		_name = nameBuffer;
		_entityId = entityId;

		_parentId = parentId;
	}

	public void Do()
	{
		let newEntity = _scene.CreateEntity(_name, _entityId);

		if (_entityId == .Zero)
		{
			/// No Id was specified, so we remember the one that was chosen by the scene.
			/// That way we can identically recreate the Entity after an undo.
			_entityId = newEntity.UUID;
		}

		let transformCmp = newEntity.GetComponent<TransformComponent>();

		if (_parentId != .Zero)
		{
			if (_scene.GetEntityByID(_parentId) case .Ok(let parentEntity))
			{
				transformCmp.Parent = parentEntity.Handle;
			}
			else
			{
				Log.EngineLogger.Error($"The required parent Entity doesn't exist. ({this})");
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

		// Todo: we might want to consider checking, that
		// 		A: the entity doesn't have any children
		// 		and B: the entity doesn't have any components (except for transform and editor flags...)

		_scene.DestroyEntity(entity, destroyChildren: false, leaveIdReserved: true);
	}

	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF($"""
			Command: CreateEntity
				- Scene: {_scene.Name}
				- Entity (Name: "{_name}", Id: {_entityId})
				- Parent: {_parentId}
			""");
	}
}
