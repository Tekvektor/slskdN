// <copyright file="ActivityPubRelationshipAuthorizationTests.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>
namespace slskd.Tests.Unit.SocialFederation;

using System.Globalization;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;
using NSec.Cryptography;
using slskd.Common;
using slskd.VirtualSoulfind.Core.Music;
using slskd.SocialFederation;
using slskd.SocialFederation.API;
using Xunit;

public sealed class ActivityPubRelationshipAuthorizationTests
{
    [Theory]
    [InlineData("Undo")]
    [InlineData("Remove")]
    public async Task SignedRelationshipRemoval_CannotNameAnotherActor(string activityType)
    {
        await VerifyRemovalAsync(activityType, "https://remote.example/actors/victim", expectedStatus: 401);
    }

    [Theory]
    [InlineData("Undo")]
    [InlineData("Remove")]
    public async Task SignedRelationshipRemoval_CanRemoveOwnRelationship(string activityType)
    {
        await VerifyRemovalAsync(activityType, "https://remote.example/actors/sender", expectedStatus: 202);
    }

    [Theory]
    [InlineData("https://remote.example/actors/Sender")]
    [InlineData(null)]
    public async Task SignedRelationshipRemoval_RejectsMissingOrDifferentCaseActor(string? nestedActor)
    {
        await VerifyRemovalAsync("Undo", nestedActor, expectedStatus: 401);
    }

    [Fact]
    public async Task SignedRelationshipRemoval_RejectsDifferentCaseOuterActor()
    {
        const string differentActor = "https://remote.example/actors/Sender";
        await VerifyRemovalAsync("Undo", differentActor, expectedStatus: 401, outerActor: differentActor);
    }

    [Fact]
    public async Task SignedRelationshipRemoval_RejectsTamperedBody()
    {
        await VerifyRemovalAsync("Undo", "https://remote.example/actors/sender", expectedStatus: 401, tamperBody: true);
    }

    private static async Task VerifyRemovalAsync(string activityType, string? nestedActor, int expectedStatus, bool tamperBody = false, string? outerActor = null)
    {
        const string sender = "https://remote.example/actors/sender";
        const string keyId = sender + "#main-key";
        var federationOptions = new Mock<IOptionsMonitor<SocialFederationOptions>>();
        federationOptions.SetupGet(options => options.CurrentValue).Returns(new SocialFederationOptions
        {
            Enabled = true,
            Mode = "Public",
            BaseUrl = "https://instance.example",
        });
        var publishingOptions = new Mock<IOptionsMonitor<FederationPublishingOptions>>();
        publishingOptions.SetupGet(options => options.CurrentValue).Returns(new FederationPublishingOptions());
        var keys = new Mock<IActivityPubKeyStore>();
        var relationships = new Mock<IActivityPubRelationshipStore>();
        var inbox = new Mock<IActivityPubInboxStore>();
        var music = new MusicLibraryActor(federationOptions.Object, keys.Object, Mock.Of<IMusicContentDomainProvider>(), NullLogger<MusicLibraryActor>.Instance);
        var actors = new LibraryActorService(federationOptions.Object, keys.Object, music,
            NullLogger<LibraryActorService>.Instance, NullLoggerFactory.Instance);
        using var http = new HttpClient();
        using var delivery = new ActivityDeliveryService(http, federationOptions.Object, publishingOptions.Object,
            keys.Object, NullLogger<ActivityDeliveryService>.Instance);
        var federation = new FederationService(federationOptions.Object, publishingOptions.Object, actors,
            relationships.Object, keys.Object, delivery, NullLogger<FederationService>.Instance);
        var fetcher = new Mock<IHttpSignatureKeyFetcher>();
        using var signingKey = Key.Import(SignatureAlgorithm.Ed25519,
            Convert.FromBase64String("nWGxne/9WqC6hCmKMH36EcONbGqL9a5f/c4g+NpR+n0="), KeyBlobFormat.RawPrivateKey);
        fetcher.Setup(value => value.FetchPublicKeyPkixAsync(keyId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(signingKey.PublicKey.Export(KeyBlobFormat.PkixPublicKey));
        var controller = new ActivityPubController(federationOptions.Object, inbox.Object,
            Mock.Of<IActivityPubOutboxStore>(), relationships.Object, federation, keys.Object, fetcher.Object,
            actors, NullLogger<ActivityPubController>.Instance);
        var context = new DefaultHttpContext();
        controller.ControllerContext = new ControllerContext { HttpContext = context };
        var body = JsonSerializer.SerializeToUtf8Bytes(new
        {
            id = sender + "/activities/removal",
            type = activityType,
            actor = outerActor ?? sender,
            @object = new { type = "Follow", actor = nestedActor, @object = "https://instance.example/actors/music" },
        });
        context.Items["ActivityPubInboxBody"] = body;
        context.Request.Method = "POST";
        context.Request.Path = "/actors/music/inbox";
        context.Request.Host = new HostString("instance.example");
        var date = DateTimeOffset.UtcNow.ToString("r", CultureInfo.InvariantCulture);
        var digest = "SHA-256=" + Convert.ToBase64String(SHA256.HashData(body));
        context.Request.Headers["Date"] = date;
        context.Request.Headers["Digest"] = digest;
        var signingText = $"(request-target): post /actors/music/inbox\nhost: instance.example\ndate: {date}\ndigest: {digest}";
        var signature = Convert.ToBase64String(SignatureAlgorithm.Ed25519.Sign(signingKey, Encoding.UTF8.GetBytes(signingText)));
        context.Request.Headers["Signature"] = $"keyId=\"{keyId}\",algorithm=\"ed25519\",headers=\"(request-target) host date digest\",signature=\"{signature}\"";

        if (tamperBody)
        {
            context.Items["ActivityPubInboxBody"] = body.Concat(new[] { (byte)' ' }).ToArray();
        }

        var result = await controller.PostToInbox("music");

        Assert.Equal(expectedStatus, Assert.IsAssignableFrom<IStatusCodeActionResult>(result).StatusCode);
        var expectedCalls = expectedStatus == 202 ? Times.Once() : Times.Never();
        relationships.Verify(value => value.RemoveFollowerAsync("music", nestedActor!, It.IsAny<CancellationToken>()), expectedCalls);
        relationships.Verify(value => value.RemoveFollowingAsync("music", nestedActor!, It.IsAny<CancellationToken>()),
            expectedStatus == 202 && activityType == "Remove" ? Times.Once() : Times.Never());
        if (expectedStatus == 401)
        {
            relationships.VerifyNoOtherCalls();
            inbox.VerifyNoOtherCalls();
        }
    }
}
