using GlitchyEngine.Core;
using GlitchyEngine.Scripting;
using Mono;
using System;
using System.Collections;
using Bon.Integrated;
using Bon;
using System.Reflection;

namespace GlitchyEngine.Serialization;

using internal GlitchyEngine.Scripting;

[BonTarget]
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

	public bool IsStatic;

	public String TypeName ~ delete:append _;

	public ScriptInstanceSerializer Serializer;

	private List<String> _ownedString = new List<String>() ~ DeleteContainerAndItems!(_);

	public append Dictionary<StringView, (SerializationType PrimitiveType, FieldData Data)> Fields = .();

	[AllowAppend]
	public this(ScriptInstanceSerializer serializer, bool isStatic, StringView? typeName, UUID? id = null)
	{
		String typeNameCopy = append String(typeName.Value);

		Serializer = serializer;

		IsStatic = isStatic;

		if (id == null)
		{
			// Make sure we have no duplicate keys
			repeat
			{
				Id = UUID.Create();
			}
			while (Serializer.ContainsId(Id));
		}
		else
		{
			Id = id.Value;
		}

		Serializer.AddObject(this);

		TypeName = typeNameCopy;
	}

	private void SetDataSimple(SerializationType fieldType, void* rawValue, ref FieldData data)
	{
		Internal.MemCpy(&data.RawData, rawValue, fieldType.GetSize());
	}

	private void SetRawData<T>(SerializationType fieldType, T rawValue, ref FieldData data)
	{
		#unwarn
		Internal.MemCpy(&data.RawData, &rawValue, fieldType.GetSize());
	}

	private void AddField(StringView fieldName, SerializationType fieldType, FieldData data)
	{
		String nameCopy = new String(fieldName);
		_ownedString.Add(nameCopy);
		
		Fields.Add(nameCopy, (fieldType, data));
	}

	public void AddField(StringView name, SerializationType primitiveType, void* value, StringView fullTypeName)
	{
		FieldData data = .();

		switch (primitiveType)
		{
		case .String, .Enum:
			// If the string is null, we store a nullptr and 0-length
			StringView valueView = StringView(null, 0);

			if (value != null)
			{
				String stringValue = new String((char8*)value);

				_ownedString.Add(stringValue);

				valueView = stringValue;
			}

			data.StringView = valueView;
		case .EngineObjectReference:
			String typeName = null;

			if (!fullTypeName.IsEmpty)
			{
				_ownedString.Add(new String(fullTypeName));
			}

			data.EngineObject = (FullTypeName: typeName, ID: *(UUID*)value);
		default:
			SetDataSimple(primitiveType, value, ref data);
		}

		AddField(name, primitiveType, data);
	}

	/*private void ConvertType(SerializationType fieldType, in FieldData fieldData, SerializationType expectedType, uint8* target)
	{
		#unwarn
		void* rawData = &fieldData.RawData;

		void SimpleConversion<TActual, TExpected>() where TExpected: operator explicit TActual
		{
			TActual actualValue = *(TActual*)rawData;
			*(TExpected*)target = (TExpected)actualValue;
		}

		if (fieldType.IsNumber && expectedType.IsNumber)
		{
			Convert.ConvertTo(Variant.Create(fieldType.));
		}

		switch(fieldType)
		{
		case .Float:
			if (expectedType == .Double)
				SimpleConversion<float, double>();
		case .Double:
			if (expectedType == .Float)
				SimpleConversion<double, float>();
		default:
			Log.EngineLogger.Error($"No field data conversion from {fieldType} to {expectedType}.");
			return;
		}
	}*/

	public void GetField(StringView fieldName, SerializationType expectedType, uint8* target, out SerializationType actualType)
	{
		actualType = .None;

		if (!Fields.TryGetValue(fieldName, let field))
			return;

		actualType = field.PrimitiveType;

		/*if (expectedType != field.PrimitiveType)
		{
			if (field.PrimitiveType.CanConvertTo(expectedType))
			{
				ConvertType(field.PrimitiveType, field.Data, expectedType, target);
			}

			return;
		}*/

		switch (field.PrimitiveType)
		{
		case .String, .Enum:
			*(StringView*)target = field.Data.StringView;
		case .EngineObjectReference:
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
	
	public void Serialize(NewScriptInstance scriptInstance)
	{
		ScriptEngine.Classes.EntitySerializer.Serialize(scriptInstance, this);
	}

	public void Deserialize(NewScriptInstance scriptInstance)
	{
		ScriptEngine.Classes.EntitySerializer.Deserialize(scriptInstance, this);
	}

	public void SerializeStaticFields(NewScriptClass scriptClass)
	{
		ScriptEngine.Classes.EntitySerializer.SerializeStatic(scriptClass, this);
	}

	public void DeserializeStaticFields(NewScriptClass scriptClass)
	{
		ScriptEngine.Classes.EntitySerializer.DeserializeStatic(scriptClass, this);
	}
	
	static this
	{
		gBonEnv.typeHandlers.Add(typeof(SerializedObject),
			    ((.)new => AssetSerialize, null));
	}

	static T GetFieldDataAs<T>(FieldData fieldData)
	{
		return *(T*)&fieldData.RawData;
	}

	static void AssetSerialize(BonWriter writer, ValueView value, BonEnvironment environment, SerializeValueState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Self));

		SerializedObject object = value.Get<Self>();
		
		writer.Type(object.TypeName);

		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, "ID", object.Id, environment);

			for (let (fieldName, field) in object.Fields)
			{
				writer.Identifier(fieldName);
				switch (field.PrimitiveType)
				{
				case .Bool:
					Serialize.Value(writer, GetFieldDataAs<bool>(field.Data), environment);
				case .Char:
					Serialize.Value(writer, GetFieldDataAs<char16>(field.Data), environment);
				case .String:
					if (field.Data.StringView.IsNull)
					{
						writer.Type("string");
					}
					#unwarn
					Serialize.Value(writer, ValueView(typeof(StringView), &field.Data.StringView), environment);

				case .Int8:
					writer.Type("int8");
					Serialize.Value(writer, GetFieldDataAs<int8>(field.Data), environment);
				case .Int16:
					writer.Type("int16");
					Serialize.Value(writer, GetFieldDataAs<int16>(field.Data), environment);
				case .Int32:
					writer.Type("int32");
					Serialize.Value(writer, GetFieldDataAs<int32>(field.Data), environment);
				case .Int64:
					writer.Type("int64");
					Serialize.Value(writer, GetFieldDataAs<int64>(field.Data), environment);
				case .UInt8:
					writer.Type("uint8");
					Serialize.Value(writer, GetFieldDataAs<uint8>(field.Data), environment);
				case .UInt16:
					writer.Type("uint16");
					Serialize.Value(writer, GetFieldDataAs<uint16>(field.Data), environment);
				case .UInt32:
					writer.Type("uint32");
					Serialize.Value(writer, GetFieldDataAs<uint32>(field.Data), environment);
				case .UInt64:
					writer.Type("uint64");
					Serialize.Value(writer, GetFieldDataAs<uint64>(field.Data), environment);

				case .Float:
					writer.Type("float");
					Serialize.Value(writer, GetFieldDataAs<float>(field.Data), environment);
				case .Double:
					writer.Type("double");
					Serialize.Value(writer, GetFieldDataAs<double>(field.Data), environment);
				case .Decimal:
					writer.Type("decimal");
					Serialize.Value(writer, GetFieldDataAs<MonoDecimal>(field.Data), environment);

				case .Enum:
					writer.Type("Enum");
					#unwarn
					Serialize.Value(writer, ValueView(typeof(StringView), &field.Data.StringView), environment);
				case .EngineObjectReference:
					writer.Type("EngineObject");
					if (field.Data.EngineObject.FullTypeName != null)
						writer.Type(field.Data.EngineObject.FullTypeName);
					Serialize.Value(writer, field.Data.EngineObject.ID, environment);
				case .ObjectReference:
					writer.outStr.Append('&');
					GetFieldDataAs<UUID>(field.Data).ToString(writer.outStr);
					writer.EntryEnd();
				default:
					Log.EngineLogger.Warning("Unhandled primitive type");
				}
			}
		}



		//AssetHandle.[Friend]AssetSerialize(writer, ValueView(typeof(AssetHandle), &handle), environment, state);

	    //writer.String(identifier);
	}

	private static Result<StringView> NestedIdentifier(BonReader reader)
	{
		let name = ParseNestedName(reader);
		if (name.Length == 0)
			reader.[Friend]Error!("Expected identifier name");

		Try!(reader.ConsumeEmpty());

		if (!reader.[Friend]Check('='))
			reader.[Friend]Error!("Expected equals");

		Try!(reader.ConsumeEmpty());

		return name;
	}

	private static StringView ParseNestedName(BonReader reader)
	{
		var nameLen = 0;
		for (; nameLen < reader.inStr.Length; nameLen++)
		{
			let char = reader.inStr[nameLen];
			if (!char.IsLetterOrDigit && char != '_' && char != '.')
				break;
		}

		let name = reader.inStr.Substring(0, nameLen);
		reader.inStr.RemoveFromStart(nameLen);
		return name;
	}

	public static Result<SerializedObject> BonDeserialize(BonReader reader, ScriptInstanceSerializer scriptSerializer, int sceneFileVersion, BonEnvironment environment = gBonEnv)
	{
		StringView type = Try!(reader.Type());

		Try!(reader.ObjectBlock());
		
		Try!(Deserialize.Value<UUID>(reader, "ID", let objectId, environment));

		SerializedObject object = new SerializedObject(scriptSerializer, false, type, objectId);

		while (reader.ObjectHasMore())
		{
			// TODO: Consume until we hit a comma. In case the current field couldn't be deserialized
			Try!(reader.EntryEnd());

			FieldData fieldData = .();
			SerializationType fieldType = .None;

			StringView fieldName = Try!(NestedIdentifier(reader));

			StringView fieldTypeName = String.Empty;

			if (reader.IsTyped())
			{
				fieldTypeName = reader.Type();
			}

			HandleField: do
			{
				if (!fieldTypeName.IsWhiteSpace)
				{
					if (fieldTypeName == "float")
					{
						float floatValue = 0.0f;
	
						Deserialize.[Friend]Float!(typeof(float), reader, ValueView(typeof(float), &floatValue));
						fieldType = .Float;
						object.SetRawData(fieldType, floatValue, ref fieldData);

						break HandleField;
					}
					else if (fieldTypeName == "double")
					{
						double doubleValue = 0.0f;
	
						Deserialize.[Friend]Float!(typeof(double), reader, ValueView(typeof(double), &doubleValue));
						fieldType = .Double;
						object.SetRawData(fieldType, doubleValue, ref fieldData);
						
						break HandleField;
					}
					else if (fieldTypeName.StartsWith("int"))
					{
						int64 intValue = 0;
	
						Deserialize.[Friend]Integer!(typeof(int64), reader, ValueView(typeof(int64), &intValue));
	
						if (fieldTypeName.EndsWith("8"))
						{
							fieldType = .Int8;
							object.SetRawData(fieldType, (int8)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("16"))
						{
							fieldType = .Int16;
							object.SetRawData(fieldType, (int16)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("32"))
						{
							fieldType = .Int32;
							object.SetRawData(fieldType, (int32)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("64"))
						{
							fieldType = .Int64;
							object.SetRawData(fieldType, (int64)intValue, ref fieldData);
						}
						else
						{
							Log.ClientLogger.Error($"Unknown integer type {fieldTypeName}");
						}
						
						break HandleField;
					}
					else if (fieldTypeName.StartsWith("uint"))
					{
						uint64 intValue = 0;
	
						Deserialize.[Friend]Integer!(typeof(uint64), reader, ValueView(typeof(uint64), &intValue));
	
						if (fieldTypeName.EndsWith("8"))
						{
							fieldType = .UInt8;
							object.SetRawData(fieldType, (uint8)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("16"))
						{
							fieldType = .UInt16;
							object.SetRawData(fieldType, (uint16)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("32"))
						{
							fieldType = .UInt32;
							object.SetRawData(fieldType, (uint32)intValue, ref fieldData);
						}
						else if (fieldTypeName.EndsWith("64"))
						{
							fieldType = .UInt64;
							object.SetRawData(fieldType, (uint64)intValue, ref fieldData);
						}
						else
						{
							Log.ClientLogger.Error($"Unknown integer type {fieldTypeName}");
						}
						
						break HandleField;
					}
					else if (fieldTypeName == "decimal")
					{
						StringView numberView = Try!(reader.Floating());
	
						if (reader.inStr.StartsWith('m'))
							reader.inStr.RemoveFromStart(1);
	
						MonoDecimal decimalValue = Try!(MonoDecimal.Parse(numberView));
						fieldType = .Decimal;
						object.SetRawData(fieldType, decimalValue, ref fieldData);
						
						break HandleField;
					}
					else if (fieldTypeName == "Enum")
					{
						String enumValue = new .();
						Deserialize.String!(reader, ref enumValue, environment);
	
						object._ownedString.Add(enumValue);
						fieldData.StringView = enumValue;
						fieldType = .Enum;
						
						break HandleField;
					}
	                else if (fieldTypeName == "EngineObject")
					{
						String entityTypeName = null;
	
						if (reader.IsTyped())
						{
							StringView entityTypeNameView = Try!(reader.Type());
		
							entityTypeName = new String(entityTypeNameView);
		
							object._ownedString.Add(entityTypeName);
						}
	
						// Object Reference
						uint64 id = 0;
	
						Deserialize.[Friend]Integer!(typeof(uint64), reader, ValueView(typeof(uint64), &id));
	
						UUID reference = UUID(id);
						fieldType = .EngineObjectReference;
						fieldData.EngineObject = (FullTypeName: entityTypeName, ID: reference);
						
						break HandleField;
					}
				}

				if (Deserialize.IsBool(reader))
				{
					bool boolValue = Try!(reader.Bool());
					fieldType = .Bool;
					object.SetDataSimple(fieldType, &boolValue, ref fieldData);
				}
				else if (reader.[Friend]Check('\'', false))
				{
					char32 c = Try!(reader.Char());
	
					fieldType = .Char;
					object.SetDataSimple(fieldType, &c, ref fieldData);
				}
				else if (reader.[Friend]Check('"', false) || fieldTypeName == "string")
				{
					if (reader.inStr.StartsWith("null"))
					{
						fieldData.StringView = null;
						fieldType = .String;
						reader.inStr.RemoveFromStart(4);
					}
					else
					{
						String target = new .();
						Deserialize.String!(reader, ref target, environment);
		
						object._ownedString.Add(target);
						fieldData.StringView = target;
						fieldType = .String;
					}
				}
				// else if (Deserialize.IsNumber(reader, let numberType))
				// {
				// 	if (numberType == .Double)
				// 	{
				// 		double double = Try!(Deserialize.ParseFloat<double>());
				// 		fieldType = .Double;
				// 		object.SetDataSimple(fieldType, &reference, ref fieldData);
				// 	}
				// 	else if (numberType == .Float)
				// 	{
				// 		float double = Try!(Deserialize.ParseFloat<float>());
				// 		fieldType = .Float;
				// 		object.SetDataSimple(fieldType, &reference, ref fieldData);
				// 	}
				// 	else if (numberType == .Integer)
				// 	{
				// 		bool isNegative = false;
	
				// 		if (reader.inStr.StartsWith('-'))
				// 		{
				// 			isNegative = true;
				// 		}
	
				// 		float double = Try!(Deserialize.ParseInt<u>());
				// 		fieldType = .Float;
				// 		object.SetDataSimple(fieldType, &reference, ref fieldData);
				// 	}
				// }
				else if (reader.IsReference())
				{
					// Object Reference
					StringView referenceView = Try!(reader.Reference());
	
					let referenceResult = uint64.Parse(referenceView);
	
					if (referenceResult case .Ok(let referenceInt))
					{
						UUID reference = UUID(referenceInt);
						fieldType = .ObjectReference;
						object.SetRawData(fieldType, reference, ref fieldData);
					}
				}
			}

			if (fieldType != .None)
			{
				object.AddField(fieldName, fieldType, fieldData);
			}

			Try!(reader.ConsumeEmpty());
		}

		Try!(reader.ObjectBlockEnd());

		return .Ok(object);
	}
}
