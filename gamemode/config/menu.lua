MEConfig = MEConfig or {}

local C = MEConfig

C.Intro = {
    PegiDuration  = 4.4,
    EsrbDuration  = 4.1,
    Gap           = 1.1,
    EndGap        = 0.5,
    SfxVolume     = 0.85,
    TotalDuration = 12.0,
}

C.Camera = {
    Shots = {
        { pos = Vector(-7064.416992, 1336.490234,  7.807098), ang = Angle(0.330002, 179.970871, 0), fov = 70 },
        { pos = Vector(-6541.694824, 1336.223511, 10.817829), ang = Angle(0.330002, 179.970871, 0), fov = 70 },
    },
    HandoffTime = 1.0,
}

C.TitleScreen = {
    Copyright         = "© 2026 Merge Empires  ·  Inspired by Mini Empires.\nGmodStore Gamemode Competition entry. All Rights Reserved.",
    BarHeight         = 180,
    MusicVolume       = 0.55,
    ShotDuration      = 6.5,
    FadeDuration      = 1.4,
    BlinkInterval     = 3.0,
    ExitFadeDuration  = 1.8,
    EnterFadeDuration = 1.0,
    TravelShots = {
        {
            A = { pos = Vector( -9244.500000,  -318.954071, -15492.083008), ang = Angle(  3.799478, -169.474503, 0) },
            B = { pos = Vector( -9637.913086,  -392.098602, -15518.728516), ang = Angle(  3.799478, -169.474503, 0) },
            fov = 70,
        },
        {
            A = { pos = Vector(-10162.839844,  -688.274475, -15546.038086), ang = Angle(-12.968955,   23.316784, 0) },
            B = { pos = Vector( -9868.986328,  -561.558167, -15472.467773), ang = Angle(-12.968955,   23.316784, 0) },
            fov = 70,
        },
        {
            A = { pos = Vector( -9267.972656,  -686.407227, -15552.825195), ang = Angle( -7.077361,  124.833542, 0) },
            B = { pos = Vector( -9558.978516,  -889.043152, -15552.825195), ang = Angle( -6.986721,  124.833542, 0) },
            fov = 70,
        },
        {
            A = { pos = Vector( -9892.075195,  -472.762695, -15134.005859), ang = Angle( 52.019917,   -0.159037, 0) },
            B = { pos = Vector( -9741.802734,  -473.180542, -15290.924805), ang = Angle( 52.110558,   -0.159037, 0) },
            fov = 70,
        },
        {
            A = { pos = Vector( -9246.974609,  -406.271576, -15548.214844), ang = Angle( -6.171997, -163.651718, 0) },
            B = { pos = Vector( -9402.320312,   -62.330376, -15548.214844), ang = Angle( -5.628157, -146.249313, 0) },
            fov = 70,
        },
    },
}

C.MainMenu = {
    Background = {
        pos = Vector(1278.792969, -2519.910156, -15027.968750),
        ang = Angle(-21.051146, -96.973534, 0),
        fov = 70,
    },
    SpawnPoint = {
        pos = Vector(1227.960327, -1938.260620, -14864.468750),
        ang = Angle(4.614168, -85.654907, 0),
    },

    LobbySpots = {
        { pos = Vector(-9547.367188, -469.474670, -15687.968750), ang = Angle(4.622638, -179.716934, 0) },
        { pos = Vector(-9697.229492, -468.490173, -15687.968750), ang = Angle(3.897518,  179.104767, 0) },
        { pos = Vector(-9879.806641, -465.637207, -15687.968750), ang = Angle(3.897518,  179.104767, 0) },
        { pos = Vector(-9442.896484, -472.463989, -15687.968750), ang = Angle(3.897518,  179.104767, 0) },
        { pos = Vector(-9300.863281, -474.683380, -15687.968750), ang = Angle(3.988158,  179.104767, 0) },
    },
    LoadingHoldDuration   = 5.0,
    LoadingFadeInDuration = 1.4,

    OpenWorldBanner = {
        Title    = "MERGE EMPIRES",
        URL      = "",
        Material = "",
        Tag      = "PLAY NOW",
    },

    TrainingBanner = {
        Title    = "TRAINING",
        URL      = "",
        Material = "",
    },

    OpenWorld = {
        Maps = {
            {
                Key   = "desert",
                Title = "BREAKTIDE",
                Image = "",
            },
        },
    },

    LoadingMessages = {
        joining_lobby = "Creating lobby",
        joining_game  = "Connecting to match",
        loading_data  = "Loading data",
    },

    ModeBanners = {
        casual = "asset://garrysmod/materials/mergeempires/banner/me_banner_casual.png",
        blitz  = "asset://garrysmod/materials/mergeempires/banner/me_banner_blitz.png",
    },
    ModeBannerDefault = "asset://garrysmod/materials/mergeempires/banner/me_banner_casual.png",
    MapBanners = {
        desert = "asset://garrysmod/materials/mergeempires/banner/me_banner_casual.png",
    },

    MatchLoading = {
        MapName     = "BREAKTIDE",
        Banner      = "asset://garrysmod/materials/mergeempires/loading/me_loading_shroud.png",
        MinDuration = 4.0,
        FadeIn      = 0.55,
        FadeBlack   = 0.7,
        WakeFade    = 1.7,
    },
}

C.Shop = {
    DefaultTab = "skins",
    Skins = {
        {
            title = "SWAT",
            items = {
                { id = "swat_1", name = "", price = 790,  rarity = "common" },
                { id = "swat_2", name = "", price = 790,  rarity = "common" },
                { id = "swat_3", name = "", price = 790,  rarity = "common" },
                { id = "swat_4", name = "", price = 790,  rarity = "common" },
                { id = "swat_5", name = "", price = 1490, rarity = "rare" },
            },
        },
        {
            title = "WWI",
            items = {
                { id = "wwi_1", name = "", price = 790,  rarity = "common" },
                { id = "wwi_2", name = "", price = 790,  rarity = "common" },
                { id = "wwi_3", name = "", price = 790,  rarity = "common" },
                { id = "wwi_4", name = "", price = 790,  rarity = "common" },
                { id = "wwi_5", name = "", price = 1490, rarity = "rare" },
            },
        },
    },
    Gems = {
        { id = "gem_320",  amount = 320,  bonus = "",           icon = "me_sardine_gems.png" },
        { id = "gem_1600", amount = 1600, bonus = "",           icon = "me_case_gems.png" },
        { id = "gem_3580", amount = 3580, bonus = "12% BONUS!", icon = "me_ammobox_gems.png" },
    },
}

C.Inventory = {
    Slots = 33,
}

C.Chat = {
    MaxLength = 50,
    BanWords = {
        "merde", "putain", "connard", "connasse", "salope", "salaud", "salopard", "pute", "pétasse", "petasse",
        "encule", "enculé", "enfoire", "enfoiré", "batard", "bâtard", "abruti", "debile", "débile", "cretin", "crétin",
        "con", "conne", "pd", "pédé", "pede", "tg", "ntm", "fdp", "bite", "couille", "couilles", "nique", "niquer",
        "chier", "chiotte", "bordel", "foutre", "ordure", "raclure", "trouduc", "branleur", "pouffiasse", "tapette",
        "negre", "nègre", "bougnoule",
        "fuck", "fucker", "fucking", "fuckers", "shit", "shite", "bitch", "bitches", "asshole", "bastard", "cunt",
        "dick", "pussy", "whore", "slut", "faggot", "fag", "retard", "retarded", "motherfucker", "cock", "prick",
        "twat", "wanker", "bollocks", "bullshit", "dumbass", "jackass", "nigger", "nigga", "douchebag",
    },
}

C.HideWhileMenuOpen = {
    { Global = "MEHUD", Field = "Panel" },
}

C.Server = {
    IntroDuration = 15.0,
    Resources = {
        "sound/mergeempires/music/intro.mp3",
        "sound/mergeempires/intro/pegi.mp3",
        "sound/mergeempires/intro/esrb.mp3",
        "sound/mergeempires/music/background.mp3",
        "materials/mergeempires/intro/pegi.png",
        "materials/mergeempires/intro/esrb.png",
    },
}

C.NetStrings = {
    Start        = "ME_Cinematic_Start",
    Stop         = "ME_Cinematic_Stop",
    Config       = "ME_Cinematic_Config",
    PlayerReady  = "ME_Cinematic_PlayerReady",
}

C.Assets = {
    SoundIntro      = "sound/mergeempires/music/intro.mp3",
    SoundPegi       = "sound/mergeempires/intro/pegi.mp3",
    SoundEsrb       = "sound/mergeempires/intro/esrb.mp3",
    SoundBackground = "sound/mergeempires/music/background.mp3",
    SoundHover      = "asset://garrysmod/sound/mergeempires/hover.mp3",
    SoundRefuse     = "asset://garrysmod/sound/mergeempires/refuse.mp3",
    SoundPurchase   = "asset://garrysmod/sound/mergeempires/menu/purchase.mp3",
    ImagePegi       = "asset://garrysmod/materials/mergeempires/intro/pegi.png",
    ImageEsrb       = "asset://garrysmod/materials/mergeempires/intro/esrb.png",
}
