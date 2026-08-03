class CompanyValue extends GSInfo
{
    function GetAuthor()        { return "MUNTY"; }
    function GetName()          { return "MUNTY Company Value"; }
    function GetDescription()   { return "Check company values and use admin commands"; }
    function GetVersion()       { return 1; }
    function MinVersionToLoad() { return 1; }
    function GetDate()          { return "02-08-2026"; }
    function GetShortName()     { return "MNTC"; }
    function CreateInstance()   { return "CompanyValue"; }
    function GetAPIVersion()    { return "1.4"; }
    function GetURL()           { return ""; }

    function GetSettings()
    {

        AddSetting({
            name = "goal_value", 
            description = "Target company value (in thousand currency units) to reach to win the game",
            min_value = 1,
            max_value = 999999999,
            easy_value = 12500,
            medium_value = 100000,
            hard_value = 500000,
            custom_value = 10000000,
            step_size = 250,
            flags = CONFIG_INGAME
        });

        AddSetting({
            name = "announce_interval",
            description = "Interval between announcements (in seconds)",
            min_value = 1,
            max_value = 3600,
            easy_value = 10,
            medium_value = 30,
            hard_value = 60,
            custom_value = 30,
            step_size = 1,
            flags = CONFIG_INGAME
        });

    }
}

RegisterGS(CompanyValue());