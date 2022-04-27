using System.Numerics;

namespace DotNetScriptingHelper;

public static class QuaternionExtensions
{
    public static (Vector3 Axis, float Angle) ToAxisAngle(this Quaternion quat)
	{
        // scalar part = cos(θ/2)
        // So, we can extract the angle directly.
        float angle = 2.0f * MathF.Acos(quat.W);

        // vector part = axis * sin(θ/2)
        // In other words, the vector part is the axis, but with length of sin(θ/2).
        // We assume quaternion is unit length, so subtracting w^2 gives us length of just vector part (aka sin(θ/2)).
        float length = MathF.Sqrt(1.0f - (quat.W * quat.W));

        Vector3 axis;

        // Normalize vector part to get the axis!
        if (length == 0)
        {
            axis = Vector3.Zero;
        }
        else
        {
            length = 1.0f / length;
            axis.X = quat.X * length;
            axis.Y = quat.Y * length;
            axis.Z = quat.Z * length;
        }

        return (axis, angle);
	}

    public static Vector3 ToEulerAngles(this Quaternion q)
    {
        // http://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToEuler/

        Vector3 result;

        float sqw = q.W * q.W;
        float sqx = q.X * q.X;
        float sqy = q.Y * q.Y;
        float sqz = q.Z * q.Z;
        float unit = sqx + sqy + sqz + sqw; // if normalised is one, otherwise is correction factor
        float test = q.X * q.Y + q.Z * q.W;
        if (test > 0.4999f * unit)
        { // singularity at north pole
            result.Y = 2.0f * MathF.Atan2(q.X, q.W);
            result.Z = MathF.PI / 2.0f;
            result.X = 0.0f;
            return result;
        }
        if (test < -0.4999f * unit)
        { // singularity at south pole
            result.Y = -2.0f * MathF.Atan2(q.X, q.W);
            result.Z = -MathF.PI / 2.0f;
            result.X = 0.0f;
            return result;
        }
        result.Y = MathF.Atan2(2 * q.Y * q.W - 2 * q.X * q.Z, sqx - sqy - sqz + sqw);
        result.Z = MathF.Asin(2 * test / unit);
        result.X = MathF.Atan2(2 * q.X * q.W - 2 * q.Y * q.Z, -sqx + sqy - sqz + sqw);

        return result;
    }
}
