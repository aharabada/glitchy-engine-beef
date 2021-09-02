namespace GlitchyEngine.World
{
	public static class TransformSystem
	{
		static uint _frame;

		public static void Update(EcsWorld world)
		{
			_frame++;

			for(var entity in world.Enumerate(typeof(TransformComponent)))
			for(var (entity, transform) in world.Enumerate<TransformComponent>())
			{
				UpdateEntity(entity, transform, world);
			}
			{
				UpdateEntity(entity, world);
			}
		}

		private static void UpdateEntity(Entity entity, TransformComponent* transform, EcsWorld world)
		{
			// Todo: this probably needs a rewrite as it may scale poorly with deep hierarchies!

			// transform was updated this frame -> skip
			if(transform.Frame == _frame)
				return;
			
			transform.Frame = _frame;

			var parent = world.GetComponent<ParentComponent>(entity);

			if(transform.IsDirty)
			{
				transform.LocalTransform = .Translation(transform.Position) * .RotationX(transform.Rotation.X) *
					.RotationY(transform.Rotation.Y) * .RotationZ(transform.Rotation.Z) * .Scaling(transform.Scale);

				transform.IsDirty = false;

				if(parent == null)
				{
					transform.WorldTransform = transform.LocalTransform;
				}
			}

			if(parent != null)
			{
				var parentEntity = parent.Entity;

				var parentTransform = world.GetComponent<TransformComponent>(parentEntity);
				UpdateEntity(parentEntity, parentTransform, world);

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
