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

    private UUID _id;

    private Stack<string> _structScope = new();

    private string _structScopeName;

    public Dictionary<UUID, DeserializationObject> DeserializedClasses;

    private object _instance;
    
    private Dictionary<string, Type> _fullNameToType = new();

    private delegate object? DeserializeMethod(DeserializationObject container, string fieldName, Type fieldType);

    private static Dictionary<Type, DeserializeMethod> _customDeserializers = new();

    /// <summary>
    /// Gets the type that was originally stored in the container, or null, if the type doesn't exist.
    /// </summary>
    public Type StoredType
    {
        get
        {
            ScriptGlue.Serialization_GetObjectTypeName(_internalContext, out string fullTypeName);

            return GetTypeFromName(fullTypeName);
        }
    }

    public DeserializationObject(IntPtr internalContext, UUID id, Dictionary<UUID, DeserializationObject> deserializedClasses)
    {
        _internalContext = internalContext;
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

    public Type FindType(string fullName)
    {
        foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies().Reverse())
        {
            Type type = assembly.GetType(fullName);

            if (type != null)
                return type;
        }

        return null;
    }

    public Type GetTypeFromName(string fullName)
    {
        if (_fullNameToType.TryGetValue(fullName, out Type storedType))
            return storedType;

        Type type = FindType(fullName);

        _fullNameToType.Add(fullName, type);

        return type;
    }

    public DeserializationObject GetDeserializedObject(UUID id)
    {
        DeserializationObject context;
        
        if (DeserializedClasses.TryGetValue(id, out context))
            return context;
        
        ScriptGlue.Serialization_GetObject(_internalContext, id, out IntPtr contextPtr);
        
        context = new DeserializationObject(contextPtr, id, DeserializedClasses);
        
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
    }

    public T GetFieldValue<T>(string fieldName, SerializationType serializationType)
    {
        return (T)GetFieldValue(fieldName, serializationType);
    }

    public unsafe object GetFieldValue(string fieldName, SerializationType serializationType)
    {
        string completeFieldName = $"{_structScopeName}{fieldName}";

        // Decimal is the larges primitive we store so we use a decimal as stack allocated memory (because stackalloc doesn't seem to work :(
        //decimal backingFieldOnStack = 0.0m;
        byte* rawData = stackalloc byte[sizeof(DataHelper)];
        //byte* rawData = (byte*)&backingFieldOnStack;

        ref DataHelper dataHelper = ref Unsafe.AsRef<DataHelper>(rawData);

        ScriptGlue.Serialization_DeserializeField(_internalContext, serializationType, completeFieldName, rawData);

        string GetString()
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

        switch (serializationType)
        {
            case SerializationType.Bool:
                return *(bool*)rawData;
            case SerializationType.Char:
                return *(char*)rawData;
            case SerializationType.String:
                return GetString();
            case SerializationType.Int8:
                return *(sbyte*)rawData;
            case SerializationType.Int16:
                return *(short*)rawData;
            case SerializationType.Int32:
                return *(int*)rawData;
            case SerializationType.Int64:
                return *(long*)rawData;
            case SerializationType.UInt8:
                return *(byte*)rawData;
            case SerializationType.UInt16:
                return *(ushort*)rawData;
            case SerializationType.UInt32:
                return *(uint*)rawData;
            case SerializationType.UInt64:
                return *(ulong*)rawData;

            case SerializationType.Float:
                return *(float*)rawData;
            case SerializationType.Double:
                return *(double*)rawData;
            case SerializationType.Decimal:
                return *(decimal*)rawData;

            case SerializationType.Enum:
                return GetString();
            case SerializationType.EntityReference:
            case SerializationType.ComponentReference:
                return dataHelper.EngineObjectReference;
            case SerializationType.ObjectReference:
                return *(UUID*)rawData;
            default:
                return NoValueDeserialized;
        }
    }

    public void Deserialize(Entity entity)
    {
        _instance = entity;

        DeserializeFields(entity);
    }
    
    public bool DeserializeFields(object obj)
    {
        Type type = obj.GetType();

        bool changed = false;

        foreach (FieldInfo field in type.GetFields())
        {
            if (!EntitySerializer.SerializeField(field))
                continue;

            object currentValue = field.GetValue(obj);

            object deserializeValue = DeserializeField(currentValue, field.FieldType, field.Name);
            
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
            }   return true;
        }
        catch (Exception e)
        {
            Log.Error(e);
        }

        return false;
    }

    public object DeserializeField(object fieldValue, Type fieldType, string fieldName)
    {
        if (fieldType.IsPrimitive)
        {
            return DeserializePrimitive(fieldName, fieldType);
        }
        else if (fieldType == typeof(string))
        {
            return GetFieldValue(fieldName, SerializationType.String);
        }
        else if (fieldType.IsEnum)
        {
            return DeserializeEnum(fieldName, fieldType);
        }
        else if (fieldType.IsArray)
        {
            return DeserializeList(fieldName, fieldType, fieldType.GetElementType());
        }
        else if (fieldType.IsGenericType)
        {
            if (TryCustomDeserializer(fieldName, fieldType, out object deserializedValue))
            {
                return deserializedValue;
            }
            
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                return DeserializeList(fieldName, fieldType, fieldType.GetGenericArguments()[0]);
            }
             //else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
            //{
            //    ImGui.Text($"{fieldName} Dictionary");
            //}
            else
            {
                // TODO: what to do?
                Log.Error($"Generic class serialization not yet implemented");
            }
        }
        else if (fieldType.IsValueType)
        {
            if (TryCustomDeserializer(fieldName, fieldType, out object deserializedValue))
            {
                return deserializedValue;
            }

            return DeserializeStruct(fieldName, fieldValue);
        }
        else if (fieldType.IsClass)
        { 
            if (TryCustomDeserializer(fieldName, fieldType, out object deserializedValue))
            {
                return deserializedValue;
            }

            return DeserializeClass(fieldName, fieldType);
        }
        else
        {
            Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");
        }

        return NoValueDeserialized;
    }

    public object DeserializePrimitive(string fieldName, Type fieldType)
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

    public object DeserializeList(string fieldName, Type fieldType, Type elementType)
    {
        UUID id = (UUID)GetFieldValue(fieldName, SerializationType.ObjectReference);

        if (id == UUID.Zero)
            return null;
        
        // Get serialization container for the instance
        DeserializationObject deserializedObject = GetDeserializedObject(id);

        Type type = deserializedObject.StoredType;

        if (type == null || !type.IsAssignableTo(fieldType))
            return null;
        
        int count = deserializedObject.GetFieldValue<int>("Count", SerializationType.Int32);

        Array array = null;
        IList list = null;

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
                list = (IList)ActivatorExtension.CreateInstanceSafe(type, count);
            }
            else
            {
                list = (IList)ActivatorExtension.CreateInstanceSafe(type);
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
            object elementValue = ActivatorExtension.CreateInstanceSafe(elementType);

            object newValue = deserializedObject.DeserializeField(elementValue, elementType, $"{i}");

            if (newValue == NoValueDeserialized)
                newValue = elementValue;

            if (array != null)
                array.SetValue(newValue, i);
            else
                list.Add(newValue);
        }

        return deserializedObject._instance;
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

    public unsafe object DeserializeClass(string fieldName, Type fieldType)
    {
        bool isEntity = typeof(Entity).IsAssignableFrom(fieldType);
        bool isComponent = fieldType.IsSubclassOf(typeof(Component));

        if (isEntity || isComponent)
        {
            var data = (DataHelper.EngineObjectReferenceHelper)GetFieldValue(fieldName, isEntity ? SerializationType.EntityReference : SerializationType.ComponentReference);

            UUID id = data.Id;

            if (id == UUID.Zero)
                return null;
            
            string fullTypeName = Encoding.UTF8.GetString(data.FullTypeName, (int)data.FullTypeNameLength);

            Type type = GetTypeFromName(fullTypeName);

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
            UUID id = (UUID)GetFieldValue(fieldName, SerializationType.ObjectReference);

            if (id == UUID.Zero)
                return null;

            // Get serialization container for the instance
            DeserializationObject deserializedObject = GetDeserializedObject(id);
            
            Type type = deserializedObject.StoredType;

            if (type == null)
                return null;

            deserializedObject._instance = ActivatorExtension.CreateInstanceSafe(type);
            
            deserializedObject.DeserializeFields(deserializedObject._instance);

            return deserializedObject._instance;
        }
    }
}
