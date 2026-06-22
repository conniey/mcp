namespace VallyEvaluator.Models;

public class StimulusGraderConfig
{
    public required string Type { get; set; }

    public required GraderConfigEntry Config { get; set; }
}

public class GraderConfigEntry
{
    public required GraderConfigEntryPair Required { get; set; }
}

public class GraderConfigEntryPair
{
    public required string Name { get; set; }

    public required string Command { get; set; }
}
