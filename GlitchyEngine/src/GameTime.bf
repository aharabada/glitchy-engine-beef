using System;
using System.Diagnostics;

namespace GlitchyEngine
{
	/**
	 * A timer providing functionality to meassure frame times and game runtime.
	*/
	public class GameTime
	{
		private append Stopwatch _stopwatch = .();
		
		private uint64 _frameCount;

		private TimeSpan _totalTime;
		private TimeSpan _frameTime;

		/**
		 * The amount of time that has passed from the start of the timer until the last frame that finished.
		 */
		public TimeSpan TotalTime => _totalTime;
		/**
		 * The duration of the last frame.
		 */
		public TimeSpan FrameTime => _frameTime;
		/**
		 * The number of frames that have been finished since the timer was started.
		 */
		public uint64 FrameCount => _frameCount;

		/// The interval in seconds from the last frame to the current one.
		public float DeltaTime => (float)_frameTime.TotalSeconds;

		/**
		 * Initializes a new instance of a GameTime.
		 * @param startNow If set to true, the timer will start immediately.
		 *				   If set to false, the timer has to be started manually.
		 */
		[AllowAppend]
		public this(bool startNow = false)
		{
			_stopwatch.Restart();
		}

		/**
		 * Starts or continues the internal timer.
		 */
		public void Start()
		{
			_stopwatch.Start();
		}
		
		/**
		 * Restarts the internal timer and resets the counters.
		 */
		public void Restart()
		{
			_totalTime = 0;
			_frameTime = 0;	
			_frameCount = 0;
			_stopwatch.Restart();
		}

		/**
		 * Stops the internal timer.
		 */
		public void Stop()
		{
			_stopwatch.Stop();
		}

		/**
		 * Resets the timer.
		 */
		public void Reset()
		{
			_totalTime = 0;
			_frameTime = 0;
			_frameCount = 0;
			_stopwatch.Reset();
		}

		/**
		 * Tells the timer that a frame has passed and updates the counters.
		 */
		public void NewFrame()
		{
			TimeSpan old = _totalTime;
			_totalTime = _stopwatch.Elapsed;
			_frameTime = _totalTime - old;

			_frameCount++;
		}

		/**
		 * Tells the timer that a frame has passed and updates the counters according to the given time step.
		 */
		public void ManualStepFrame(float deltaTimeSeconds)
		{
			_frameTime = TimeSpan.FromSeconds(deltaTimeSeconds);
			_totalTime += _frameTime;

			_frameCount++;
		}
	}
}
