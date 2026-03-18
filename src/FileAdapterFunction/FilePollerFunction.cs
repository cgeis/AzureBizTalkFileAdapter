using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Azure.Storage.Files.Shares;
using System.Text.RegularExpressions;

public class FilePollerFunction
{
    private readonly IConfiguration _config;
    private readonly ILogger _logger;

    public FilePollerFunction(IConfiguration config, ILoggerFactory loggerFactory)
    {
        _config = config;
        _logger = loggerFactory.CreateLogger<FilePollerFunction>();
    }

    [Function("FileAdapterPoller")]
    public async Task Run([TimerTrigger("%PollingSchedule%")] TimerInfo timer)
    {
        _logger.LogInformation("BizTalk FILE Adapter poll started");

        var inputConn = _config["InputStorageConnectionString"];
        var inputShareName = _config["InputFileShareName"];
        var inputDir = _config["InputDirectory"] ?? "/";
        var mask = _config["InputFileMask"] ?? "*.*";

        var shareClient = new ShareClient(inputConn, inputShareName);
        var dirClient = shareClient.GetDirectoryClient(inputDir);

        await foreach (var item in dirClient.GetFilesAndDirectoriesAsync())
        {
            if (!item.IsFile || !MatchesMask(item.Name, mask)) continue;

            var fileClient = dirClient.GetFileClient(item.Name);
            var download = await fileClient.DownloadAsync();
            using var ms = new MemoryStream();
            await download.Value.Content.CopyToAsync(ms);
            var content = ms.ToArray();
            var originalName = item.Name;

            // Process (extend here if needed – e.g. XML transform)
            var newName = MacroReplacer.Replace(_config["OutputFileNameTemplate"]!, originalName);

            // Output
            var outConn = _config["OutputStorageConnectionString"];
            var outShare = new ShareClient(outConn, _config["OutputFileShareName"]);
            var outDirClient = outShare.GetDirectoryClient(_config["OutputDirectory"] ?? "/");
            var outFile = outDirClient.GetFileClient(newName);

            await outFile.CreateAsync(content.Length);
            await outFile.UploadRangeAsync(new HttpRange(0, content.Length), new MemoryStream(content));

            await fileClient.DeleteIfExistsAsync(); // BizTalk-style delete after success
            _logger.LogInformation("Processed {Original} → {New}", originalName, newName);
        }
    }

    private static bool MatchesMask(string fileName, string mask)
    {
        var pattern = "^" + Regex.Escape(mask).Replace("\\*", ".*").Replace("\\?", ".") + "$";
        return Regex.IsMatch(fileName, pattern, RegexOptions.IgnoreCase);
    }
}
