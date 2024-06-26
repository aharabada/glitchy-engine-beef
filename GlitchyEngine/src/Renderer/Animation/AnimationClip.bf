using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer.Animation
{
	class AnimationPlayer
	{
		public Skeleton Skeleton ~ _.ReleaseRef();
		public AnimationClip CurrentClip ~ _.ReleaseRef();
		public float TimeStamp;

		public SkeletonPose Pose ~ delete _;

		public Matrix[] SkinningMatricies ~ delete _;
		public Matrix3x3[] InvTransSkinningMatricies ~ delete _;

		public this(Skeleton skeleton, AnimationClip clip)
		{
			Skeleton = skeleton;
			CurrentClip = clip;

			Pose = new SkeletonPose(Skeleton);

			SkinningMatricies = new Matrix[Skeleton.Joints.Count];
			InvTransSkinningMatricies = new Matrix3x3[Skeleton.Joints.Count];
		}

		public void Update(GameTime gameTime)
		{
			TimeStamp += (float)gameTime.FrameTime.TotalSeconds;

			if(CurrentClip.IsLooping && CurrentClip.Duration != 0)
			{
				TimeStamp %= CurrentClip.Duration;
			}

			for(int i < Skeleton.Joints.Count)
			{
				ref JointPose localPose = ref Pose.LocalPose[i];

				localPose = CurrentClip.JointAnimations[i].GetCurrentPose(TimeStamp);

				Matrix jointToParent =
					Matrix.Translation(localPose.Translation) *
					Matrix.RotationQuaternion(localPose.Rotation) *
					Matrix.Scaling(localPose.Scale);

				uint8 parentIndex = Skeleton.Joints[i].ParentID;
				
				ref Matrix globalPose = ref Pose.GlobalPose[i];

				if(parentIndex == uint8.MaxValue)
				{
					globalPose = jointToParent;
				}
				else
				{
					globalPose = Pose.GlobalPose[parentIndex] * jointToParent;
				}

				SkinningMatricies[i] = globalPose * Skeleton.Joints[i].InverseBindPose;
				InvTransSkinningMatricies[i] = ((Matrix3x3)SkinningMatricies[i]).Inverse().Transpose();
			}
		}
	}

	class AnimationClip : RefCounter
	{
		private Skeleton _skeleton ~ _.ReleaseRef();
		public JointAnimation[] JointAnimations ~ delete _;
		public bool IsLooping;
		public float Duration;

		public Skeleton Skeleton => _skeleton;

		[AllowAppend]
		public this(Skeleton skeleton)
		{
			var jointAnimations = new JointAnimation[skeleton.Joints.Count];

			Log.EngineLogger.AssertDebug(skeleton != null);

			_skeleton = skeleton..AddRef();
			JointAnimations = jointAnimations;
		}

		// TODO: check
		public ~this()
		{
			for(var jointAnimation in JointAnimations)
			{
				//jointAnimation.Dispose();
				delete jointAnimation;
			}
		}
	}
	
	public enum InterpolationMode
	{
		/**
		 * No keyframe interpolation.
		 * The keyframe with the greates timestamp that is smaller than the current time will be used.
		 */
		Step,
		/**
		 * Linear interpolation between the two keyframes that are closest to the current time.
		 */
		Linear,
		/**
		 * Cubic spline interpolation between the two keyframes that are closest to the current time.
		 */
		CubicSpline
	}

	class JointAnimationChannel<T> where T : struct // : IDisposable 
	{
		public float[] TimeStamps;
		public T[] Values;
		public InterpolationMode InterpolationMode = .Step;

		public float Duration => TimeStamps[TimeStamps.Count - 1];

		public this(int samples, InterpolationMode interpolationMode)
		{
			TimeStamps = new float[samples];
			Values = new T[samples];
			InterpolationMode = interpolationMode;
		}

		public ~this()
		{
			delete TimeStamps;
			delete Values;
		}
		

		public (T, T, float) GetSample(float currentTime)
		{
			let (previousIndex, previousTime) = FindPreviousTimeStamp(currentTime);

			T previousSample = Values[previousIndex];

			if(InterpolationMode == .Step)
			{
				return (previousSample, default(T), 0f);
			}
			else
			{
				int nextIndex = previousIndex + 1;
				if(nextIndex >= Values.Count)
					nextIndex = Values.Count - 1;

				float nextTime = TimeStamps[nextIndex];

				T nextSample = Values[nextIndex];
				
				float interpolationValue = (currentTime - previousTime) / (nextTime - previousTime);

				return (previousSample, nextSample, interpolationValue);
			}
		}

		public (int Index, float timeStamp) FindPreviousTimeStamp(float currentTime)
		{
			// TODO use binary search to speed things up?

			int index = TimeStamps.Count - 1;

			for(int i < TimeStamps.Count)
			{
				if(TimeStamps[i] > currentTime)
				{
					index = i - 1;
					break;
				}
			}

			if(index == -1)
				index = 0;

			// Don't return -1 but return first frame
			return (index, TimeStamps[index]);

			//return array.Count - 1;
		}
	}

	class JointAnimation// : IDisposable
	{
		public JointAnimationChannel<float3> TranslationChannel ~ delete _;
		public JointAnimationChannel<Quaternion> RotationChannel ~ delete _;
		public JointAnimationChannel<float3> ScaleChannel ~ delete _;

		public float Duration
		{
			get
			{
				return Math.Max(Math.Max(
					TranslationChannel?.Duration ?? 0, RotationChannel?.Duration ?? 0), ScaleChannel?.Duration ?? 0);
			}
		}
		/*
		public void Dispose()
		{
			delete TranslationChannel;
			delete RotationChannel;
			delete ScaleChannel;
		}
		*/
		public JointPose GetCurrentPose(float timeStamp)
		{
			JointPose result;

			if(TranslationChannel != null)
			{
				let (previous, next, interpolationValue) = TranslationChannel.GetSample(timeStamp);

				switch(TranslationChannel.InterpolationMode)
				{
				case .Step:
					result.Translation = previous;
				case .Linear:
					result.Translation = lerp(previous, next, interpolationValue);
				default:
					result.Rotation = ?;
					Runtime.NotImplemented();
				}
			}
			else
			{
				result.Translation = .Zero;
			}
			
			if(RotationChannel != null)
			{
				let (previous, next, interpolationValue) = RotationChannel.GetSample(timeStamp);
				
				switch(RotationChannel.InterpolationMode)
				{
				case .Step:
					result.Rotation = previous;
				case .Linear:
					result.Rotation = Quaternion.Slerp(previous, next, interpolationValue);
				default:
					result.Rotation = ?;
					Runtime.NotImplemented();
				}
			}
			else
			{
				result.Rotation = .Identity;
			}
			
			if(ScaleChannel != null)
			{
				let (previous, next, interpolationValue) = ScaleChannel.GetSample(timeStamp);
				
				//switch(ScaleChannel.InterpolationMode)
				switch(InterpolationMode.Step)
				{
				case .Step:
					result.Scale = previous;
				case .Linear:
					result.Scale = lerp(previous, next, interpolationValue);
				default:
					result.Rotation = ?;
					Runtime.NotImplemented();
				}
			}
			else
			{
				result.Scale = .One;
			}

			return result;
		}
	}
}
