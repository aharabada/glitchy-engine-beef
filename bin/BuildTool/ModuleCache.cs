using System.Diagnostics.CodeAnalysis;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BuildTool;

[JsonSourceGenerationOptions(WriteIndented = true)]
[JsonSerializable(typeof(Dictionary<string, ModuleInfo>))]
internal partial class SourceGenerationContext : JsonSerializerContext { }

internal class ModuleCache
{
    private Dictionary<string, ModuleInfo> _modules = new();

    public static ModuleCache Load(string filePath)
    {
        if (!File.Exists(filePath))
        {
            return new ModuleCache();
        }

        using FileStream stream = File.OpenRead(filePath);
        Dictionary<string, ModuleInfo>? modules =
            JsonSerializer.Deserialize(stream, SourceGenerationContext.Default.DictionaryStringModuleInfo);

        return new ModuleCache()
        {
            _modules = modules ?? new Dictionary<string, ModuleInfo>()
        };
    }

    public void Save(string filePath)
    {
        using FileStream stream = File.Create(filePath);
        JsonSerializer.Serialize(stream, _modules, SourceGenerationContext.Default.DictionaryStringModuleInfo);
    }

    private static string GetModuleKey(string moduleName, BuildConfig configuration) =>
        $"{moduleName}: {configuration}";

    public void SetModuleInfo(ModuleInfo moduleInfo)
    {
        _modules[GetModuleKey(moduleInfo.Name, moduleInfo.Configuration)] = moduleInfo;
    }

    public ModuleInfo GetModuleInfo(string moduleName, BuildConfig configuration)
    {
        if (_modules.TryGetValue(GetModuleKey(moduleName, configuration), out ModuleInfo? moduleInfo))
        {
            return moduleInfo;
        }

        ModuleInfo info = new()
        {
            Name = moduleName,
            Configuration = configuration,
            LastSuccessfulBuild = DateTime.MinValue
        };

        SetModuleInfo(info);

        return info;
    }

}

public enum BuildConfig
{
    Debug,
    Release
}

public class ModuleInfo
{
    public string Name { get; set; }
    public BuildConfig Configuration { get; set; }

    public DateTime LastSuccessfulBuild { get; set; }

    [JsonIgnore]
    private Dictionary<string, SourceHash> _cachedSourceHashes = new();

    [JsonIgnore]
    private Dictionary<string, SourceHash> _newSourceHashes = new();

    /// <summary>
    /// Serializes <see cref="_newSourceHashes"/> and deserializes into <see cref="_cachedSourceHashes"/>.
    /// </summary>
    [JsonInclude]
    [JsonPropertyName("hashes")]
    internal Dictionary<string, SourceHash> Hashes
    {
        get => _newSourceHashes;
        set => _cachedSourceHashes = value;
    }

    public bool TryGetCachedHash(string fileName, out SourceHash cachedHash)
    {
        return _cachedSourceHashes.TryGetValue(fileName, out cachedHash);
    }

    public void SetNewHash(string fileName, SourceHash hash)
    {
        _newSourceHashes[fileName] = hash;
    }

    public void ResetHashes()
    {
        _cachedSourceHashes = _newSourceHashes;
        _newSourceHashes = new();
    }
}

public enum HashType
{
    Hash,
    Date
}

public struct SourceHash : IEquatable<SourceHash>
{
    public HashType Type { get; init; }
    public string? Hash { get; init; }
    public long Length { get; init; }

    public static SourceHash CreateHash(string hash, long length)
    {
        return new SourceHash()
        {
            Type = HashType.Hash,
            Hash = hash,
            Length = length
        };
    }

    public static SourceHash CreateTimeStamp(DateTime timeStamp, long length)
    {
        return new SourceHash()
        {
            Type = HashType.Date,
            Hash = timeStamp.ToString("o"), // ISO 8601 format
            Length = length
        };
    }

    public static bool operator ==(SourceHash left, SourceHash right) => left.Equals(right);
    public static bool operator !=(SourceHash left, SourceHash right) => !left.Equals(right);

    public override bool Equals([NotNullWhen(true)] object? obj)
    {
        return obj is SourceHash other && Equals(other);
    }

    public bool Equals(SourceHash other)
    {
        return Type == other.Type && Hash == other.Hash && Length == other.Length;
    }

    public override int GetHashCode()
    {
        return HashCode.Combine((int)Type, Hash, Length);
    }
}
