using System;

namespace Mono;

static class Mono
{
	typealias mono_bool = System.Windows.IntBool;

	[LinkName(.C)]
	public static extern void mono_set_assemblies_path(char8* path);

	[LinkName(.C)]
	public static extern MonoDomain* mono_jit_init(char8* file);

	[LinkName(.C)]
	public static extern void mono_jit_parse_options(int32 argc, char8** argv);

	[LinkName(.C)]
	public static extern void mono_jit_cleanup(MonoDomain* domain);

	[LinkName(.C)]
	public static extern MonoDomain* mono_domain_create_appdomain(char8* friendly_name, char8* configuration_file);

	[LinkName(.C)]
	public static extern mono_bool mono_domain_set(MonoDomain* domain, mono_bool force);

	[LinkName(.C)]
	public static extern MonoImage* mono_image_open_from_data_full(uint8* data, uint32 data_len,
		mono_bool need_copy, MonoImageOpenStatus* status, mono_bool refonly);

	[LinkName(.C)]
	public static extern MonoImage* mono_assembly_get_image(MonoAssembly* assembly);
	
	[LinkName(.C)]
	public static extern void mono_assembly_close(MonoAssembly* assembly);

	[LinkName(.C)]
	public static extern void mono_image_close(MonoImage* image);
	
	[LinkName(.C)]
	public static extern char8* mono_image_strerror(MonoImageOpenStatus status);

	[LinkName(.C)]
	public static extern MonoAssembly* mono_assembly_load_from_full(MonoImage* image, char8* fileName,
					MonoImageOpenStatus* status, mono_bool refonly);

	
	[LinkName(.C)]
	public static extern MonoTableInfo* mono_image_get_table_info(MonoImage* image, MonoMetaTableEnum table_id);
	
	[LinkName(.C)]
	public static extern int32 mono_image_get_table_rows(MonoImage *image, MonoMetaTableEnum table_id);
	
	[LinkName(.C)]
	public static extern int32 mono_table_info_get_rows(MonoTableInfo* table);

	[LinkName(.C)]
	public static extern void mono_metadata_decode_row (MonoTableInfo* t,
				       int32 idx,
				       uint32* res,
				       int32 res_size);

	[LinkName(.C)]
	public static extern char8* mono_metadata_string_heap(MonoImage* meta, uint32 table_index);
	[LinkName(.C)]
	public static extern uint8* mono_metadata_blob_heap(MonoImage* meta, uint32 index);
	[LinkName(.C)]
	public static extern uint32 mono_metadata_decode_blob_size(uint8* xptr, out uint8* newPosition);

	typealias gconstpointer = void*;
	typealias gpointer = void*;

	[LinkName(.C)]
	public static extern void mono_add_internal_call(char8* name, gconstpointer method);
	
	[LinkName(.C)]
	public static extern MonoString* mono_string_new(MonoDomain* domain, char8* text);
	
	[LinkName(.C)]
	public static extern MonoString* mono_string_new_len(MonoDomain* domain, char8* text, uint32 length);

	[LinkName(.C)]
	public static extern MonoDomain* mono_domain_get();

	[LinkName(.C)]
	public static extern MonoClass* mono_class_from_name(MonoImage* image, char8* name_space,
		char8* name);

	[LinkName(.C)]
	public static extern MonoClass* mono_class_from_mono_type(MonoType* type);

	[LinkName(.C)]
	public static extern char8* mono_class_get_name(MonoClass* monoClass);
	
	[LinkName(.C)]
	public static extern MonoType* mono_class_get_type(MonoClass* monoClass);
	
	[LinkName(.C)]
	public static extern int32 mono_class_instance_size(MonoClass* @class);

	[LinkName(.C)]
	public static extern char8* mono_class_get_namespace(MonoClass* monoClass);
	
	[LinkName(.C)]
	public static extern MonoImage* mono_class_get_image(MonoClass* monoClass);

	[LinkName(.C)]
	public static extern MonoClass* mono_class_load_from_name(MonoImage* image, char8* name_space,
		char8* name);

	[LinkName(.C)]
	public static extern MonoObject* mono_object_new(MonoDomain* domain, MonoClass* klass);
	
	[LinkName(.C)]
	public static extern void mono_runtime_object_init(MonoObject* this_obj);

	[LinkName(.C)]
	public static extern MonoMethod* mono_class_get_methods(MonoClass* klass, gpointer* iter);

	[LinkName(.C)]
	public static extern MonoMethod* mono_class_get_method_from_name(MonoClass* klass, char8* name, int param_count);

	[LinkName(.C)]
	public static extern MonoObject* mono_runtime_invoke(MonoMethod* method, void* obj, void** param, MonoObject** exc);
	
	[LinkName(.C)]
	public static extern MonoMethod* mono_object_get_virtual_method(MonoObject* obj, MonoMethod* method);

	[LinkName(.C)]
	public static extern void* mono_object_unbox(MonoObject* obj);
	
	[LinkName(.C)]
	public static extern void* mono_domain_unload(MonoDomain* domain);

	
	[LinkName(.C)]
	public static extern gpointer mono_method_get_unmanaged_thunk(MonoMethod *method);

	[LinkName(.C)]
	public static extern char8* mono_method_get_name(MonoMethod *method);
	
	[LinkName(.C)]
	public static extern MonoMethodSignature* mono_method_signature(MonoMethod *method);

	[LinkName(.C)]
	public static extern uint32 mono_signature_get_param_count(MonoMethodSignature *sig);
	
	[LinkName(.C)]
	public static extern MonoType* mono_signature_get_params(MonoMethodSignature *sig, gpointer *iter);

	[LinkName(.C)]
	public static extern mono_bool mono_class_is_subclass_of(MonoClass *monoClass, MonoClass *parentClass,
		mono_bool check_interfaces);

	[LinkName(.C)]
	public static extern uint32 mono_gchandle_new(MonoObject* obj, mono_bool pinned);
	
	[LinkName(.C)]
	public static extern void mono_gchandle_free(uint32 gchandle);
	
	[LinkName(.C)]
	public static extern char8* mono_string_to_utf8(MonoString *s);
	
	[LinkName(.C)]
	public static extern char8* mono_string_to_utf8_checked(MonoString *s, MonoError* error);
	
	[LinkName(.C)]
	public static extern void mono_free(void* ptr);
	
	[LinkName(.C)]
	public static extern MonoClassField* mono_class_get_field_from_name(MonoClass* monoClass, char8* name);

	[LinkName(.C)]
	public static extern void mono_field_set_value(MonoObject* obj, MonoClassField* field, void* value);

	[LinkName(.C)]
	public static extern MonoType* mono_reflection_type_from_name(char8* name, MonoImage* image);

	[LinkName(.C)]
	public static extern MonoType* mono_reflection_type_get_type(MonoReflectionType* reflectionType);

	[LinkName(.C)]
	public static extern MonoReflectionType* mono_type_get_object(MonoDomain *domain, MonoType *type);

	[LinkName(.C)]
	public static extern MonoClassField* mono_class_get_fields(MonoClass* klass, gpointer* iter);

	[LinkName(.C)]
	public static extern MonoClass* mono_class_get_parent(MonoClass* klass);
	
	[LinkName(.C)]
	public static extern char8* mono_field_get_name(MonoClassField* field);

	[LinkName(.C)]
	public static extern MonoType* mono_field_get_type(MonoClassField* field);

	[LinkName(.C)]
	public static extern MonoClass* mono_field_get_parent(MonoClassField* field);

	[LinkName(.C)]
	public static extern uint32 mono_field_get_flags(MonoClassField* field);

	[LinkName(.C)]
	public static extern uint8* mono_field_get_data(MonoClassField* field);

	[LinkName(.C)]
	public static extern void mono_field_get_value(MonoObject* object, MonoClassField* field, void* value);
	
	[LinkName(.C)]
	public static extern void mono_field_static_get_value(MonoVTable* vt, MonoClassField* field, void* value);

	/// Gets the field as object, boxes the value if it is a valuetype.
	[LinkName(.C)]
	public static extern MonoObject* mono_field_get_value_object(MonoDomain* domain, MonoClassField* field, MonoObject* obj);
	
	[LinkName(.C)]
	public static extern MonoCustomAttrInfo* mono_custom_attrs_from_class(MonoClass *klass);

	[LinkName(.C)]
	public static extern MonoCustomAttrInfo* mono_custom_attrs_from_field(MonoClass* monoClass, MonoClassField* field);
	
	[LinkName(.C)]
	public static extern mono_bool mono_custom_attrs_has_attr(MonoCustomAttrInfo* attributeInfo, MonoClass* attributeClass);

	[LinkName(.C)]
	public static extern MonoObject* mono_custom_attrs_get_attr(MonoCustomAttrInfo* attributeInfo, MonoClass* attributeClass);

	[LinkName(.C)]
	public static extern Mono.MonoTypeEnum mono_type_get_type(MonoType* type);
	
	[LinkName(.C)]
	public static extern char8* mono_type_get_name(MonoType* type);
	
	[LinkName(.C)]
	public static extern char8* mono_type_full_name(MonoType* type);
	
	[LinkName(.C)]
	public static extern MonoClass* mono_type_get_class(MonoType* type);

	/// MonoError

	[LinkName(.C)]
	public static extern void mono_error_cleanup(MonoError* error);

	[LinkName(.C)]
	public static extern mono_bool mono_error_ok(MonoError* error);
	
	[LinkName(.C)]
	public static extern char8* mono_error_get_message(MonoError* error);

	[LinkName(.C)]
	public static extern void mono_debug_init(DebugFormat debugFormat);
	
	[LinkName(.C)]
	public static extern void mono_debug_domain_create(MonoDomain* domain);
	
	[LinkName(.C)]
	public static extern void mono_debug_domain_unload(MonoDomain* domain);

	[LinkName(.C)]
	public static extern void mono_debug_open_image_from_memory(MonoImage *image, uint8* raw_contents, int32 size);

	[LinkName(.C)]
	public static extern void mono_thread_set_main(MonoThread* thread);
	
	[LinkName(.C)]
	public static extern MonoThread* mono_thread_current();

#region Property

	[LinkName(.C)]
	public static extern MonoProperty* mono_class_get_property_from_name(MonoClass *klass, char8* name);
	
	[LinkName(.C)]
	public static extern void mono_property_set_value(MonoProperty *prop, void *obj, void **@params, MonoObject **exc);
	
	[LinkName(.C)]
	public static extern MonoObject* mono_property_get_value(MonoProperty *prop, void *obj, void** @params, MonoObject** exc);

#endregion

#region Exception
	
	[LinkName(.C), NoReturn]
	public static extern void mono_raise_exception(MonoException *ex);

	[LinkName(.C)]
	public static extern char8* mono_exception_get_managed_backtrace(MonoException* exc);
	
	[LinkName(.C)]
	public static extern MonoException* mono_exception_from_name_msg(MonoImage *image, char8* name_space, char8* name, char8* msg);

	[LinkName(.C)]
	public static extern MonoException* mono_get_exception_argument(char8* arg, char8* msg);

	[LinkName(.C)]
	public static extern MonoException* mono_get_exception_invalid_operation(char8* msg);

	[LinkName(.C)]
	public static extern MonoException* mono_get_exception_not_implemented(char8* msg);

#endregion

	[LinkName(.C)]
	public static extern MonoClass* mono_object_get_class(MonoObject* obj);

	
	[LinkName(.C)]
	public static extern mono_bool mono_class_is_enum(MonoClass* @class);

	
	[LinkName(.C)]
	public static extern MonoVTable* mono_class_vtable(MonoDomain* domain, MonoClass* @class);

	
	[LinkName(.C)]
	public static extern MonoObject* mono_value_box(MonoDomain* domain, MonoClass* klass, gpointer value);

#region MonoArray

	typealias uintptr_t = uint;
	typealias intptr_t = int;

	[LinkName(.C)]
	public static extern MonoArray* mono_array_new(MonoDomain *domain, MonoClass *eclass, uintptr_t length);
	
	[LinkName(.C)]
	public static extern MonoArray* mono_array_new_checked(MonoDomain *domain, MonoClass *eclass, uintptr_t length, MonoError *error);

	[LinkName(.C)]
	public static extern MonoArray* mono_array_new_full(MonoDomain *domain, MonoClass *array_class, uintptr_t* lengths, uintptr_t* lower_bounds);
	
	[LinkName(.C)]
	public static extern MonoArray* mono_array_new_full_checked(MonoDomain *domain, MonoClass *array_class, uintptr_t* lengths, uintptr_t* lower_bounds, MonoError *error);

	[LinkName(.C)]
	public static extern void mono_array_full_copy(MonoArray* src, MonoArray* dest);
	
	[LinkName(.C)]
	public static extern MonoArray* mono_array_clone(MonoArray* array);
	
	[LinkName(.C)]
	public static extern MonoArray* mono_array_clone_checked(MonoArray* array, MonoError* error);
	
	[LinkName(.C)]
	public static extern void* mono_array_addr_with_size(MonoArray *array, int32 size, uintptr_t idx);

	[LinkName(.C)]
	public static extern uintptr_t mono_array_length(MonoArray *array);
	
	[Inline]
	public static T* mono_array_addr<T>(MonoArray* array, uintptr_t index)
	{
		return (T*)mono_array_addr_with_size(array, sizeof(T), index);
	}

	[Inline]
	public static T mono_array_get<T>(MonoArray* array, uintptr_t index)
	{
		return *mono_array_addr<T>(array, index);
	}

	[Inline]
	public static void mono_array_set<T>(MonoArray* array, uintptr_t index, T value)
	{
		T* entryPtr = mono_array_addr<T>(array, index);
		*entryPtr = value;
	}

#endregion

#region DebugHelpers
	
	[LinkName(.C)]
	public static extern MonoMethod* mono_method_desc_search_in_class(MonoMethodDesc* desc, MonoClass* klass);

	[LinkName(.C)]
	public static extern MonoMethodDesc* mono_method_desc_new(char8* name, mono_bool include_namespace);

	[LinkName(.C)]
	public static extern void mono_method_desc_free(MonoMethodDesc* decs);

#endregion
}

struct MonoMethodDesc;

struct MonoDomain;

struct MonoAssembly;

struct MonoImage;

struct MonoTableInfo;

struct MonoString;

struct MonoClass;

struct MonoObject;

struct MonoMethod;

struct MonoMethodSignature;

struct MonoProperty;

struct MonoThread;

struct MonoVTable;

struct MonoArray;

struct MonoException
{
	void* _bla;
	void* _bla2;
	void* _bla3;
	public MonoString* Message;
}

struct MonoClassField;

struct MonoType;

struct MonoError
{
	private uint32 bla;
	private void*[12] bla2;
}

struct MonoReflectionType;

struct MonoCustomAttrInfo;

enum MonoImageOpenStatus
{
	Ok,
	Error_Errno,
	MissingAssemblyRef,
	ImageInvalid
}

enum SOME_RANDOM_ENUM{
	MONO_TYPEDEF_FLAGS,
	MONO_TYPEDEF_NAME,
	MONO_TYPEDEF_NAMESPACE,
	MONO_TYPEDEF_EXTENDS,
	MONO_TYPEDEF_FIELD_LIST,
	MONO_TYPEDEF_METHOD_LIST,
	MONO_TYPEDEF_SIZE
}

enum FIELD_TABLE_FLAGS : uint32
{
	MONO_FIELD_FLAGS,
	MONO_FIELD_NAME,
	MONO_FIELD_SIGNATURE,
	MONO_FIELD_SIZE
}

enum MonoMetaTableEnum : int32
{
	MONO_TABLE_MODULE,
	MONO_TABLE_TYPEREF,
	MONO_TABLE_TYPEDEF,
	MONO_TABLE_FIELD_POINTER,
	MONO_TABLE_FIELD,
	MONO_TABLE_METHOD_POINTER,
	MONO_TABLE_METHOD,
	MONO_TABLE_PARAM_POINTER,
	MONO_TABLE_PARAM,
	MONO_TABLE_INTERFACEIMPL,
	MONO_TABLE_MEMBERREF, /* 0xa */
	MONO_TABLE_CONSTANT,
	MONO_TABLE_CUSTOMATTRIBUTE,
	MONO_TABLE_FIELDMARSHAL,
	MONO_TABLE_DECLSECURITY,
	MONO_TABLE_CLASSLAYOUT,
	MONO_TABLE_FIELDLAYOUT, /* 0x10 */
	MONO_TABLE_STANDALONESIG,
	MONO_TABLE_EVENTMAP,
	MONO_TABLE_EVENT_POINTER,
	MONO_TABLE_EVENT,
	MONO_TABLE_PROPERTYMAP,
	MONO_TABLE_PROPERTY_POINTER,
	MONO_TABLE_PROPERTY,
	MONO_TABLE_METHODSEMANTICS,
	MONO_TABLE_METHODIMPL,
	MONO_TABLE_MODULEREF, /* 0x1a */
	MONO_TABLE_TYPESPEC,
	MONO_TABLE_IMPLMAP,
	MONO_TABLE_FIELDRVA,
	MONO_TABLE_ENCLOG,
	MONO_TABLE_ENCMAP,
	MONO_TABLE_ASSEMBLY, /* 0x20 */
	MONO_TABLE_ASSEMBLYPROCESSOR,
	MONO_TABLE_ASSEMBLYOS,
	MONO_TABLE_ASSEMBLYREF,
	MONO_TABLE_ASSEMBLYREFPROCESSOR,
	MONO_TABLE_ASSEMBLYREFOS,
	MONO_TABLE_FILE,
	MONO_TABLE_EXPORTEDTYPE,
	MONO_TABLE_MANIFESTRESOURCE,
	MONO_TABLE_NESTEDCLASS,
	MONO_TABLE_GENERICPARAM, /* 0x2a */
	MONO_TABLE_METHODSPEC,
	MONO_TABLE_GENERICPARAMCONSTRAINT,
	MONO_TABLE_UNUSED8,
	MONO_TABLE_UNUSED9,
	MONO_TABLE_UNUSED10,
	/* Portable PDB tables */
	MONO_TABLE_DOCUMENT, /* 0x30 */
	MONO_TABLE_METHODBODY,
	MONO_TABLE_LOCALSCOPE,
	MONO_TABLE_LOCALVARIABLE,
	MONO_TABLE_LOCALCONSTANT,
	MONO_TABLE_IMPORTSCOPE,
	MONO_TABLE_STATEMACHINEMETHOD,
	MONO_TABLE_CUSTOMDEBUGINFORMATION

//#define MONO_TABLE_LAST MONO_TABLE_CUSTOMDEBUGINFORMATION
//#define MONO_TABLE_NUM (MONO_TABLE_LAST + 1)

}

enum DebugFormat : uint32
{
	None,
	Mono,
	/** Deprecated, the mdb debugger is not longer supported. */
	Debugger
}

enum FieldAttribute
{
	FieldAccessMask = 0x0007,
	CompilerControlled = 0x0000,
	Private = 0x0001,
	FamAndAssem = 0x0002,
	Assembly = 0x0003,
	Family = 0x0004,
	FamOrAssem = 0x0005,
	Public = 0x0006,
	Static = 0x0010,
	InitOnly = 0x0020,
	Literal = 0x0040,
	NotSerialized = 0x0080,
	SpecialName = 0x0200,
	PinvokeImpl = 0x2000,
	/** For runtime use only */
	ReservedMask = 0x9500,
	/** For runtime use only */
	RtSpecialName = 0x0400,
	/** For runtime use only */
	HasFieldMarshal = 0x1000,
	/** For runtime use only */
	HasDefault = 0x8000,
	/** For runtime use only */
	HasFieldRva = 0x0100
}

enum MonoTypeEnum : int32
{
	End = 0x00,       /* End of List */
	Void = 0x01,
	Boolean = 0x02,
	Char = 0x03,
	I1 = 0x04,
	U1 = 0x05,
	I2 = 0x06,
	U2 = 0x07,
	I4 = 0x08,
	U4 = 0x09,
	I8 = 0x0a,
	U8 = 0x0b,
	R4 = 0x0c,
	R8 = 0x0d,
	String = 0x0e,
	Ptr = 0x0f,       /* arg: <type> token */
	Byref = 0x10,       /* arg: <type> token */
	Valuetype = 0x11,       /* arg: <type> token */
	Class = 0x12,       /* arg: <type> token */
	Var = 0x13,	   /* number */
	Array = 0x14,       /* type, rank, boundsCount, bound1, loCount, lo1 */
	Genericinst = 0x15,	   /* <type> <type-arg-count> <type-1> \x{2026} <type-n> */
	Typedbyref = 0x16,
	I = 0x18,
	U = 0x19,
	Fnptr = 0x1b,	      /* arg: full method signature */
	Object = 0x1c,
	SzArray = 0x1d,       /* 0-based one-dim-array */
	Mvar = 0x1e,       /* number */
	CmodReqd = 0x1f,       /* arg: typedef or typeref token */
	CmodOpt = 0x20,       /* optional arg: typedef or typref token */
	Internal = 0x21,       /* CLR internal type */
	Modifier = 0x40,       /* Or with the following types */
	Sentinel = 0x41,       /* Sentinel for varargs method signature */
	Pinned = 0x45,       /* Local var that points to pinned object */
	Enum = 0x55        /* an enumeration */
}
