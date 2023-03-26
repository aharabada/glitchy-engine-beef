using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace GlitchyEngine
{
    public class CSharpTesting
    {
        public float MyPublicFloatVar = 5.0f;
        
		public CSharpTesting()
		{
			Console.WriteLine("Hallo von C#!");
            DoSomething();
            Console.WriteLine(Sample());
        }
        
        [DllImport ("__Internal", EntryPoint="DoSomething")]
        static extern void DoSomething();

        [MethodImpl(MethodImplOptions.InternalCall)]
        static extern string Sample();

        public void PrintFloatVar()
        {
            Console.WriteLine("MyPublicFloatVar = {0:F}", MyPublicFloatVar);
        }

        private float IncrementFloatVar(float value)
        {
            MyPublicFloatVar += value;

            return MyPublicFloatVar;
        }
    }
}