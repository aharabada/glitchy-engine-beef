using System;
using xxHash;
using System.Collections;
using System.Reflection;
using System.Diagnostics;
using GlitchyEngine.Core;
namespace GlitchyEngine.Content;

struct AssetHandle : IHashable
{
	private UUID _uuid;

	/// Defines an asset that is invalid.
	public const AssetHandle Invalid = .(UUID(0xAAAA'AAAA'AAAA'AAAA));

	/// Create a new random AssetHandle
	public this()
	{
		_uuid = UUID();
	}

	private this(UUID uuid)
	{
		_uuid = uuid;
	}

	[Inline]
	public T Get<T>(IContentManager contentManager = null) where T : Asset
	{
		return Content.GetAsset<T>(this, contentManager);
	}

	public int GetHashCode() => _uuid.GetHashCode();
}

struct AssetHandle<T> where T : Asset
{
	private AssetHandle _handle;
	private IContentManager _contentManager;
	/*
	 * We don't increment/decrement the reference counter since we guarantee that we query for the asset every frame.
	 */
	private T _asset;
	//private uint8 _currentFrame;
	//private uint64 _actualCurrentFrame = 0;

	public const Self Invalid = .();

	public this(AssetHandle handle, IContentManager contentManager = null)
	{
		_handle = handle;

		_asset = handle.Get<T>(contentManager);
		_contentManager = _asset?.ContentManager;
		if (_contentManager == null)
			_contentManager = contentManager;
		//_currentFrame = (uint8)Application.Get().GameTime.FrameCount;
	}

	// Creates a new invalid asset handle
	private this()
	{
		_handle = .Invalid;
		//_currentFrame = 0;
		_contentManager = null;
		_asset = null;
	}

	public static implicit operator Self(AssetHandle handle)
	{
		return Self(handle);
	}

	public static implicit operator AssetHandle(Self handle)
	{
		return handle._handle;
	}
	
	public static implicit operator T(ref Self handle)
	{
		return handle.Get();
	}

	public T Get(IContentManager contentManager = null) mut
	{
		// We only care whether we are in a different frame -> we only compare the lower 8 bits.
		//uint8 actualFrame = (uint8)Application.Get().GameTime.FrameCount;
		//var actualActualFrame = Application.Get().GameTime.FrameCount;

		//if (actualFrame != _currentFrame)
		{
			_asset = Content.GetAsset<T>(_handle, contentManager == null ? _contentManager : contentManager);
			//_currentFrame = actualFrame;
			//_actualCurrentFrame = Application.Get().GameTime.FrameCount;
		}

		return _asset;
	}

	[Comptime, OnCompile(.TypeInit)]
	static void Init()
	{
		for (var field in typeof(T).GetFields(BindingFlags.FlattenHierarchy))
		{
			if (field.IsStatic || !field.IsPublic)
				continue;

			String modifier = field.IsPublic ? "public" : "private";

			String code = scope $"""
				{modifier} {field.FieldType} {field.Name}
				{{
					get mut
					{{
						return Get().{field.Name};
					}}
					set mut
					{{
						Get().{field.Name} = value;
					}}
				}}


				""";

			Compiler.EmitTypeBody(typeof(Self), code);
		}

		Dictionary<StringView, (MethodInfo? Getter, MethodInfo? Setter)> properties = scope .();

		for (var method in typeof(T).GetMethods(BindingFlags.FlattenHierarchy | BindingFlags.Public))
		{
			if (method.IsStatic || !method.IsPublic || method.IsConstructor || method.IsDestructor)
				continue;

			// Filter out destructors
			if (method.Name == "~this")
				continue;

			if (method.Name.StartsWith("get__"))
			{
				StringView name = method.Name;
				name.RemoveFromStart(5);

				if (!properties.TryGetValue(name, var propertyInfo))
				{
					propertyInfo = default;
				}

				propertyInfo.Getter = method;

				properties[name] = propertyInfo;

				continue;
			}
			if (method.Name.StartsWith("set__"))
			{
				StringView name = method.Name;
				name.RemoveFromStart(5);

				if (!properties.TryGetValue(name, var propertyInfo))
				{
					propertyInfo = default;
				}

				propertyInfo.Setter = method;

				properties[name] = propertyInfo;

				continue;
			}

			String modifier = method.IsPublic ? "public" : "private";
			
			String parameters = scope String();
			String arguments = scope String();

			for (int param < method.ParamCount)
			{
				Type paramType = method.GetParamType(param);
				StringView paramName = method.GetParamName(param);
				/*String buffer = scope .();
				method.GetParamsDecl(buffer);*/

				if (param != 0)
				{
					parameters.Append(", ");
					arguments.Append(", ");
				}

				// TODO: Default value
				parameters.AppendF($"{paramType} {paramName}");

				/*if (!buffer.IsEmpty)
				{
					parameters.AppendF($"/*{buffer}*/");
				}*/

				arguments.AppendF($" {paramName}");
			}

			String code = scope $"""
				{modifier} {method.ReturnType} {method.Name}({parameters}) mut
				{{
					return Get().{method.Name}({arguments});
				}}


				""";

			Compiler.EmitTypeBody(typeof(Self), code);
		}

		for (var (propertyName, property) in properties)
		{
			Type propertyType = property.Getter?.ReturnType ?? property.Setter?.GetParamType(0);

			String getter = scope .();
			String setter = scope .();

			if (property.Getter != null)
			{
				getter.AppendF($"""
						get mut
						{{
							return Get().{propertyName};
						}}
					""");
			}
			if (property.Setter != null)
			{
				getter.AppendF($"""

						set mut
						{{
							Get().{propertyName} = value;
						}}
					""");
			}

			String code = scope $"""
				public {propertyType} {propertyName}
				{{
				{getter}{setter}
				}}


				""";

			Compiler.EmitTypeBody(typeof(Self), code);
		}
	}
}
