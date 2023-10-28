using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Scripting;

enum ScriptFieldType
{
	case None;

	case Class;
	case Enum;
	case Struct;

	case GenericClass;
	case Array;
	
	case Bool;
	
	case SByte;
	case Short;
	case Int, Int2, Int3, Int4;
	case Long;
	case Byte;
	case UShort;
	case UInt; // UInt2, UInt3, UInt4;
	case ULong;
	
	case Float, float2, float3, float4;
	case Double, Double2, Double3, Double4;
	
	case Entity;
	case Component;

	public Type GetBeefType()
	{
		switch(this)
		{
		case .Bool:
			return typeof(bool);

		case .SByte:
			return typeof(int8);
		case .Short:
			return typeof(int16);
		case .Int:
			return typeof(int32);
		case .Int2:
			return typeof(int2);
		case .Int3:
			return typeof(int3);
		case .Int4:
			return typeof(int4);
		case .Long:
			return typeof(int64);
			
		case .Byte:
			return typeof(uint8);
		case .UShort:
			return typeof(uint16);
		case .UInt:
			return typeof(uint32);
		case .ULong:
			return typeof(uint64);
			
		case .Float:
			return typeof(float);
		case .float2:
			return typeof(float2);
		case .float3:
			return typeof(float3);
		case .float4:
			return typeof(float4);
			
		case .Double:
			return typeof(double);
		case .Double2:
			return typeof(double2);
		case .Double3:
			return typeof(double3);
		case .Double4:
			return typeof(double4);

		case .Entity:
			return typeof(UUID);
		case .Component:
			return typeof(UUID);

		default:
			return null;
		}
	}
}