using System.Text;

namespace GlitchyEngine.Extensions;

public static class StringExtension
{
    /// <summary>
    /// Converts a variable name to a pretty name as good as reasonably possible.
    /// </summary>
    /// <param name="uglyName">The name of a variable to prettify.</param>
    /// <returns>The pretty string.</returns>
    public static string ToPrettyName(this string uglyName)
    {
        StringBuilder sb = new StringBuilder(uglyName.Length);
    
        bool wasUpper = false;
        bool inWord = false;
        bool inNumber = false;
    
        foreach (char c in uglyName)
        {
            if (char.IsLetter(c))
            {
                if (inNumber)
                {
                    sb.Append(' ');
                    inNumber = false;
                }
            
                bool newWord = !inWord;
                        
                if (char.IsUpper(c) && !wasUpper)
                {
                    newWord = true;
                    wasUpper = true;
                
                    if (inWord)
                    {
                        sb.Append(' ');
                    }
                }
                else if (char.IsLower(c))
                {
                    wasUpper = false;
                }
            
                sb.Append(newWord ? char.ToUpper(c) : char.ToLower(c));
            
                inWord = true;
            }
            else if (char.IsDigit(c))
            {
                if (inWord)
                {
                    sb.Append(' ');
                    inWord = false;
                    inNumber = true;
                }
            
                sb.Append(c);
            }
            else if (inWord || inNumber)
            {
                sb.Append(' ');
                inWord = false;
                inNumber = false;
                wasUpper = false;
            }
        }
    
        return sb.ToString();
    }
}
