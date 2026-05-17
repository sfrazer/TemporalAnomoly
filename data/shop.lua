local M = {}

M.startingBonuses = {
    {id = "extra_starting_card", name = "Extra Starting Card", cost = 3,  maxCount = 3,
     description = "+1 card in opening hand (stackable 3\xc3\x97)"},
    {id = "starting_outpost",    name = "Starting Outpost",    cost = 5,  maxCount = 1,
     description = "Pre-place a Temporal Outpost in your starting city"},
    {id = "light_incidents",     name = "Light Incidents",     cost = 8,  maxCount = 1,
     description = "Skip the 2 heaviest initial threat seedings"},
    {id = "remove_flux",         name = "Remove Flux Card",    cost = 10, maxCount = 1,
     description = "Remove 1 Chronological Flux card from the deck"},
    {id = "bonus_action",        name = "Bonus Action",        cost = 12, maxCount = 1,
     description = "5 actions per turn instead of 4"},
}

M.deckCards = {
    {id = "stabilizer_cache",   name = "Stabilizer Cache",   cost = 3, maxCopies = 2,
     description = "Clear all cubes of 1 color in your current city"},
    {id = "mobile_outpost",     name = "Mobile Outpost",     cost = 4, maxCopies = 2,
     description = "Build a Temporal Outpost without discarding a card"},
    {id = "emergency_protocol", name = "Emergency Protocol", cost = 5, maxCopies = 2,
     description = "+2 actions this turn"},
    {id = "temporal_seal",      name = "Temporal Seal",      cost = 4, maxCopies = 2,
     description = "Prevent all incidents in 1 city for 1 round"},
    {id = "supply_drop",        name = "Supply Drop",        cost = 3, maxCopies = 2,
     description = "Restore 3 cubes to any depleted anomaly supply"},
}

M.challengeMods = {
    {id = "hotspot",          name = "Hotspot",          bonusRP = 1,
     description = "When drawn: place 2 cubes on a random city/period"},
    {id = "cascade_event",    name = "Cascade Event",    bonusRP = 2,
     description = "When drawn: also resolve 2 additional threat cards"},
    {id = "volatile_anomaly", name = "Volatile Anomaly", bonusRP = 3,
     description = "When drawn: next Chronological Flux seeds 3 cities"},
    {id = "temporal_ban",     name = "Temporal Ban",     bonusRP = 1,
     description = "When drawn: teleport actions disabled for 1 turn"},
}

return M
