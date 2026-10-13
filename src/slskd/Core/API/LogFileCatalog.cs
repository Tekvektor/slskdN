// <copyright file="LogFileCatalog.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>

namespace slskd.Core.API;

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

internal sealed record LogFileEntry(string Name, long Length, DateTimeOffset LastModified);

internal static class LogFileCatalog
{
    public static IReadOnlyList<LogFileEntry> List(string directory, string appName)
    {
        if (!Directory.Exists(directory))
        {
            return Array.Empty<LogFileEntry>();
        }

        var enumerationOptions = new EnumerationOptions
        {
            AttributesToSkip = FileAttributes.Hidden | FileAttributes.System | FileAttributes.ReparsePoint,
            IgnoreInaccessible = true,
            RecurseSubdirectories = false,
        };

        return Directory.EnumerateFiles(directory, $"{appName}-*.log", enumerationOptions)
            .Select(path => Path.GetFileName(path))
            .Where(name => TryResolve(directory, appName, name, out _))
            .Select(name => new FileInfo(Path.Combine(directory, name)))
            .OrderByDescending(file => file.LastWriteTimeUtc)
            .ThenByDescending(file => file.Name, StringComparer.Ordinal)
            .Select(file => new LogFileEntry(file.Name, file.Length, new DateTimeOffset(file.LastWriteTimeUtc)))
            .ToArray();
    }

    public static bool TryResolve(string directory, string appName, string fileName, out string path)
    {
        path = string.Empty;

        if (string.IsNullOrWhiteSpace(fileName)
            || !fileName.StartsWith($"{appName}-", StringComparison.Ordinal)
            || fileName.Length != appName.Length + 13
            || !fileName.EndsWith(".log", StringComparison.Ordinal)
            || !DateOnly.TryParseExact(fileName.AsSpan(appName.Length + 1, 8), "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _))
        {
            return false;
        }

        var fullDirectory = Path.TrimEndingDirectorySeparator(Path.GetFullPath(directory));
        var candidate = Path.GetFullPath(Path.Combine(fullDirectory, fileName));
        var candidateDirectory = Path.TrimEndingDirectorySeparator(Path.GetDirectoryName(candidate)!);
        var pathComparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

        if (!string.Equals(candidateDirectory, fullDirectory, pathComparison)
            || !File.Exists(candidate)
            || (File.GetAttributes(candidate) & FileAttributes.ReparsePoint) != 0)
        {
            return false;
        }

        path = candidate;
        return true;
    }
}
