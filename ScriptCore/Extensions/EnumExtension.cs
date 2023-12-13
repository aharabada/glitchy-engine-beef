using System.Collections.Generic;
using System.Linq;

namespace GlitchyEngine.Extensions;

/// <summary>
/// Extends the <see cref="IEnumerable{T}"/>-interface with useful methods.
/// </summary>
public static class EnumExtension
{
    /// <summary>
    /// Enumerates the enumerable and returns a tuple containing the item and the index for every item.
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="self"></param>
    /// <returns></returns>
    public static IEnumerable<(T item, int index)> WithIndex<T>(this IEnumerable<T> self)       
        => self.Select((item, index) => (item, index));
}