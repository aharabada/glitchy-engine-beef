using System;

namespace GlitchyEngine.World
{
	public static class TransformSystem
	{
		static uint _frame;

		public static void Update(EcsWorld world)
		{
			_frame++;

			for(var (entity, transform) in world.Enumerate<TransformComponent>())
			{
				UpdateEntity(entity, transform, world);
			}
		}

		private static void UpdateEntity(EcsEntity entity, TransformComponent* transform, EcsWorld world)
		{
			// Todo: test scaling with deep hierarchies!

			// transform was updated this frame -> skip
			if(transform.Frame == _frame)
				return;
			
			transform.Frame = _frame;

			//var parent = world.GetComponent<ParentComponent>(entity);

			if(transform.IsDirty)
			{
				//transform.LocalTransform = .Translation(transform.Position) * .RotationQuaternion(transform.Rotation) * .Scaling(transform.Scale);
				transform.[Friend]_localTransform = .Translation(transform.Position) * .RotationQuaternion(transform.Rotation) * .Scaling(transform.Scale);

				transform.IsDirty = false;

				if(transform.Parent == EcsEntity.InvalidEntity)
				{
					transform.WorldTransform = transform.LocalTransform;
				}
			}

			if(transform.Parent != EcsEntity.InvalidEntity)
			{
				var parentTransform = world.GetComponent<TransformComponent>(transform.Parent);
				UpdateEntity(transform.Parent, parentTransform, world);

				// TODO: I think we unnecessarily recalculate world transform every frame
				// Parent transform is newer than our transform or was updated this frame
				if(parentTransform.Frame >= transform.Frame)
				{
					transform.WorldTransform = parentTransform.WorldTransform * transform.LocalTransform;
				}
			}
		}
	}
}
