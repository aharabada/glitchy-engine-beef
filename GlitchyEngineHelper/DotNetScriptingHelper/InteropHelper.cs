using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;

namespace DotNetScriptingHelper;

public class InteropHelper
{
    struct CreateArgs
    {
        public IntPtr Ptr;
        public int Length;

        public string ManagedCopy => Marshal.PtrToStringUTF8(Ptr, Length);
    }

    //[UnmanagedCallersOnly]
    public static int SomeMethod(IntPtr args, int argLength)
    {
        Debug.WriteLine(typeof(InteropHelper).AssemblyQualifiedName);

        return 5;
    }

    [UnmanagedCallersOnly]
    public static IntPtr CreateInstance(IntPtr args, int argLength)
    {
        try
        {
            Debug.Assert(Marshal.SizeOf<CreateArgs>() == argLength, "Provided argument has wrong size.");
            
            CreateArgs createArgs = Marshal.PtrToStructure<CreateArgs>(args);
            
            string str = createArgs.ManagedCopy;
            
            Console.WriteLine($"Trying to get type \"{str}\"");
            
            Type? type = Type.GetType(createArgs.ManagedCopy, true);
            
            if (type == null)
            {
                Console.WriteLine("Type was null.");
                return IntPtr.Zero;
            }

            object? instance = Activator.CreateInstance(type);

            if (instance == null)
                return IntPtr.Zero;

            GCHandle handle = GCHandle.Alloc(instance);

            return GCHandle.ToIntPtr(handle);
        }
        catch (Exception e)
        {
            Console.WriteLine(e);
            throw;
        }
    }

    [UnmanagedCallersOnly]
    public static void CallMethod(IntPtr instance, IntPtr methodName, int methodNameLength)
    {
        GCHandle handle = GCHandle.FromIntPtr(instance);

        if (handle.Target == null)
            throw new Exception("Handle has no target?");

        Type type = handle.Target.GetType();

        string name = Marshal.PtrToStringUTF8(methodName, methodNameLength);

        MethodInfo? mi = type.GetMethod(name);

        if (mi == null)
            throw new Exception("MethodInfo is null.");

        mi.Invoke(handle.Target, null);
    }


    public delegate void FreeInstanceEntryPoint(IntPtr instance);

    [UnmanagedCallersOnly]
    public static void FreeInstance(IntPtr instance)
    {
        GCHandle handle = GCHandle.FromIntPtr(instance);
        handle.Free();
    }
}
