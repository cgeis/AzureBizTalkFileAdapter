using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration((context, builder) =>
    {
        var tempConfig = new ConfigurationBuilder()
            .AddEnvironmentVariables()
            .Build();
        var conn = tempConfig["AppConfigConnectionString"] ?? throw new InvalidOperationException("AppConfigConnectionString missing");
        builder.AddAzureAppConfiguration(conn);
    })
    .Build();

host.Run();
