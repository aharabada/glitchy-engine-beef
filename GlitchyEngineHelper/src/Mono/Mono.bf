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
	public static extern char8* mono_metadata_string_heap(MonoImage *meta, uint32 table_index);

	typealias gconstpointer = void*;

	[LinkName(.C)]
	public static extern void mono_add_internal_call(char8* name, gconstpointer method);
	
	[LinkName(.C)]
	public static extern MonoString* mono_string_new(MonoDomain* domain, char8* text);
	
	[LinkName(.C)]
	public static extern MonoDomain* mono_domain_get();

	[LinkName(.C)]
	public static extern MonoClass* mono_class_from_name(MonoImage* image, char8* name_space,
		char8* name);

	[LinkName(.C)]
	public static extern MonoClass* mono_class_load_from_name(MonoImage* image, char8* name_space,
		char8* name);

	[LinkName(.C)]
	public static extern MonoObject* mono_object_new(MonoDomain* domain, MonoClass* klass);
	
	[LinkName(.C)]
	public static extern void mono_runtime_object_init(MonoObject* this_obj);

	[LinkName(.C)]
	public static extern MonoMethod* mono_class_get_method_from_name(MonoClass* klass, char8* name, int param_count);

	[LinkName(.C)]
	public static extern MonoObject* mono_runtime_invoke(MonoMethod* method, void* obj, void** param, MonoObject** exc);
	
	[LinkName(.C)]
	public static extern void* mono_object_unbox(MonoObject* obj);
	
	[LinkName(.C)]
	public static extern void* mono_domain_unload(MonoDomain* domain);
}

struct MonoDomain;

struct MonoAssembly;

struct MonoImage;

struct MonoTableInfo;

struct MonoString;

struct MonoClass;

struct MonoObject;

struct MonoMethod;

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