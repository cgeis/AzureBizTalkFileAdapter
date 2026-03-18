using System.Globalization;

public static class MacroReplacer
{
    public static string Replace(string template, string sourceFileName)
    {
        var now = DateTime.UtcNow;
        var result = template;

        result = result.Replace("%SourceFileName%", sourceFileName);
        result = result.Replace("%MessageID%", Guid.NewGuid().ToString());
        result = result.Replace("%datetime%", now.ToString("yyyy-MM-ddTHHmmss", CultureInfo.InvariantCulture));
        result = result.Replace("%datetime_bts2000%", now.ToString("yyyyMMddHHmmssfff"));
        result = result.Replace("%datetime.tz%", now.ToString("yyyy-MM-ddTHHmmss") + "+0000");
        result = result.Replace("%time%", now.ToString("HHmmss"));
        result = result.Replace("%time.tz%", now.ToString("HHmmss") + "+0000");

        // Derived for convenience (BizTalk-compatible)
        result = result.Replace("%Extension%", Path.GetExtension(sourceFileName));
        result = result.Replace("%SourceFileNameNoExt%", Path.GetFileNameWithoutExtension(sourceFileName));

        // Party macros not applicable here (no BizTalk context) – left unsubstituted per BizTalk behavior
        return result;
    }
}
