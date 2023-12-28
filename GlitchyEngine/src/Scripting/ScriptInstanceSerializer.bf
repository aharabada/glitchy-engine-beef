using Mono;
using System.Collections;
using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

public enum SerializationType : int32
{
	case None;

	case Bool;
	
	case Char;
	case String;
	
	case Int8;
	case Int16;
	case Int32;
	case Int64;
	case UInt8;
	case UInt16;
	case UInt32;
	case UInt64;
	
	case Float;
	case Double;
	case Decimal;

	case Enum;
	
	case EntityReference;
	case ComponentReference;
	
	case ObjectReference;

	public int GetSize()
	{
		switch (this)
		{
		case .Bool:
			return 1;
		case .Char:
			return 1;
		case .Int8, .UInt8:
			return 1;
		case .Int16, .UInt16:
			return 2;
		case .Int32, .UInt32:
			return 4;
		case .Int64, .UInt64:
			return 8;
		case .Float:
			return 4;
		case .Double:
			return 8;
		case .Decimal:
			return 16;
		case .EntityReference, .ComponentReference, .ObjectReference:
			return sizeof(UUID);
		case .String:
			return sizeof(StringView);
		case .Enum:
			return sizeof(StringView);
		default:
			return 0;
		}
	}
}

class SerializedObject
{
	[Union]
	public struct FieldData
	{
		public uint8[16] RawData;
		public StringView StringView;
		public (String FullTypeName, UUID ID) EngineObject;
		
		static this()
		{
			// This is important, because we expect 16 Bytes on the C# side
			Compiler.Assert(sizeof(Self) == 16);
		}
	}

	/// ID used to identify the object represented by this SerializedObject. In case that the represented object is a
	/// Script Instance, the ID is the UUID of the Entity, random otherwise.
	/// Todo: This sucks because we don't know all UUIDs beforehand and might accidentally assign the ID of an Entity to some class
	public UUID Id;

	public String TypeName ~ delete:append _;

	public Dictionary<UUID, SerializedObject> AllObjects;

	private List<String> _ownedString = new List<String>() ~ DeleteContainerAndItems!(_);

	public append Dictionary<StringView, (SerializationType PrimitiveType, FieldData Data)> Fields = .();

	[AllowAppend]
	public this(Dictionary<UUID, SerializedObject> allObjects, StringView? typeName, UUID? id = null)
	{
		String typeNameCopy = append String(typeName.Value);

		AllObjects = allObjects;

		if (id == null)
		{
			// Make sure we have no duplicate keys
			repeat
			{
				Id = UUID.Create();
			}
			while (AllObjects.ContainsKey(Id));
		}
		else
		{
			Id = id.Value;
		}

		AllObjects.Add(Id, this);

		TypeName = typeNameCopy;
	}

	public void AddField(StringView name, SerializationType primitiveType, MonoObject* value, MonoString* fullTypeName)
	{
		FieldData data = .();

		switch (primitiveType)
		{
		case .String, .Enum:
			// If the string is null, we store a nullptr and 0-length
			StringView valueView = StringView(null, 0);

			if (value != null)
			{
				MonoString* string = (.)value;
				char8* rawStringValue = Mono.mono_string_to_utf8(string);

				String stringValue = new String(rawStringValue);

				_ownedString.Add(stringValue);

				Mono.mono_free(rawStringValue);

				valueView = stringValue;
			}

			data.StringView = valueView;
		case .EntityReference, .ComponentReference:
			String typeName = null;

			if (fullTypeName != null)
			{
				char8* rawTypeName = Mono.mono_string_to_utf8(fullTypeName);
				typeName = new String(rawTypeName);

				_ownedString.Add(typeName);

				Mono.mono_free(rawTypeName);
			}

			data.EngineObject = (FullTypeName: typeName, ID: *(UUID*)Mono.mono_object_unbox(value));
		default:
			void* rawValue = Mono.mono_object_unbox(value);

			Internal.MemCpy(&data.RawData, rawValue, primitiveType.GetSize());

			String nameCopy = new String(name);
			_ownedString.Add(nameCopy);
		}

		String nameCopy = new String(name);
		_ownedString.Add(nameCopy);
		
		Fields.Add(nameCopy, (primitiveType, data));
	}
	
	public void GetField(StringView fieldName, SerializationType expectedType, uint8* target)
	{
		if (!Fields.TryGetValue(fieldName, let field))
			return;

		if (expectedType != field.PrimitiveType)
			return;

		switch (field.PrimitiveType)
		{
		case .String, .Enum:
			*(StringView*)target = field.Data.StringView;
		case .EntityReference, .ComponentReference:
			let engineObjectData = field.Data.EngineObject;
			
			*(char8**)target = engineObjectData.FullTypeName?.CStr();
			*(int*)(target + sizeof(char8*)) = engineObjectData.FullTypeName?.Length ?? 0;
			*(UUID*)(target + sizeof(char8*) + sizeof(int)) = engineObjectData.ID;
		default:
			// Most values can simply be copied, the conversion will be done in C#
#unwarn
			Internal.MemCpy(target, &field.Data.RawData, sizeof(FieldData));
		}
	}
	
	typealias SerializeMethod = function MonoObject*(MonoObject* entity, void* contextPtr, MonoException** exception);
	typealias DeserializeMethod = function MonoObject*(MonoObject* entity, void* contextPtr, MonoException** exception);

	public void Serialize(ScriptInstance scriptInstance)
	{
		SerializeMethod serialize = (SerializeMethod)ScriptEngine.Classes.EntitySerializer.GetMethodThunk("Serialize", 2);

		void* thisPtr = Internal.UnsafeCastToPtr(this);

		MonoException* exception = null;
		serialize(scriptInstance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, scriptInstance);
	}

	public void Deserialize(ScriptInstance scriptInstance)
	{
		DeserializeMethod deserialize = (DeserializeMethod)ScriptEngine.Classes.EntitySerializer.GetMethodThunk("Deserialize", 2);

		void* thisPtr = Internal.UnsafeCastToPtr(this);

		MonoException* exception = null;
		deserialize(scriptInstance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, scriptInstance);
	}
}
