// Based on the Decimal implementation from the Mono Runtime: https://github.com/mono/mono/blob/0f53e9e151d92944cacab3e24ac359410c606df6/mcs/class/referencesource/mscorlib/system/decimal.cs
// Originally licensed under the MIT license.

using System;
using Bon;
using Bon.Integrated;

namespace GlitchyEngine.Scripting;

/// A struct compatible with the Decimal type form the .Net Runtime.
struct Decimal
{
    // Sign mask for the flags field. A value of zero in this bit indicates a
    // positive Decimal value, and a value of one in this bit indicates a
    // negative Decimal value.
    //
    // Look at OleAut's DECIMAL_NEG constant to check for negative values
    // in native code.
    private const uint32 SignMask = 0x80000000u;
	
	// Scale mask for the flags field. This byte in the flags field contains
	// the power of 10 to divide the Decimal value by. The scale byte must
	// contain a value between 0 and 28 inclusive.
	private const uint32 ScaleMask = 0x00FF0000u;

	[Bitfield<uint16>(.Private, .BitsAt(16, 0), "_dontUse", .Read)]
	[Bitfield<uint8>(.Public, .BitsAt(8, 16), "Exponent")]
	[Bitfield<uint8>(.Private, .BitsAt(7, 24), "_dontUse2")]
	[Bitfield<bool>(.Public, .BitsAt(1, 31), "Sign")]
	private uint32 _flags;

	private uint32 _high;
	private uint32 _low;
	private uint32 _mid;

	public uint32[3] Mantissa => .(_low, _mid, _high);

	static this
	{
		gBonEnv.typeHandlers.Add(typeof(Decimal),
			    ((.)new => AssetSerialize, new => AssetDeserialize));
	}

	public this()
	{
		_high = 0;
		_low = 0;
		_mid = 0;
		_flags = 0;
	}
	
	public this(int value)
	{
		var value;
	    if (value >= 0)
	    {
	        _flags = 0;
	    }
	    else
	    {
	        _flags = SignMask;
	        value = -value;
	    }
	    _low = (uint32)value;
	    _mid = (uint32)(value >> 32);
	    _high = 0;
	}

    public this(uint value)
    {
        _flags = 0;
	    _low = (uint32)value;
	    _mid = (uint32)(value >> 32);
        _high = 0;
    }

	static void AssetSerialize(BonWriter writer, ValueView value, BonEnvironment environment, SerializeValueState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Self));

		Decimal decimal = value.Get<Decimal>();

		decimal.ToString(writer.outStr);
	}

	static Result<void> AssetDeserialize(BonReader reader, ValueView value, BonEnvironment environment, DeserializeValueState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Self));

		return .Ok;
	}

	public override void ToString(String strBuffer)
	{
		uint64 d, r;

		uint32[3] a = .(_high, _mid, _low);

		char8[30] str = .();
		char8* ptr = &str[29];

		int digits = 0;

		repeat
		{
		    r = a [0];

		    d = r / 10;
		    r = ((r - d * 10) << 32) + a [1];
		    a [0] = (uint32)d;

		    d = r / 10;
		    r = ((r - d * 10) << 32) + a [2];
		    a [1] = (uint32)d;

		    d = r / 10;
			r = r - d * 10;
			a [2] = (uint32)d;

			*ptr = '0' + (uint8)r;
			ptr--;
			digits++;
			if (digits == Exponent)
			{
				*ptr = '.';
				ptr--;
				digits++;
			}
		}
		while (a[0] > 0 || a[1] > 0 || a[2] > 0 || digits < (Exponent + 2));

		if (Sign)
			strBuffer.Append('-');

		strBuffer.Append(StringView(&str[30 - digits], digits));
		strBuffer.Append('m');
	}

	public static Result<Decimal> Parse(StringView strBuffer)
	{
		var strBuffer;

		Decimal result = .();

		if (strBuffer.StartsWith('-'))
		{
			strBuffer.RemoveFromStart(1);
			result.Sign = true;
		}

		if (strBuffer.EndsWith('m'))
		{
			strBuffer.RemoveFromEnd(1);
		}

		int decimalPointIndex = strBuffer.IndexOf('.');

		if (decimalPointIndex != -1)
		{
			int exponent = strBuffer.Length - decimalPointIndex - 1;

			if (exponent < 0 || exponent > 28)
				return .Err;

			result.Exponent = (uint8)exponent;

			if (strBuffer.IndexOf('.', decimalPointIndex + 1) != -1)
				return .Err;
		}
		
		repeat
		{
			if (strBuffer[0] != '.')
			{
				int32 digit = strBuffer[0] - '0';
	
				if (digit < 0 || digit > 10)
					return .Err;
				
				uint64 tmp, carry;
	
				tmp = result._low * 10;
				carry = (tmp + (uint64)digit) >> 32;
				result._low = (uint32)tmp + (uint32)digit;
				
				tmp = result._mid * 10 + carry;
				carry = tmp >> 32;
				result._mid = (uint32)tmp;
				
				tmp = result._high * 10 + carry;
				carry = tmp >> 32;
				result._high = (uint32)tmp;
			}

			strBuffer.RemoveFromStart(1);
		}
		while (!strBuffer.IsEmpty);

		return .Ok(result);
	}
}
