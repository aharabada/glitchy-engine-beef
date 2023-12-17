using System;
using System.Runtime.CompilerServices;

namespace GlitchyEngine.Math;

/// <summary>
/// Represents a 16-bit floating point number. (IEEE 754 half-precision binary floating-point (binary16))
/// </summary>
/// <remarks>
/// Even though it is possible, it's not recommended to perform calculations using this type directly, because most operators will simply cast the operands to <see cref="float"/> and cast the result back to <see cref="Half"/>.
/// </remarks>
public struct Half : IComparable , IComparable<Half>, IConvertible, IEquatable<Half>, IFormattable
{
    public static readonly Half MinValue = new(-65504); // Should be 0xFBFF
    public static readonly Half MaxValue = new(65504); // Should be 0x7BFF

    // The numbers for Inifnity, NaN and Zero need to be hardcoded as binaries,
    // because the conversion intself relies on them.

    public static readonly Half PositiveInfinity = new(0x7C00);
    public static readonly Half NegativeInfinity = new(0xFC00);
    public static readonly Half NaN = new(0x7CFF);
	
    public static readonly Half Zero = new(0x0000);
    public static readonly Half NegativeZero = new(0x8000);

    private ushort _data;
    
    public bool IsNegative => IsNegative_Impl(this);

    public bool IsFinite => IsFinite_Impl(this);
    public bool IsInfinity => IsInfinity_Impl(this);
    public bool IsPositiveInfinity => _data == PositiveInfinity._data;
    public bool IsNegativeInfinity => _data == NegativeInfinity._data;
    public bool IsNaN => IsNan_Impl(this);

    public bool IsSubnormal => IsSubnormal_Impl(this);

    public Half(float value)
    {
        FromFloat32(value, out Half halfValue);
        this = halfValue;
    }

    private Half(ushort data)
    {
        _data = data;
    }

    public static explicit operator float(Half value)
    {
        ToFloat32(value, out float floatValue);
        return floatValue;
    }

    public static explicit operator Half(float value)
    {
        FromFloat32(value, out Half halfValue);
        return halfValue;
    }

    /// <summary>Converts the numeric value of this instance to its equivalent string representation.</summary>
    /// <returns>The string representation of the value of this instance.</returns>
    public override string ToString() => ((float)this).ToString();

    public int CompareTo(object obj)
    {
        if (obj == null)
            return 1;

        if (obj is not Half value)
            throw new ArgumentException($"Object must be of type {typeof(Half)}");

        return CompareTo(value);
    }
    
    public int CompareTo(Half other)
    {
        return ((float)this).CompareTo((float)other);
    }

    public TypeCode GetTypeCode() => TypeCode.Object;

    public bool ToBoolean(IFormatProvider provider) => Convert.ToBoolean((float)this, provider);

    public byte ToByte(IFormatProvider provider) => Convert.ToByte((float)this, provider);

    public char ToChar(IFormatProvider provider) => Convert.ToChar((float)this, provider);

    public DateTime ToDateTime(IFormatProvider provider) => Convert.ToDateTime((float)this, provider);

    public decimal ToDecimal(IFormatProvider provider) => Convert.ToDecimal((float)this, provider);

    public double ToDouble(IFormatProvider provider) => Convert.ToDouble((float)this, provider);

    public short ToInt16(IFormatProvider provider) => Convert.ToInt16((float)this, provider);

    public int ToInt32(IFormatProvider provider) => Convert.ToInt32((float)this, provider);

    public long ToInt64(IFormatProvider provider) => Convert.ToInt64((float)this, provider);

    public sbyte ToSByte(IFormatProvider provider) => Convert.ToSByte((float)this, provider);

    public float ToSingle(IFormatProvider provider) => Convert.ToSingle((float)this, provider);

    /// <summary>Converts the numeric value of this instance to its equivalent string representation using the specified culture-specific format information.</summary>
    /// <param name="provider">An object that supplies culture-specific formatting information.</param>
    /// <returns>The string representation of the value of this instance as specified by <paramref name="provider">provider</paramref>.</returns>
    public string ToString(IFormatProvider provider) => ((float)this).ToString(provider);
    
    /// <summary>Converts the numeric value of this instance to its equivalent string representation, using the specified format.</summary>
    /// <param name="format">A numeric format string.</param>
    /// <returns>The string representation of the value of this instance as specified by <paramref name="format">format</paramref>.</returns>
    /// <exception cref="T:System.FormatException"><paramref name="format">format</paramref> is invalid.</exception>
    public string ToString(string format) => ((float)this).ToString(format);

    /// <summary>Converts the numeric value of this instance to its equivalent string representation using the specified format and culture-specific format information.</summary>
    /// <param name="format">A numeric format string.</param>
    /// <param name="provider">An object that supplies culture-specific formatting information.</param>
    /// <returns>The string representation of the value of this instance as specified by <paramref name="format">format</paramref> and <paramref name="provider">provider</paramref>.</returns>
    public string ToString(string format, IFormatProvider provider) => ((float)this).ToString(format, provider);

    public object ToType(Type conversionType, IFormatProvider provider) => ((IConvertible)(float)this).ToType(conversionType, provider);

    public ushort ToUInt16(IFormatProvider provider) => Convert.ToUInt16((float)this, provider);

    public uint ToUInt32(IFormatProvider provider) => Convert.ToUInt32((float)this, provider);

    public ulong ToUInt64(IFormatProvider provider) => Convert.ToUInt64((float)this, provider);

    public bool Equals(Half other)
    {
        return _data == other._data;
    }
    
    public override bool Equals(object obj)
    {
        return obj is Half other && Equals(other);
    }

    public override int GetHashCode()
    {
        return _data.GetHashCode();
    }

    #region Operators

    public static bool operator ==(Half left, Half right) => left._data == right._data;

    public static bool operator !=(Half left, Half right) => left._data != right._data;
    
    public static bool operator <(Half left, Half right)
    {
        LessThan_Impl(left, right, out bool result);
        return result;
    }
    
    public static bool operator <=(Half left, Half right)
    {
        LessThanOrEqual_Impl(left, right, out bool result);
        return result;
    }
    public static bool operator >(Half left, Half right)
    {
        GreaterThan_Impl(left, right, out bool result);
        return result;
    }
    
    public static bool operator >=(Half left, Half right)
    {
        GreaterThanOrEqual_Impl(left, right, out bool result);
        return result;
    }

    public static Half operator +(Half value) => value;

    public static Half operator -(Half value)
    {
        Negate_Impl(value, out Half result);
        return result;
    }

    public static Half operator +(Half left, Half right)
    {
        Add_Impl(left, right, out Half result);
        return result;
    }

    public static Half operator -(Half left, Half right)
    {
        Subtract_Impl(left, right, out Half result);
        return result;
    }

    public static Half operator *(Half left, Half right)
    {
        Multiply_Impl(left, right, out Half result);
        return result;
    }

    public static Half operator /(Half left, Half right)
    {
        Divide_Impl(left, right, out Half result);
        return result;
    }

    public static Half operator %(Half left, Half right)
    {
        Modulo_Impl(left, right, out Half result);
        return result;
    }

    public static Half operator ++(Half value)
    {
        Increment_Impl(value, out Half result);
        return result;
    }

    public static Half operator --(Half value)
    {
        Decrement_Impl(value, out Half result);
        return result;
    }
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void LessThan_Impl(Half left, Half right, out bool result);
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void LessThanOrEqual_Impl(Half left, Half right, out bool result);
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void GreaterThan_Impl(Half left, Half right, out bool result);
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void GreaterThanOrEqual_Impl(Half left, Half right, out bool result);

    // Externe Methoden hier als Platzhalter
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Add_Impl(Half left, Half right, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Subtract_Impl(Half left, Half right, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Multiply_Impl(Half left, Half right, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Divide_Impl(Half left, Half right, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Modulo_Impl(Half left, Half right, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Negate_Impl(Half value, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Increment_Impl(Half value, out Half result);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void Decrement_Impl(Half value, out Half result);

    #endregion

    #region Bindings

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void FromFloat32(float value, out Half halfValue);

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void ToFloat32(Half value, out float floatValue);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern bool IsNegative_Impl(Half self);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern bool IsFinite_Impl(Half self);
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern bool IsInfinity_Impl(Half self);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern bool IsNan_Impl(Half self);
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern bool IsSubnormal_Impl(Half self);

    #endregion
}
