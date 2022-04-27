namespace DotNetScriptingHelper;

public class GameTime
{
    private ulong _frameCount;

    private TimeSpan _totalTime;
    private TimeSpan _frameTime;

    public ulong FrameCount => _frameCount;
    public TimeSpan TotalTime => _totalTime;
    public TimeSpan FrameTime => _frameTime;
    
    public float DeltaTime => (float)_frameTime.TotalSeconds;
    public float TotalSeconds => (float)_totalTime.TotalSeconds;

    internal GameTime(ulong frameCount, TimeSpan totalTime, TimeSpan frameTime)
    {
        _frameCount = frameCount;
        _totalTime = totalTime;
        _frameTime = frameTime;
    }
}
