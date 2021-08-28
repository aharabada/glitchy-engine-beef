namespace GlitchyEngine.World
{
	public static class TransformSystem
	{
		static uint _frame;

		public static void Update(EcsWorld world)
		{
			_frame++;

			for(var entity in world.Enumerate(typeof(TransformComponent)))
			{
				UpdateEntity(entity, world);
			}
		}

		private static TransformComponent* UpdateEntity(Entity entity, EcsWorld world)
		{
			// Todo: this probably needs a rewrite as it may scale poorly with deep hierarchies!

			var transform = world.GetComponent<TransformComponent>(entity);

			// If tranform was updated this frame -> skip
			if(transform.Frame == _frame)
				return transform;

			var parent = world.GetComponent<ParentComponent>(entity);

			if(transform.IsDirty)
			{
				transform.LocalTransform = .Translation(transform.Position) * .RotationX(transform.Rotation.X) *
					.RotationY(transform.Rotation.Y) * .RotationZ(transform.Rotation.Z) * .Scaling(transform.Scale);
				transform.Frame = _frame;
				transform.IsDirty = false;

				if(parent == null)
				{
					transform.WorldTransform = transform.LocalTransform;
				}
			}

			if(parent != null)
			{
				var parentTransform = UpdateEntity(parent.Entity, world);

				// Parent transform is newer than our transform or was updated this frame
				if(parentTransform.Frame >= transform.Frame)
				{
					transform.WorldTransform = parentTransform.WorldTransform * transform.LocalTransform;
					transform.Frame = parentTransform.Frame;
				}
			}

			return transform;
		}
	}
}
