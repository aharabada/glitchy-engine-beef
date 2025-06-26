namespace System;

extension Enum
{
	public static void SetFlag<T>(ref T value, T flag) where T : enum
	{
		value = (T)(value.Underlying | flag.Underlying);
	}
	
	public static void ClearFlag<T>(ref T value, T flag) where T : enum
	{
		value = (T)(value.Underlying & ~flag.Underlying);
	}

	public static void SetFlagConditionally<T>(ref T value, T flag, bool setFlag) where T : enum
	{
		if (setFlag)
			SetFlag<T>(ref value, flag);
		else
			ClearFlag<T>(ref value, flag);
	}

	public static bool HasAnyFlag<T>(T value, T flags) where T : enum
	{
		return (value.Underlying & flags.Underlying) != default;
	}
}
