// <copyright file="ScopedApiKeyHubFilter.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>
namespace slskd.Authentication;

using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR;

/// <summary>
///     Rejects narrowly scoped credentials on hubs without an explicit scope mapping.
/// </summary>
public sealed class ScopedApiKeyHubFilter : IHubFilter
{
    public Task OnConnectedAsync(HubLifetimeContext context, Func<HubLifetimeContext, Task> next)
    {
        RequireUnrestrictedCredential(context.Context.User);
        return next(context);
    }

    public ValueTask<object?> InvokeMethodAsync(HubInvocationContext invocationContext, Func<HubInvocationContext, ValueTask<object?>> next)
    {
        RequireUnrestrictedCredential(invocationContext.Context.User);
        return next(invocationContext);
    }

    private static void RequireUnrestrictedCredential(ClaimsPrincipal? user)
    {
        var scopes = user?.FindAll(SlskdClaims.ScopeClaim)
            .Select(claim => claim.Value)
            .Where(scope => !string.IsNullOrWhiteSpace(scope))
            .ToArray() ?? Array.Empty<string>();

        if (scopes.Length > 0 && !scopes.Contains(SlskdClaims.ScopeAll, StringComparer.OrdinalIgnoreCase))
        {
            throw new HubException("This credential does not permit access to SignalR hubs.");
        }
    }
}
