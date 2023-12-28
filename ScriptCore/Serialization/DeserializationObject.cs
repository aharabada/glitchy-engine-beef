using GlitchyEngine.Core;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;

namespace GlitchyEngine.Serialization;

internal class DeserializationObject
{
    private IntPtr _internalContext;

    private UUID _id;

    private Stack<string> _structScope = new();

    private string _structScopeName;

    public Dictionary<UUID, DeserializationObject> DeserializedClasses;

    private object _instance;

    public DeserializationObject(IntPtr internalContext, UUID id, Dictionary<UUID, DeserializationObject> deserializedClasses)
    {
        _internalContext = internalContext;
        _id = id;
        DeserializedClasses = deserializedClasses;
    }

    private Dictionary<string, Type> _fullNameToType = new();

    private Type FindType(string fullName)
    {
        foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies().Reverse())
        {
            Type type = assembly.GetType(fullName);

            if (type != null)
                return type;
        }

        return null;
    }

    private Type GetTypeFromName(string fullName)
    {
        if (_fullNameToType.TryGetValue(fullName, out Type storedType))
            return storedType;

        Type type = FindType(fullName);

        _fullNameToType.Add(fullName, type);

        return type;
    }

    private DeserializationObject GetDeserializedObject(UUID id)
    {
        DeserializationObject context;
        
        if (DeserializedClasses.TryGetValue(id, out context))
            return context;
        
        ScriptGlue.Serialization_GetObject(_internalContext, id, out IntPtr contextPtr);
        
        context = new DeserializationObject(contextPtr, id, DeserializedClasses);
        
        DeserializedClasses.Add(id, context);
        
        ScriptGlue.Serialization_GetObjectTypeName(context._internalContext, out string fullTypeName);
            
        Type type = GetTypeFromName(fullTypeName);

        if (type == null)
            return context;

        try
        {
            context._instance = Activator.CreateInstance(type, true);
        }
        catch (MissingMethodException e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": The type doesn't contain a constructor with zero parameters.\nMake sure the type has a constructor that takes no arguments (It can be private!).\n{e}");
        }
        catch (MethodAccessException e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": The default constructor is not accessible.\n{e}");
        }
        catch (Exception e)
        {
            Log.Error(e);

            return context;
        }

        if (context._instance == null)
            return context;

        context.DeserializeFields(context._instance);

        return context;
    }
    
    private void PushScope(string name)
    {
        _structScope.Push(name);

        _structScopeName += $"{name}.";
    }

    private void PopScope()
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

    private unsafe object GetFieldValue(string fieldName, SerializationType serializationType)
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
                return null;
        }
    }

    public void Deserialize(Entity entity)
    {
        _instance = entity;

        DeserializeFields(entity);
    }
    
    private bool DeserializeFields(object obj)
    {
        Type type = obj.GetType();

        bool changed = false;

        foreach (FieldInfo field in type.GetFields())
        {
            if (!EntitySerializer.SerializeField(field))
                continue;

            changed |= DeserializeField(obj, field);
        }

        return changed;
    }

    private bool DeserializeField(object targetInstance, FieldInfo field)
    {
        Type fieldType = field.FieldType;

        object newFieldValue = null;

        if (fieldType.IsPrimitive)
        {
            newFieldValue = DeserializePrimitive(field.Name, fieldType);
        }
        else if (fieldType == typeof(string))
        {
            newFieldValue = GetFieldValue(field.Name, SerializationType.String);
        }
        else if (fieldType.IsEnum)
        {
            newFieldValue = DeserializeEnum(field.Name, fieldType);
        }
        else if (fieldType.IsArray)
        {
        //    Log.Error($"Array serialization not yet implemented");
        }
        else if (fieldType.IsGenericType)
        {
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                //SerializeList(fieldName, type, o);
                Log.Error($"List serialization not yet implemented");
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
            object structValue = field.GetValue(targetInstance);

            newFieldValue = DeserializeStruct(field.Name, structValue);
        }
        else if (fieldType.IsClass)
        {
            newFieldValue = DeserializeClass(field.Name, fieldType);
        }
        else
        {
            Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");
        }

        if (newFieldValue != null)
        {
            field.SetValue(targetInstance, newFieldValue);
            return true;
        }

        return false;
    }

    private object DeserializePrimitive(string fieldName, Type fieldType)
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

    private object DeserializeEnum(string fieldName, Type enumType)
    {
        if (GetFieldValue(fieldName, SerializationType.Enum) is not string valueName)
            return null;

        try
        {
            return Enum.Parse(enumType, valueName);
        }
        catch
        {
            Log.Error($"Failed to parse \"{valueName}\" as enum-type \"{enumType}\"");
        }

        return null;
    }

    private object DeserializeStruct(string fieldName, object targetInstance)
    {
        PushScope(fieldName);

        bool changed = DeserializeFields(targetInstance);
        
        PopScope();

        return changed ? targetInstance : null;
    }

    private unsafe object DeserializeClass(string fieldName, Type fieldType)
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
                return null;

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

            DeserializationObject deserializedObject = GetDeserializedObject(id);

            return deserializedObject._instance;
        }
    }
}
