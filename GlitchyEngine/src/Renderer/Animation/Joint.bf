using GlitchyEngine.Math;
using System;

namespace GlitchyEngine.Renderer.Animation
{
	public struct Joint
	{
		/// Converts vertices from model space to joint space
		public Matrix InverseBindPose;
		public String Name;
		public uint8 ParentID;
	}

	public struct JointPose
	{
		public Quaternion Rotation;
		public Vector3 Translation;
		public Vector3 Scale;
	}
}
