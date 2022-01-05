using GlitchyEngine.Renderer.Animation;

namespace GlitchyEngine.World
{
	struct AnimationComponent : IDisposableComponent
	{
		private AnimationClip _animationClip;

		private SkeletonPose _pose;

		public AnimationClip AnimationClip
		{
			get => _animationClip;
			set mut
			{
				if(_animationClip == value)
					return;

				SetReference!(_animationClip, value);
			}
		}

		public float TimeIndex;

		public float TimeScale;

		public bool IsPlaying;

		public SkeletonPose Pose => _pose;

		public void Dispose()
		{
			_animationClip?.ReleaseRef();
			delete _pose;
		}
	}
}
