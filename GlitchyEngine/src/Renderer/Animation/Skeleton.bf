using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer.Animation
{
	public class Skeleton
	{
		public Joint[] Joints ~ delete _;

		public Joint? GetParent(Joint joint)
		{
			if(joint.ParentID == uint8.MaxValue)
				return null;

			return Joints[joint.ParentID];
		}

		public ~this()
		{
			for(var joint in Joints)
			{
				delete joint.Name;
			}
		}
	}

	public class SkeletonPose
	{
		public Skeleton Skeleton;
		public JointPose[] LocalPose ~ delete _;
		public Matrix[] GlobalPose ~ delete _;

		public this(Skeleton skeleton)
		{
			Skeleton = skeleton;

			int jointCount = Skeleton.Joints.Count;

			LocalPose = new JointPose[jointCount];
			GlobalPose = new Matrix[jointCount];
		}
	}
}
