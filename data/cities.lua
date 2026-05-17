return {
    {
        id       = "seattle",
        name     = "Seattle",
        adjacent = { "chicago", "los_angeles" },
    },
    {
        id       = "los_angeles",
        name     = "Los Angeles",
        adjacent = { "seattle", "houston" },
    },
    {
        id       = "houston",
        name     = "Houston",
        adjacent = { "los_angeles", "atlanta", "chicago" },
    },
    {
        id       = "atlanta",
        name     = "Atlanta",
        adjacent = { "houston", "new_york" },
    },
    {
        id       = "new_york",
        name     = "New York",
        adjacent = { "atlanta", "chicago" },
    },
    {
        id       = "chicago",
        name     = "Chicago",
        adjacent = { "seattle", "houston", "new_york" },
    },
}
