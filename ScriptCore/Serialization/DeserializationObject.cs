using GlitchyEngine.Core;
using GlitchyEngine.Extensions;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.Tracing;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using GlitchyEngine.Editor;

namespace GlitchyEngine.Serialization;

public class DeserializationObject
{
    public class NoObject
    {

    }

    /// <summary>
    /// Object used to specify, that no particular value was deserialized for the field and thus the value currently stored shall not be changed.
    /// </summary>
    public static readonly NoObject NoValueDeserialized = new ();

    private IntPtr _internalContext;

    private bool _isStatic;
    
    private UUID _id;

    private Stack<string> _structScope = new();

    private string _structScopeName = "";

    public Dictionary<UUID, DeserializationObject> DeserializedClasses;

    private object? _instance;
    
    private Dictionary<string, Type?> _fullNameToType = new();

    private delegate object? DeserializeMethod(DeserializationObject container, string fieldName, Type fieldType);

    private static Dictionary<Type, DeserializeMethod> _customDeserializers = new();

    /// <summary>
    /// Gets the type that was originally stored in the container, or null, if the type doesn't exist.
    /// </summary>
    public Type? StoredType
    {
        get
        {
            ScriptGlue.Serialization_GetObjectTypeName(_internalContext, out string fullTypeName);

            return GetTypeFromName(fullTypeName);
        }
    }

    public bool IsStatic => _isStatic;
    
    public DeserializationObject(IntPtr internalContext, bool isStatic, UUID id, Dictionary<UUID, DeserializationObject> deserializedClasses)
    {
        _internalContext = internalContext;
        _isStatic = isStatic;
        _id = id;
        DeserializedClasses = deserializedClasses;
    }
    
    static DeserializationObject()
    {
        foreach (Type type in TypeExtension.EnumerateAllTypes())
        {
            if (type.TryGetCustomAttribute<CustomSerializerAttribute>(out var attribute))
            {
                MethodInfo? deserializeMethod = type.GetMethod("Deserialize", BindingFlags.Static | BindingFlags.Public,
                    null,
                    new []{ typeof(DeserializationObject), typeof(string), typeof(Type) }, null);

                if (deserializeMethod == null)
                {
                    Log.Error($"No Deserialize-method found for type {type}");
                }
                else
                {
                    DeserializeMethod method = deserializeMethod.GetDelegate<DeserializeMethod>();

                    _customDeserializers.Add(attribute.Type, method);
                }
            }
        }
    }
    
    public Type? GetTypeFromName(string fullName)
    {
        if (_fullNameToType.TryGetValue(fullName, out Type? storedType))
            return storedType;

        Type? type = TypeExtension.FindType(fullName);
        
        _fullNameToType.Add(fullName, type);

        return type;
    }

    public DeserializationObject? GetDeserializedObject(UUID id)
    {
        DeserializationObject context;
        
        if (DeserializedClasses.TryGetValue(id, out context))
            return context;
        
        ScriptGlue.Serialization_GetObject(_internalContext, id, out IntPtr contextPtr);

        if (contextPtr == IntPtr.Zero)
        {
            return null;
        }

        context = new DeserializationObject(contextPtr, false, id, DeserializedClasses);
        
        DeserializedClasses.Add(id, context);
        
        return context;
    }
    
    public void PushScope(string name)
    {
        _structScope.Push(name);

        _structScopeName += $"{name}.";
    }

    public void PopScope()
    {
        string scopeToRemove = _structScope.Pop();
        _structScopeName = _structScopeName.Remove(_structScopeName.Length - scopeToRemove.Length - 1);
    }

    [StructLayout(LayoutKind.Explicit)]
    private unsafe struct DataHelper
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct EngineObjectReferenceHelper
        {
            public byte* FullTypeName;
            public long FullTypeNameLength;
            public UUID Id;
        }
        
        [FieldOffset(0)]
        public EngineObjectReferenceHelper EngineObjectReference;

        [FieldOffset(0)]
        public ulong UInt;

        [FieldOffset(0)]
        public long Int;

        [FieldOffset(0)]
        public UUID UUID;
    }

    public T? GetFieldValue<T>(string fieldName, SerializationType expectedType)
    {
        return (T?)GetFieldValue(fieldName, expectedType);
    }

    public unsafe object? GetFieldValue(string fieldName, SerializationType expectedType)
    {
        string completeFieldName = $"{_structScopeName}{fieldName}";

        // Decimal is the larges primitive we store so we use a decimal as stack allocated memory (because stackalloc doesn't seem to work :(
        //decimal backingFieldOnStack = 0.0m;
        //byte* rawData = (byte*)&backingFieldOnStack;
        
        //byte* rawData = stackalloc byte[sizeof(DataHelper)];
        //ref DataHelper dataHelper = ref Unsafe.AsRef<DataHelper>(rawData);

        DataHelper dataHelper = new();
        byte* rawData = (byte*)Unsafe.AsPointer(ref dataHelper);

        // //byte* rawData = stackalloc byte[sizeof(DataHelper)];
        // //ref DataHelper dataHelper = ref Unsafe.AsRef<DataHelper>(rawData);

        ScriptGlue.Serialization_DeserializeField(_internalContext, expectedType, completeFieldName, rawData, out SerializationType actualType);

        string? GetString()
        {
            // rawData contains a Pointer and a string length!
            byte* utf8Ptr = *(byte**)rawData;

            if (utf8Ptr == null)
                return null;
            
            ulong length = *(ulong*)(rawData + 8);

            if (length == 0)
                return string.Empty;

            return Encoding.UTF8.GetString(utf8Ptr, (int)length);
        }

        object? value = actualType switch
        {
            SerializationType.Bool => *(bool*)rawData,
            SerializationType.Char => *(char*)rawData,
            SerializationType.String => GetString(),
            SerializationType.Int8 => *(sbyte*)rawData,
            SerializationType.Int16 => *(short*)rawData,
            SerializationType.Int32 => *(int*)rawData,
            SerializationType.Int64 => *(long*)rawData,
            SerializationType.UInt8 => *(byte*)rawData,
            SerializationType.UInt16 => *(ushort*)rawData,
            SerializationType.UInt32 => *(uint*)rawData,
            SerializationType.UInt64 => *(ulong*)rawData,
            SerializationType.Float => *(float*)rawData,
            SerializationType.Double => *(double*)rawData,
            SerializationType.Decimal => *(decimal*)rawData,
            SerializationType.Enum => GetString(),
            SerializationType.EntityReference => dataHelper.EngineObjectReference,
            SerializationType.ComponentReference => dataHelper.EngineObjectReference,
            SerializationType.ObjectReference => dataHelper.UUID,
            _ => NoValueDeserialized
        };

        if (actualType != expectedType)
        {
            if (!actualType.CanConvertTo(expectedType))
            {
                return NoValueDeserialized;
            }

            try
            {
                Type? targetType = expectedType.GetTypeInstance();

                return targetType != null ? Convert.ChangeType(value, targetType) : NoValueDeserialized;
            }
            catch (Exception e)
            {
                Log.Error($"Failed to convert type {actualType} to {expectedType}: {e}");
                return NoValueDeserialized;
            }
        }

        return value;
    }

    public void Deserialize(Entity entity)
    {
        _instance = entity;

        DeserializeFields(entity);
    }

    public void Deserialize(Type type)
    {
        _instance = null;

        DeserializeStaticFields(type);
    }
    
    public bool DeserializeStaticFields(Type type)
    {
        bool changed = false;

        foreach (FieldInfo field in type.GetFields(BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public))
        {
            if (!EntitySerializer.SerializeField(field, true))
                continue;

            object currentValue = field.GetValue(null);

            object? deserializeValue = DeserializeField(currentValue, field.FieldType, field.Name);
            
            if (deserializeValue != NoValueDeserialized)
            {
                field.SetValue(null, deserializeValue);
                changed = true;
            }
        }

        return changed;
    }
    
    public bool DeserializeFields(object obj)
    {
        Type type = obj.GetType();

        bool changed = false;

        foreach (FieldInfo field in type.GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
        {
            if (!EntitySerializer.SerializeField(field, false))
                continue;

            object currentValue = field.GetValue(obj);

            object? deserializeValue = DeserializeField(currentValue, field.FieldType, field.Name);
            
            if (deserializeValue != NoValueDeserialized)
            {
                field.SetValue(obj, deserializeValue);
                changed = true;
            }
        }

        return changed;
    }
    
    private bool TryCustomDeserializer(string fieldName, Type fieldType, out object? deserializedValue)
    {
        deserializedValue = NoValueDeserialized;

        try
        {
            // Try to match the concrete type first (e.g. Foo -> Foo and Foo<Bar> -> List<Bar>)
            // Note: Foo<Bar> wont match a serializer for Foo<>
            if (_customDeserializers.TryGetValue(fieldType, out DeserializeMethod deserializeMethod))
            {
                deserializedValue = deserializeMethod(this, fieldName, fieldType);
                return true;
            }
            
            if (fieldType.IsGenericType && _customDeserializers.TryGetValue(fieldType.GetGenericTypeDefinition(), out deserializeMethod))
            {
                deserializedValue = deserializeMethod(this, fieldName, fieldType);
                return true;
            }
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }

        return false;
    }

    public object? DeserializeField(object? fieldValue, Type fieldType, string fieldName)
    {
        if (TryCustomDeserializer(fieldName, fieldType, out object? deserializedValue))
        {
            return deserializedValue;
        }

        if (fieldType.IsPrimitive)
        {
            return DeserializePrimitive(fieldName, fieldType);
        }
        if (fieldType == typeof(string))
        {
            return GetFieldValue(fieldName, SerializationType.String);
        }
        if (fieldType.IsEnum)
        {
            return DeserializeEnum(fieldName, fieldType);
        }
        if (fieldType.IsArray)
        {
            Type? elementType = fieldType.GetElementType();

            if (elementType == null)
                return NoValueDeserialized;

            return DeserializeList(fieldName, fieldType, elementType);
        }
        if (fieldType.IsValueType)
        {
            // Null Value doesn't make any sense, because we need a value to deserialize into!
            Debug.Assert(fieldValue != null);

            return DeserializeStruct(fieldName, fieldValue!);
        }
        if (fieldType.IsClass)
        {
            return DeserializeClass(fieldName, fieldType);
        }

        Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");

        return NoValueDeserialized;
    }

    public object? DeserializePrimitive(string fieldName, Type fieldType)
    {
        Debug.Assert(fieldType.IsPrimitive, $"{fieldType} is not a primitive type.");

        SerializationType expectedType = SerializationType.None;
        
        if (fieldType == typeof(bool))
            expectedType = SerializationType.Bool;
        else if (fieldType == typeof(char))
            expectedType = SerializationType.Char;
        else if (fieldType == typeof(byte))
            expectedType = SerializationType.UInt8;
        else if (fieldType == typeof(sbyte))
            expectedType = SerializationType.Int8;
        else if (fieldType == typeof(ushort))
            expectedType = SerializationType.UInt16;
        else if (fieldType == typeof(short))
            expectedType = SerializationType.Int16;
        else if (fieldType == typeof(uint))
            expectedType = SerializationType.UInt32;
        else if (fieldType == typeof(int))
            expectedType = SerializationType.Int32;
        else if (fieldType == typeof(ulong))
            expectedType = SerializationType.UInt64;
        else if (fieldType == typeof(long))
            expectedType = SerializationType.Int64;
        else if (fieldType == typeof(float))
            expectedType = SerializationType.Float;
        else if (fieldType == typeof(double))
            expectedType = SerializationType.Double;
        else if (fieldType == typeof(decimal))
            expectedType = SerializationType.Decimal;
        else
        {
            Log.Error($"The primitive {fieldType} is not implemented.");
        }

        return GetFieldValue(fieldName, expectedType);
    }

    public object? DeserializeList(string fieldName, Type fieldType, Type elementType)
    {
        UUID id = (UUID)GetFieldValue(fieldName, SerializationType.ObjectReference)!;

        if (id == UUID.Zero)
            return null;
        
        // Get serialization container for the instance
        DeserializationObject? deserializedObject = GetDeserializedObject(id);

        if (deserializedObject == null)
            return NoValueDeserialized;

        Type? type = deserializedObject.StoredType;

        if (type == null || !type.IsAssignableTo(fieldType))
            return null;
        
        int count = deserializedObject.GetFieldValue<int>("Count", SerializationType.Int32);

        Array? array = null;
        IList? list = null;

        if (type.IsArray)
        {
            array = Array.CreateInstance(elementType, count);

            deserializedObject._instance = array;
        }
        else
        {
            Debug.Assert(fieldType.IsAssignableTo(typeof(IList)));

            if (type.GetGenericTypeDefinition() == typeof(List<>))
            {
                list = (IList?)ActivatorExtension.CreateInstanceSafe(type, count);
            }
            else
            {
                list = (IList?)ActivatorExtension.CreateInstanceSafe(type);
            }

            if (list == null)
                return null;
            
            if (list.IsFixedSize)
            {
                Log.Error("Cannot deserialize fixed length lists.");

                return null;
            }

            deserializedObject._instance = list;
        }

        for (int i = 0; i < count; i++)
        {
            object? elementValue = NeedsInstance(elementType) ? ActivatorExtension.CreateInstanceSafe(elementType) : null;

            object? newValue = deserializedObject.DeserializeField(elementValue, elementType, $"{i}");

            if (newValue == NoValueDeserialized)
                newValue = elementValue;

            if (array != null)
                array.SetValue(newValue, i);
            else if (list != null)
                list.Add(newValue);
            else
                Log.Error($"Deserialized element for field {fieldName}, but has no array or list to add it to.");
        }

        return deserializedObject._instance;
    }

    private bool NeedsInstance(Type type)
    {
        if (type.IsClass)
        {
            if (type == typeof(string))
                return false;

            return true;
        }

        return true;
    }

    public object DeserializeEnum(string fieldName, Type enumType)
    {
        if (GetFieldValue(fieldName, SerializationType.Enum) is not string valueName)
            return NoValueDeserialized;

        try
        {
            return Enum.Parse(enumType, valueName);
        }
        catch
        {
            Log.Error($"Failed to parse \"{valueName}\" as enum-type \"{enumType}\"");
        }

        return NoValueDeserialized;
    }

    public object DeserializeStruct(string fieldName, object targetInstance)
    {
        PushScope(fieldName);

        bool changed = DeserializeFields(targetInstance);
        
        PopScope();

        return changed ? targetInstance : NoValueDeserialized;
    }

    public unsafe object? DeserializeClass(string fieldName, Type fieldType)
    {
        if (fieldType.IsGenericType && fieldType.GetGenericTypeDefinition() == typeof(List<>))
        {
            return DeserializeList(fieldName, fieldType, fieldType.GetGenericArguments()[0]);
        }

        bool isEntity = typeof(Entity).IsAssignableFrom(fieldType);
        bool isComponent = fieldType.IsSubclassOf(typeof(Component));

        if (isEntity || isComponent)
        {
            object? fieldData = GetFieldValue(fieldName, isEntity ? SerializationType.EntityReference : SerializationType.ComponentReference);

            if (fieldData is not DataHelper.EngineObjectReferenceHelper data)
                return NoValueDeserialized;

            UUID id = data.Id;

            if (id == UUID.Zero)
                return null;
            
            string fullTypeName = Encoding.UTF8.GetString(data.FullTypeName, (int)data.FullTypeNameLength);

            Type? type = GetTypeFromName(fullTypeName);

            if (type == null)
                return NoValueDeserialized;

            if (isEntity)
            {
                // We have to differentiate between simple Entity references and script instances
                // (because we decided to use the same type for both, so we could have a field Entity which contains a script instance instead of an Entity reference)
                if (type == typeof(Entity))
                    return new Entity(id);

                return Entity.GetScriptReference(id, type);
            }
            else
            {
                Entity entity = new Entity(id);

                return entity.GetComponent(type);
            }
        }
        else
        {
            UUID id = (UUID)GetFieldValue(fieldName, SerializationType.ObjectReference)!;

            if (id == UUID.Zero)
                return null;

            // Get serialization container for the instance
            DeserializationObject? deserializedObject = GetDeserializedObject(id);

            if (deserializedObject == null)
                return NoValueDeserialized;

            Type? type = deserializedObject.StoredType;

            if (type == null)
                return NoValueDeserialized;

            deserializedObject._instance = ActivatorExtension.CreateInstanceSafe(type);

            if (deserializedObject._instance == null)
            {
                Log.Error($"Failed to create instance of type {type} for field {fieldName}");
                return NoValueDeserialized;
            }

            deserializedObject.DeserializeFields(deserializedObject._instance);

            return deserializedObject._instance;
        }
    }
}
