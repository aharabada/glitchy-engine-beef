using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace BuildTool;

abstract class Module
{
    public abstract string Name { get; }

    public List<Module> Dependencies { get; } = new();
    public abstract List<Type> DependencyTypes { get; }

    public abstract Task<bool> Run(BuildInfo buildInfo);

    protected virtual List<WatchedSource> GetWatchedSources(BuildInfo buildInfo) => [];

    /// <summary>
    /// Check whether the requested build configurations actually need to be rebuilt.
    /// </summary>
    /// <param name="buildInfo"></param>
    /// <param name="moduleBuildCache"></param>
    /// <returns>The updated build information.</returns>
    public BuildInfo GetBuildInfo(BuildInfo buildInfo, ModuleCache moduleBuildCache)
    {
        BuildInfo moduleBuildInfo = buildInfo;

        if (buildInfo.BuildDebug)
        {
            ModuleInfo cacheInfo = moduleBuildCache.GetModuleInfo(Name, BuildConfig.Debug);
                
            moduleBuildInfo.BuildDebug = HasSourceChanged(moduleBuildInfo, cacheInfo);
        }
        
        if (buildInfo.BuildRelease)
        {
            ModuleInfo cacheInfo = moduleBuildCache.GetModuleInfo(Name, BuildConfig.Release);
                
            moduleBuildInfo.BuildRelease = HasSourceChanged(moduleBuildInfo, cacheInfo);
        }

        return moduleBuildInfo;
    }

    public bool HasSourceChanged(BuildInfo buildInfo, ModuleInfo cacheInfo)
    {
        bool needsRebuild = false;

        if (buildInfo.ForceRebuild)
            needsRebuild = true;

        // If we never successfully built before, we need to build now.
        if (cacheInfo.LastSuccessfulBuild == DateTime.MinValue)
            needsRebuild = true;

        List<WatchedSource> watchedSources = GetWatchedSources(buildInfo);

        if (watchedSources.Count == 0)
            needsRebuild = true;

        foreach (WatchedSource source in watchedSources)
        {
            bool cacheEntryFound = cacheInfo.TryGetCachedHash(source.Path, out SourceHash cachedHash);

            SourceHash newHash;

            if (Directory.Exists(source.Path))
            {
                Debug.Assert(source.Mode == WatchMode.Metadata, "Directory watching is only supported in Metadata mode.");
                
                DirectoryInfo dirInfo = new (source.Path);

                if (dirInfo.LastWriteTimeUtc > cacheInfo.LastSuccessfulBuild)
                {
                    Console.WriteLine("Needs rebuild");
                    needsRebuild = true;
                }

                // Since we don't save anything directory specific in the has, we can skip this check if we already know that we are going to rebuild.
                if (!needsRebuild)
                {
                    foreach (FileSystemInfo dirEntry in dirInfo.EnumerateFileSystemInfos("**",
                                 enumerationOptions: new EnumerationOptions()
                                     { MatchType = MatchType.Win32, RecurseSubdirectories = source.Recursive }))
                    {
                        //string relativePath = Path.GetRelativePath(dirInfo.FullName, dirEntry.FullName);
                        //if (source.ExcludedDirectories.Contains(relativePath, StringComparer.OrdinalIgnoreCase))
                        //    continue;

                        Console.WriteLine("Checking entry: " + dirEntry.FullName);
                        if (dirEntry.LastWriteTimeUtc > cacheInfo.LastSuccessfulBuild)
                        {
                            Console.WriteLine("Needs rebuild");
                            needsRebuild = true;
                            break;
                        }
                    }
                }

                // We really just need any timestamp, to know that the directory existed at some point.
                newHash = SourceHash.CreateTimeStamp(DateTime.UtcNow, 1);
            }
            else if (File.Exists(source.Path))
            {
                FileInfo fileInfo = new (source.Path);
                
                if (source.Mode == WatchMode.Metadata)
                {
                    newHash = SourceHash.CreateTimeStamp(fileInfo.LastWriteTimeUtc, fileInfo.Length);
                    
                    if (newHash != cachedHash)
                        needsRebuild = true;
                }
                else if (source.Mode == WatchMode.Content)
                {
                    string hash = ComputeFileHash(fileInfo.FullName);
                    newHash = SourceHash.CreateHash(hash, fileInfo.Length);

                    if (newHash != cachedHash)
                    {
                        Console.WriteLine("Needs rebuild");
                        needsRebuild = true;
                    }
                }
                else
                {
                    throw new InvalidOperationException("Unsupported file watch mode: " + source.Mode);
                }
            }
            else
            {
                if (source.Mode == WatchMode.Metadata)
                {
                    newHash = SourceHash.CreateTimeStamp(DateTime.MinValue, -1);
                }
                else
                {
                    newHash = SourceHash.CreateHash(string.Empty, -1);
                }

                if (!cacheEntryFound || newHash != cachedHash)
                {
                    // If we didn't have a cache entry before then this is the first time building.
                    // If we had a cache entry before we need to check whether it didn't exist before.
                    needsRebuild = true;
                }
            }
                    
            cacheInfo.SetNewHash(source.Path, newHash);
        }

        return needsRebuild;
    }

    private static string ComputeFileHash(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        using var sha256 = SHA256.Create();

        byte[] hash = sha256.ComputeHash(stream);
        return Convert.ToHexString(hash);
    }

    public void UpdateCacheInfo(BuildInfo buildInfo, ModuleCache moduleCache, bool success)
    {
        if (buildInfo.BuildDebug)
        {
            ModuleInfo cacheInfo = moduleCache.GetModuleInfo(Name, BuildConfig.Debug);
            cacheInfo.LastSuccessfulBuild = success ? DateTime.UtcNow : DateTime.MinValue;

            if (!success)
                cacheInfo.ResetHashes();
        }
        
        if (buildInfo.BuildRelease)
        {
            ModuleInfo cacheInfo = moduleCache.GetModuleInfo(Name, BuildConfig.Release);
            cacheInfo.LastSuccessfulBuild = success ? DateTime.UtcNow : DateTime.MinValue;
            
            if (!success)
                cacheInfo.ResetHashes();
        }
    }
}
