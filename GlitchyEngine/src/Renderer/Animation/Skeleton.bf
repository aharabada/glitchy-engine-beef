using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer.Animation
{
	public class Skeleton : RefCounter
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
		private Skeleton _skeleton ~ _.ReleaseRef();
		public JointPose[] LocalPose ~ delete _;
		public Matrix[] GlobalPose ~ delete _;
		
		public Matrix[] SkinningMatricies ~ delete _;
		public Matrix3x3[] InvTransSkinningMatricies ~ delete _;

		public Skeleton Skeleton => _skeleton;

		public this(Skeleton skeleton)
		{
			_skeleton = skeleton..AddRef();

			int jointCount = _skeleton.Joints.Count;

			LocalPose = new JointPose[jointCount];
			GlobalPose = new Matrix[jointCount];

			SkinningMatricies = new Matrix[jointCount];
			InvTransSkinningMatricies = new Matrix3x3[jointCount];
		}
	}
}
