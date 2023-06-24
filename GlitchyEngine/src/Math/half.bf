using System;

namespace GlitchyEngine.Math;

/// Represents a 16bit floating point number. (IEEE 754 half-precision binary floating-point (binary16))
/// Note: Eventhough it is possible, it is not recommended to perform calculations on this type.
/// Most operations will simply convert the halfs to floats, perform the calculation and convert the result back to half.
struct half : IFloating, ISigned, IFormattable, IHashable, IEquatable<half>, ICanBeNaN
{
	public const half MinValue = half(-65504); // Should be 0xFBFF
	public const half MaxValue = half(65504); // Should be 0x7BFF

	// The numbers for Inifnity, NaN and Zero need to be hardcoded as binaries,
	// because the conversion intself relies on them.

	public const half PositiveInfinity = half(0x7C00);
	public const half NegativeInfinity = half(0xFC00);
	public const half NaN = half(0x7CFF);
	
	public const half Zero = half(0x0000);
	public const half NegativeZero = half(0x8000);

	private uint16 _data;

	public bool IsNegative => (_data & Half_Sign_Mask) > 0;

	public bool IsFinity => (_data & ~Half_Sign_Mask) < Half_Exponent_Mask;
	public bool IsInfinity => (_data & ~Half_Sign_Mask) == Half_Exponent_Mask;
	
	public bool IsPositiveInfinity => _data == PositiveInfinity._data;
	public bool IsNegativeInfinity => _data == NegativeInfinity._data;

	public bool IsNaN => (_data & ~Half_Sign_Mask) > Half_Exponent_Mask;
	
	public bool IsSubnormal
	{
		get
		{
			var unsignedBits = _data & ~Half_Sign_Mask;

			// Zero isn't normalized and if exponent is 0 we are unnormalized
			return (unsignedBits != 0) && ((unsignedBits & Half_Exponent_Mask) == 0);
		}
	}

	public this(float value)
	{
		this = FromFloat32(value);
	}

	private this(uint16 data)
	{
		_data = data;
	}

	public explicit static operator half(float value) => FromFloat32(value);
	public explicit static operator float(half value) => ToFloat32(value);

	public static half FromFloat32(float value)
	{
		if (value == 0.0f)
			return half(0x0000);

		if (value == -0.0f)
			return half(0x8000);

#unwarn
		uint32 singleBits = *(uint32*)&value;

		uint32 sign = GetSingleSignBit(singleBits);
		int32 exponent = (int32)GetSingleExponent(singleBits);
		uint32 mantissa = GetSingleMantissa(singleBits);

		// Shift 13 so we truncate mantissa from 23 to 10 bits.
		uint32 halfMantissa = mantissa >> 13;

		if (exponent == 0xFF)
		{
			// largest possible single exponent -> either infinity or NaN

			if (mantissa == 0)
			{
				// Infinity
				return (sign == 1) ? NegativeInfinity : PositiveInfinity;
			}
			else
			{
				// NaN -> Keeps sign and mantissa intact

				uint16 halfBits = SetHalfSignBit(0, (uint16)sign);
				// Set all five exponent bits to 1
				halfBits = SetHalfExponent(halfBits, 0x1F);
				halfBits = SetHalfMantissa(halfBits, (uint16)halfMantissa);

				return half(halfBits);
			}
		}

		// Normalized single

		// excess-K decode and encode -127 is k for single, 15 is k for half
		exponent = exponent - 127 + 15;

		if (exponent < 0)
			// The given number is too small for a half (even denormalized) -> return 0
			return (sign == 1) ? NegativeZero : Zero;

		if (exponent > 31)
			// The given number is too large for a half -> return infinity
			return (sign == 1) ? NegativeInfinity : PositiveInfinity;

		// The given number fits -> convert (might become denormalized)
		uint16 halfBits = SetHalfSignBit(0, (uint16)sign);
		halfBits = SetHalfExponent(halfBits, (uint16)exponent);
		halfBits = SetHalfMantissa(halfBits, (uint16)halfMantissa);

		return half(halfBits);
	}

	public static float ToFloat32(half value)
	{
#unwarn
		uint16 halfBits = *(uint16*)&value;

		if (halfBits == Zero._data)
			return 0.0f;

		if (halfBits == NegativeZero._data)
			return -0.0f;

		uint16 sign = GetHalfSignBit(halfBits);
		int16 exponent = (int16)GetHalfExponent(halfBits);
		uint16 mantissa = GetHalfMantissa(halfBits);
		
		// Shift 13 so we extend mantissa from 10 to 23 bits.
		uint32 singleMantissa = (uint32)mantissa << 13;

		if (exponent == 0x1F)
		{
			// largest possible half exponent -> either infinity or NaN

			if (mantissa == 0)
			{
				// Infinity
				return (sign == 1) ? float.NegativeInfinity : float.PositiveInfinity;
			}
			else
			{
				// NaN -> Keeps sign and mantissa intact

				uint32 singleBits = SetSingleSignBit(0, sign);
				// Set all five exponent bits to 1
				singleBits = SetSingleExponent(halfBits, 0xFF);
				singleBits = SetSingleMantissa(halfBits, singleMantissa);

				return *(float*)&singleBits;
			}
		}

		// Normalized half

		// excess-K decode and encode -127 is k for single, 15 is k for half
		exponent = exponent - 15 + 127;

		uint32 singleBits = SetSingleSignBit(0, sign);
		singleBits = SetSingleExponent(singleBits, (uint32)exponent);
		singleBits = SetSingleMantissa(singleBits, singleMantissa);

		return *(float*)&singleBits;
	}

#region Single <-> Half Helpers

	const uint32 Single_Sign_Shift = 31;
	const uint32 Single_Sign_Mask = 0x8000'0000; // 1 bit, offset 31

	const uint32 Single_Exponent_Shift = 23;
	const uint32 Single_Exponent_Mask = 0x7F80'0000; // 8 bit, offset 23

	const uint32 Single_Mantissa_Mask = 0x007F'FFFF; // 23 bit, offset 0
	
	const uint16 Half_Sign_Shift = 15;
	const uint16 Half_Sign_Mask = 0x8000; // 1 bit, offset 15

	const uint16 Half_Exponent_Shift = 10;
	const uint16 Half_Exponent_Mask = 0x7C00; // 5 bit, offset 10

	const uint16 Half_Mantissa_Mask = 0x03FF; // 10 bit, offset 0

	private static uint32 GetSingleSignBit(uint32 singleData)
	{
		return (singleData >> Single_Sign_Shift);
	}

	private static uint32 GetSingleExponent(uint32 singleData)
	{
		return (singleData & Single_Exponent_Mask) >> Single_Exponent_Shift;
	}
	
	private static uint32 GetSingleMantissa(uint32 singleData)
	{
		return (singleData & Single_Mantissa_Mask);
	}
	
	private static uint32 SetSingleSignBit(uint32 singleData, uint32 signBit)
	{
		return ((signBit << Single_Sign_Shift) & Single_Sign_Mask) | (singleData & ~Single_Sign_Mask);
	}

	private static uint32 SetSingleExponent(uint32 singleData, uint32 exponent)
	{
		return ((exponent << Single_Exponent_Shift) & Single_Exponent_Mask) | (singleData & ~Single_Exponent_Mask);
	}

	private static uint32 SetSingleMantissa(uint32 singleData, uint32 mantissa)
	{
		return (mantissa & Single_Mantissa_Mask) | (singleData & ~Single_Mantissa_Mask);
	}

	private static uint16 GetHalfSignBit(uint16 HalfData)
	{
		return (HalfData >> Half_Sign_Shift);
	}

	private static uint16 GetHalfExponent(uint16 HalfData)
	{
		return (HalfData & Half_Exponent_Mask) >> Half_Exponent_Shift;
	}

	private static uint16 GetHalfMantissa(uint16 HalfData)
	{
		return (HalfData & Half_Mantissa_Mask);
	}

	private static uint16 SetHalfSignBit(uint16 HalfData, uint16 signBit)
	{
		return ((signBit << Half_Sign_Shift) & Half_Sign_Mask) | (HalfData & ~Half_Sign_Mask);
	}

	private static uint16 SetHalfExponent(uint16 HalfData, uint16 exponent)
	{
		return ((exponent << Half_Exponent_Shift) & Half_Exponent_Mask) | (HalfData & ~Half_Exponent_Mask);
	}

	private static uint16 SetHalfMantissa(uint16 HalfData, uint16 mantissa)
	{
		return (mantissa & Half_Mantissa_Mask) | (HalfData & ~Half_Mantissa_Mask);
	}

#endregion

	public int GetHashCode()
	{
		return _data;
	}

	public void ToString(String outString)
	{
		ToFloat32(this).ToString(outString);
	}

	public void ToString(String outString, String format, IFormatProvider formatProvider)
	{
		ToFloat32(this).ToString(outString, format, formatProvider);
	}

	public static half operator +(half lhs, half rhs)
	{
		return (half)((float)lhs + (float)rhs);
	}

	public static half operator +(half value) => value;

	public static half operator -(half lhs, half rhs)
	{
		return (half)((float)lhs - (float)rhs);
	}

	public static half operator -(half value)
	{
		uint16 signBit = GetHalfSignBit(value._data);

		// Invert the sign bit (~)
		return half(SetHalfSignBit(value._data, ~signBit));
	}

	public static half operator *(half lhs, half rhs)
	{
		return (half)((float)lhs * (float)rhs);
	}

	public static half operator /(half lhs, half rhs)
	{
		return (half)((float)lhs / (float)rhs);
	}

	public static half operator %(half lhs, half rhs)
	{
		return (half)((float)lhs % (float)rhs);
	}

	public static bool operator==(half value1, half value2) => value1._data == value2._data;

	public static bool operator!=(half value1, half value2) => value1._data != value2._data;

	public static int operator<=>(half value1, half value2) => (float)value1 <=> (float)value2;

	public bool Equals(half other)
	{
		return _data == other._data;
	}
}