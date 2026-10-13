// <copyright file="ScopedHubAuthorizationTests.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>
namespace slskd.Tests.Unit.Common.Authentication;

using System.Security.Claims;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using slskd.Authentication;
using slskd.Search;
using slskd.Search.API;
using Xunit;

public sealed class ScopedHubAuthorizationTests
{
    [Theory]
    [InlineData("nowplaying", false)]
    [InlineData("federation", false)]
    [InlineData("*", true)]
    [InlineData(null, true)]
    public async Task HubConnection_EnforcesScopesBeforeSendingSearchSnapshot(string? scope, bool allowed)
    {
        var searches = new Mock<ISearchService>();
        searches.Setup(value => value.ListAsync(null, 500, 0, null)).ReturnsAsync(new List<Search>());
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Logging.ClearProviders();
        builder.Services.AddSingleton(searches.Object);
        builder.Services.AddAuthorization(options => options.AddPolicy(AuthPolicy.Any, policy => policy.RequireAuthenticatedUser()));
        builder.Services.AddSignalR(options => options.AddFilter<ScopedApiKeyHubFilter>());
        await using var app = builder.Build();
        app.UseRouting();
        app.Use(async (context, next) =>
        {
            var claims = new List<Claim> { new(ClaimTypes.Name, "integration-key"), new(ClaimTypes.Role, "Administrator") };
            if (scope != null) claims.Add(new Claim(SlskdClaims.ScopeClaim, scope));
            context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "ApiKey"));
            await next();
        });
        app.UseAuthorization();
        app.MapHub<SearchHub>("/hub/search");
        await app.StartAsync();
        await using var connection = new HubConnectionBuilder()
            .WithUrl(app.Urls.Single() + "/hub/search", options =>
            {
                options.Transports = Microsoft.AspNetCore.Http.Connections.HttpTransportType.LongPolling;
            })
            .Build();
        var snapshot = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        connection.On<List<Search>>(SearchHubMethods.List, _ => snapshot.TrySetResult());
        connection.Closed += _ => { closed.TrySetResult(); return Task.CompletedTask; };

        await connection.StartAsync();
        var completed = await Task.WhenAny(snapshot.Task, closed.Task).WaitAsync(TimeSpan.FromSeconds(10));

        Assert.Same(allowed ? snapshot.Task : closed.Task, completed);
        searches.Verify(value => value.ListAsync(null, 500, 0, null), allowed ? Times.Once() : Times.Never());
    }
}
