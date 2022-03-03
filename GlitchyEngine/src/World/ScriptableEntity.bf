namespace GlitchyEngine.World
{
	class ScriptableEntity
	{
		internal Entity _entity;

		public T* AddComponent<T>(T value = T()) where T: struct, new
		{
			return _entity.AddComponent<T>(value);
		}

		public T* GetComponent<T>() where T: struct, new
		{
			return _entity.GetComponent<T>();
		}

		public bool HasComponent<T>() where T: struct, new
		{
			return _entity.HasComponent<T>();
		}

		public void RemoveComponent<T>() where T: struct, new
		{
			_entity.RemoveComponent<T>();
		}

		protected virtual void OnCreate() {}
		protected virtual void OnDestroy() {}
		protected virtual void OnUpdate(GameTime gt) {}
	}
}