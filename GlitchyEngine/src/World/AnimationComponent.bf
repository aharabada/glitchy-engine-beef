using GlitchyEngine.Renderer.Animation;

namespace GlitchyEngine.World
{
	struct AnimationComponent : IDisposableComponent
	{
		private AnimationClip _animationClip;

		public AnimationClip AnimationClip
		{
			get => _animationClip;
			set mut
			{
				if(_animationClip == value)
					return;

				_animationClip?.ReleaseRef();
				_animationClip = value;
				_animationClip?.AddRef();
			}
		}

		public static void DisposeComponent(void* component)
		{
			Self* animationComponent = (Self*)component;

			animationComponent._animationClip?.ReleaseRef();
		}
	}
}
