using System;
namespace GlitchyEngine.Scripting;

enum DotNetVersionType
{
	case Normal;
	case Preview(int Number);
	case ReleaseCandidate(int Number);
	case Unknown;

	public int GetSortingOrder()
	{
		switch (this)
		{
		case .Normal:
			return 3;
		case .ReleaseCandidate:
			return 2;
		case .Preview:
			return 1;
		case .Unknown:
			return 0;
		}
	}
}

struct DotNetVersion
{
	public int Major;
	public int Minor;
	public int Patch;

	public DotNetVersionType Type;

	public this()
	{
		this = default;
	}

	public this(int major, int minor, int patch, DotNetVersionType type)
	{
		Major = major;
		Minor = minor;
		Patch = patch;
		Type = type;
	}

	public override void ToString(String outBuffer)
	{
		outBuffer.AppendF($"{Major}.{Minor}.{Patch}");

		switch (Type)
		{
		case .Normal:
			// Nothing to do.
		case .Preview(int Number):
			outBuffer.AppendF($" (Preview {Number})");
		case .ReleaseCandidate(int Number):
			outBuffer.AppendF($" (Release Candidate {Number})");
		case .Unknown:
			outBuffer.Append(" (Unknown release type)");
		}
	}

	public static int operator <=>(DotNetVersion lhs, DotNetVersion rhs)
	{
		if (lhs.Major != rhs.Major)
		    if (lhs.Major > rhs.Major)
		        return 1;
		    else
		        return -1;

		if (lhs.Minor != rhs.Minor)
		    if (lhs.Minor > rhs.Minor)
		        return 1;
		    else
		        return -1;

		if (lhs.Patch != rhs.Patch)
		    if (lhs.Patch > rhs.Patch)
		        return 1;
		    else
		        return -1;

		return lhs.Type.GetSortingOrder() <=> rhs.Type.GetSortingOrder();
	}
}
