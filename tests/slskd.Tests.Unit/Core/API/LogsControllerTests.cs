// <copyright file="LogsControllerTests.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>
namespace slskd.Tests.Unit.Core.API;

using System.Reflection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using slskd.Core.API;
using Xunit;

public class LogsControllerTests
{
    [Theory]
    [InlineData(typeof(LogsController), nameof(LogsController.Logs))]
    [InlineData(typeof(LogsController), nameof(LogsController.Files))]
    [InlineData(typeof(LogsController), nameof(LogsController.View))]
    [InlineData(typeof(LogsController), nameof(LogsController.Download))]
    [InlineData(typeof(LogsHub), null)]
    public void LogSurfaces_RequireAdministratorRole(Type type, string? actionName)
    {
        var attributes = actionName == null
            ? type.GetCustomAttributes<AuthorizeAttribute>(inherit: true)
            : type.GetMethod(actionName)!.GetCustomAttributes<AuthorizeAttribute>(inherit: true);
        var authorize = Assert.Single(attributes);

        Assert.Equal(AuthPolicy.Any, authorize.Policy);
        Assert.Equal(AuthRole.AdministratorOnly, authorize.Roles);
    }

    [Fact]
    public void Logs_ReturnsSnapshotArray()
    {
        Program.LogBuffer.Enqueue(new LogRecord
        {
            Context = "test",
            Message = "message",
            Timestamp = DateTime.UtcNow,
        });

        var controller = new LogsController();

        var result = Assert.IsType<OkObjectResult>(controller.Logs());

        Assert.IsAssignableFrom<LogRecord[]>(result.Value);
    }

    [Fact]
    public void LogFileCatalog_ListsOnlyDirectApplicationLogFilesNewestFirst()
    {
        using var directory = new TemporaryDirectory();
        var oldest = Path.Combine(directory.Path, "slskd-20261010.log");
        var newest = Path.Combine(directory.Path, "slskd-20261012.log");
        File.WriteAllText(oldest, "old");
        File.WriteAllText(newest, "newer");
        File.WriteAllText(Path.Combine(directory.Path, "other-20261012.log"), "other");
        File.WriteAllText(Path.Combine(directory.Path, "slskd-20261012.txt"), "text");
        var nested = Directory.CreateDirectory(Path.Combine(directory.Path, "nested"));
        File.WriteAllText(Path.Combine(nested.FullName, "slskd-20261013.log"), "nested");
        File.SetLastWriteTimeUtc(oldest, new DateTime(2026, 10, 10, 12, 0, 0, DateTimeKind.Utc));
        File.SetLastWriteTimeUtc(newest, new DateTime(2026, 10, 12, 12, 0, 0, DateTimeKind.Utc));

        var files = LogFileCatalog.List(directory.Path, "slskd");

        Assert.Collection(
            files,
            file =>
            {
                Assert.Equal("slskd-20261012.log", file.Name);
                Assert.Equal(5, file.Length);
                Assert.Equal(DateTimeOffset.Parse("2026-10-12T12:00:00Z"), file.LastModified);
            },
            file => Assert.Equal("slskd-20261010.log", file.Name));
    }

    [Fact]
    public void LogFileCatalog_RejectsPathsAndFilesOutsideTheApplicationLogPattern()
    {
        using var directory = new TemporaryDirectory();
        File.WriteAllText(Path.Combine(directory.Path, "slskd-20261012.log"), "log");

        Assert.True(LogFileCatalog.TryResolve(directory.Path, "slskd", "slskd-20261012.log", out var path));
        Assert.Equal(Path.Combine(directory.Path, "slskd-20261012.log"), path);
        Assert.False(LogFileCatalog.TryResolve(directory.Path, "slskd", "../outside.log", out _));
        Assert.False(LogFileCatalog.TryResolve(directory.Path, "slskd", "..\\outside.log", out _));
        Assert.False(LogFileCatalog.TryResolve(directory.Path, "slskd", "other-20261012.log", out _));
        Assert.False(LogFileCatalog.TryResolve(directory.Path, "slskd", "slskd-20261012.txt", out _));
    }

    private sealed class TemporaryDirectory : IDisposable
    {
        public TemporaryDirectory()
        {
            Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"slskdn-log-catalog-{Guid.NewGuid():N}");
            Directory.CreateDirectory(Path);
        }

        public string Path { get; }

        public void Dispose() => Directory.Delete(Path, recursive: true);
    }
}
