// <copyright file="UploadQueueForecast.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>
namespace slskd.Transfers;

/// <summary>
/// A consistent forecast of queue position and the user's group slot capacity.
/// </summary>
/// <param name="QueuePosition">The estimated number of transfers ahead of a new upload.</param>
/// <param name="Slots">The configured upload slots for the user's group.</param>
public sealed record UploadQueueForecast(int QueuePosition, int Slots);
