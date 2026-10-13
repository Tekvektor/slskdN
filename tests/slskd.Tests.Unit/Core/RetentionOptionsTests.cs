// <copyright file="RetentionOptionsTests.cs" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>

namespace slskd.Tests.Unit.Core;

using System.ComponentModel.DataAnnotations;
using Xunit;

public class RetentionOptionsTests
{
    [Fact]
    public void LogsDefaultToFourteenDays()
    {
        Assert.Equal(14, new Options.RetentionOptions().Logs);
    }

    [Theory]
    [InlineData(1, false)]
    [InlineData(2, true)]
    public void LogsRequireAtLeastTwoDays(int days, bool expectedValid)
    {
        var options = new Options.RetentionOptions { Logs = days };
        var results = new List<ValidationResult>();

        var valid = Validator.TryValidateObject(options, new ValidationContext(options), results, validateAllProperties: true);

        Assert.Equal(expectedValid, valid);
    }
}
