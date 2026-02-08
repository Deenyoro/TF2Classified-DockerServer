/*
    ===Versus Saxton Hale Mode===
    Created by Rainbolt Dash (formerly Dr.Eggman): programmer, model-maker, mapper.
    Notoriously famous for creating plugins with terrible code and then abandoning them
    
    FlaminSarge - He makes cool things. He improves on terrible things until they're good.
    Chdata - A Hale enthusiast and a coder. An Integrated Data Sentient Entity.
    nergal - Added some very nice features to the plugin and fixed important bugs.
    
    New plugin thread on AlliedMods: https://forums.alliedmods.net/showthread.php?p=2167912
*/
#define PLUGIN_VERSION "1.55"
#pragma semicolon 1
#include <tf2_stocks>
#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS
#include <regex>
#if SOURCEMOD_V_MINOR > 7
  //#pragma newdecls required
#endif
#include <clientprefs>
#include <sdkhooks>
#include <morecolors>
#include <sourcemod>
#include <nextmap>
#include <saxtonhale>

#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>         // Set up this way, not including any of these prevents VSH's integration for them from running at all.
#tryinclude <goomba>                // But if one is included, VSH can still run with or without that plugin actually being there / working.
#tryinclude <rtd>                   // It just won't use them if they are not there, and use them if they're loaded.
#define REQUIRE_PLUGIN

static bool:g_bSteamToolsIsRunning = false;
static bool:g_bTF2AttributesIsRunning = false;
//static bool:g_bGoombaStompIsRunning = false;     // Not necessary, because we only use callbacks from these plugins - we don't call any natives ourself.
//static bool:g_bRollTheDiceIsRunning = false;

#define CBS_MAX_ARROWS 9

#define EASTER_BUNNY_ON         // Add a "//" before this line [or delete it] to remove the easter bunny
#define OVERRIDE_MEDIGUNS_ON    // Blocking this will make all mediguns be visually replaced with a kritkrieg model instead of keeping their reskinned versions

// Not recommended to change the super jump defines below without knowing how they work.
#define HALEHHH_TELEPORTCHARGETIME 2
#define HALE_JUMPCHARGETIME 1

#define HALEHHH_TELEPORTCHARGE (25 * HALEHHH_TELEPORTCHARGETIME)
#define HALE_JUMPCHARGE (25 * HALE_JUMPCHARGETIME)
       
#define TF_MAX_PLAYERS          65             //  Sourcemod supports up to 64 players? Too bad TF2 doesn't. 33 player server +1 for 0 (console/world)
#define MAX_ENTITIES            2049           //  This is probably TF2 specific
#define MAX_CENTER_TEXT         192            //  PrintCenterText()

#define FCVAR_VERSION           FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT

// Player team values from Team Fortress 2... but without the annoying enum type thing
#define TEAM_UNOWEN             0
#define TEAM_SPEC               1
#define TEAM_RED                2
#define TEAM_BLU                3

#define MAX_INT                 2147483647     //  PriorityCenterText
#define MIN_INT                 -2147483648    //  PriorityCenterText
#define MAX_DIGITS              12             //  10 + \0 for IntToString. And negative signs.

// TF2 Weapon Loadout Slots
enum
{
    TFWeaponSlot_DisguiseKit = 3,
    TFWeaponSlot_Watch = 4,
    TFWeaponSlot_DestroyKit = 4,
    TFWeaponSlot_BuildKit = 5
}

// m_lifeState
enum
{
    LifeState_Alive = 0,
    LifeState_Dead = 2
}

//  For IsDate()
enum
{
    Month_None = 0,
    Month_Jan,
    Month_Feb,
    Month_Mar,
    Month_Apr,
    Month_May,
    Month_Jun,
    Month_Jul,
    Month_Aug,
    Month_Sep,
    Month_Oct,
    Month_Nov,
    Month_Dec
}

// Default stock weapon item definition indexes for GunmettleToIndex()
enum
{
    TFWeapon_Invalid = -1,

    TFWeapon_SniperRifle = 14,
    TFWeapon_SMG = 16,
    TFWeapon_Scattergun = 13,

    TFWeapon_Shotgun = 10,
    TFWeapon_ShotgunSoldier = 10,
    TFWeapon_ShotgunPyro = 12,
    TFWeapon_ShotgunHeavy = 11,
    TFWeapon_ShotgunEngie = 9,

    TFWeapon_Minigun = 15,
    TFWeapon_Flamethrower = 21,
    TFWeapon_RocketLauncher = 18,
    TFWeapon_Medigun = 29,
    TFWeapon_StickyLauncher = 20,
    TFWeapon_Revolver = 24,

    TFWeapon_Pistol = 23,
    TFWeapon_PistolScout = 23,
    TFWeapon_PistolEngie = 22
}

// TF2 Weapon qualities
enum 
{
    TFQual_None = -1,       // Probably should never actually set an item's quality to this
    TFQual_Normal = 0,
    TFQual_NoInspect = 0,   // Players cannot see your attributes - NO LONGER WORKS due to Gunmettle update.
    TFQual_Rarity1,
    TFQual_Genuine = 1,
    TFQual_Rarity2,
    TFQual_Level = 2,       //  Same color as "Level # Weapon" text in description
    TFQual_Vintage,
    TFQual_Rarity3,         //  Is actually 4 - sort of brownish
    TFQual_Rarity4,
    TFQual_Unusual = 5,
    TFQual_Unique,
    TFQual_Community,
    TFQual_Developer,
    TFQual_Selfmade,
    TFQual_Customized,
    TFQual_Strange,
    TFQual_Completed,
    TFQual_Haunted,         //  13
    TFQual_Collectors
}

// START FILE DEFINTIONS & ENUMS

enum e_flNext
{
    e_flNextBossTaunt = 0,
    e_flNextAllowBossSuicide,
    e_flNextAllowOtherSpawnTele,
    e_flNextBossKillSpreeEnd,
    e_flNextHealthQuery
}

enum e_flNext2
{
    e_flNextEndPriority = 0
}

// Saxton Hale Files

// Model
//#define HaleModel               "models/player/saxton_hale/saxton_hale.mdl"
#define HaleModel               "models/player/saxton_test4/saxton_hale_test4.mdl"

// Materials

static const String:HaleMatsV2[][] = {
    "materials/models/player/saxton_test4/eyeball_l.vmt",
    "materials/models/player/saxton_test4/eyeball_r.vmt",
    "materials/models/player/saxton_test4/halebody.vmt",
    "materials/models/player/saxton_test4/halebody.vtf",
    "materials/models/player/saxton_test4/halebodyexponent.vtf",
    "materials/models/player/saxton_test4/halehead.vmt",
    "materials/models/player/saxton_test4/halehead.vtf",
    "materials/models/player/saxton_test4/haleheadexponent.vtf",
    "materials/models/player/saxton_test4/halenormal.vtf",
    "materials/models/player/saxton_test4/halephongmask.vtf"
    //"materials/models/player/saxton_test4/halegibs.vmt",
    //"materials/models/player/saxton_test4/halegibs.vtf"
};

// SFX
#define HaleYellName            "saxton_hale/saxton_hale_responce_1a.wav"
#define HaleRageSoundB          "saxton_hale/saxton_hale_responce_1b.wav"
#define HaleComicArmsFallSound  "saxton_hale/saxton_hale_responce_2.wav"
#define HaleLastB               "vo/announcer_am_lastmanalive"

#define HaleKSpree              "saxton_hale/saxton_hale_responce_3.wav"
//HaleKSpree2 - this line is broken and unused
#define HaleKSpree2             "saxton_hale/saxton_hale_responce_4.wav"

//===New responces===
#define HaleRoundStart          "saxton_hale/saxton_hale_responce_start"                // 1-5
#define HaleJump                "saxton_hale/saxton_hale_responce_jump"                 // 1-2
#define HaleRageSound           "saxton_hale/saxton_hale_responce_rage"                 // 1-4
#define HaleKillMedic           "saxton_hale/saxton_hale_responce_kill_medic.wav"
#define HaleKillSniper1         "saxton_hale/saxton_hale_responce_kill_sniper1.wav"
#define HaleKillSniper2         "saxton_hale/saxton_hale_responce_kill_sniper2.wav"
#define HaleKillSpy1            "saxton_hale/saxton_hale_responce_kill_spy1.wav"
#define HaleKillSpy2            "saxton_hale/saxton_hale_responce_kill_spy2.wav"
#define HaleKillEngie1          "saxton_hale/saxton_hale_responce_kill_eggineer1.wav"
#define HaleKillEngie2          "saxton_hale/saxton_hale_responce_kill_eggineer2.wav"
#define HaleKSpreeNew           "saxton_hale/saxton_hale_responce_spree"                // 1-5
#define HaleWin                 "saxton_hale/saxton_hale_responce_win"                  // 1-2
#define HaleLastMan             "saxton_hale/saxton_hale_responce_lastman"              // 1-5
//#define HaleLastMan2Fixed     "saxton_hale/saxton_hale_responce_lastman2.wav"
#define HaleFail                "saxton_hale/saxton_hale_responce_fail"                 // 1-3

//===1.32 responces===
#define HaleJump132             "saxton_hale/saxton_hale_132_jump_"                     // 1-2
#define HaleStart132            "saxton_hale/saxton_hale_132_start_"                    // 1-5
#define HaleKillDemo132         "saxton_hale/saxton_hale_132_kill_demo.wav"
#define HaleKillEngie132        "saxton_hale/saxton_hale_132_kill_engie_"               // 1-2
#define HaleKillHeavy132        "saxton_hale/saxton_hale_132_kill_heavy.wav"
#define HaleKillScout132        "saxton_hale/saxton_hale_132_kill_scout.wav"
#define HaleKillSpy132          "saxton_hale/saxton_hale_132_kill_spie.wav"
#define HaleKillPyro132         "saxton_hale/saxton_hale_132_kill_w_and_m1.wav"
#define HaleSappinMahSentry132  "saxton_hale/saxton_hale_132_kill_toy.wav"
#define HaleKillKSpree132       "saxton_hale/saxton_hale_132_kspree_"                   // 1-2
#define HaleKillLast132         "saxton_hale/saxton_hale_132_last.wav"
#define HaleStubbed132          "saxton_hale/saxton_hale_132_stub_"                     // 1-4

// Unused
//#define HaleEnabled             QueuePanelH(Handle:0, MenuAction:0, 9001, 0)


// Christian Brutal Sniper Files

// Model
#define CBSModel                "models/player/saxton_hale/cbs_v4.mdl"

// Materials
// Prepared Manually

// SFX
#define CBSTheme                "saxton_hale/the_millionaires_holiday.mp3"
#define CBS0                    "vo/sniper_specialweapon08.mp3"
#define CBS1                "vo/taunts/sniper_taunts02.mp3"
#define CBS2                    "vo/sniper_award"
#define CBS3                "vo/sniper_battlecry03.mp3"
#define CBS4                    "vo/sniper_domination"
#define CBSJump1                "vo/sniper_specialcompleted02.mp3"

// Unused
//#define ShivModel               "models/weapons/c_models/c_wood_machete/c_wood_machete.mdl"


// Horseless Headless Horsemann Files

// Model
#define HHHModel                "models/player/saxton_hale/hhh_jr_mk3.mdl"

// Materials

// SFX
#define HHHLaught               "vo/halloween_boss/knight_laugh"
#define HHHRage                 "vo/halloween_boss/knight_attack01.mp3"
#define HHHRage2                "vo/halloween_boss/knight_alert.mp3"
#define HHHAttack               "vo/halloween_boss/knight_attack"

#define HHHTheme                "ui/holiday/gamestartup_halloween.mp3"

// Unused
//#define AxeModel                "models/weapons/c_models/c_headtaker/c_headtaker.mdl"


// Vagineer Files

// Model
#define VagineerModel           "models/player/saxton_hale/vagineer_v150.mdl"

// Materials
// None! He uses Engineer's stuff

// SFX
#define VagineerLastA           "saxton_hale/lolwut_0.wav"
#define VagineerRageSound       "saxton_hale/lolwut_2.wav"
#define VagineerStart           "saxton_hale/lolwut_1.wav"
#define VagineerKSpree          "saxton_hale/lolwut_3.wav"
#define VagineerKSpree2         "saxton_hale/lolwut_4.wav"
#define VagineerHit             "saxton_hale/lolwut_5.wav"

//===New Vagineer's responces===
#define VagineerRoundStart      "saxton_hale/vagineer_responce_intro.wav"
#define VagineerJump            "saxton_hale/vagineer_responce_jump_"         //  1-2
#define VagineerRageSound2      "saxton_hale/vagineer_responce_rage_"         //  1-4
#define VagineerKSpreeNew       "saxton_hale/vagineer_responce_taunt_"        //  1-5
#define VagineerFail            "saxton_hale/vagineer_responce_fail_"         //  1-2

// Unused
//#define VagineerModel           "models/player/saxton_hale/vagineer_v150.mdl"
//#define WrenchModel             "models/weapons/w_models/w_wrench.mdl"


#if defined EASTER_BUNNY_ON
// Easter Bunny Files

// Model
#define BunnyModel              "models/player/saxton_hale/easter_demo.mdl"
#define EggModel                "models/player/saxton_hale/w_easteregg.mdl"

// Materials
static const String:BunnyMaterials[][] = {
    "materials/models/player/easter_demo/demoman_head_red.vmt",
    "materials/models/player/easter_demo/easter_body.vmt",
    "materials/models/player/easter_demo/easter_body.vtf",
    "materials/models/player/easter_demo/easter_rabbit.vmt",
    "materials/models/player/easter_demo/easter_rabbit.vtf",
    "materials/models/player/easter_demo/easter_rabbit_normal.vtf",
    "materials/models/player/easter_demo/eyeball_r.vmt"
    // "materials/models/player/easter_demo/demoman_head_blue_invun.vmt", // This is for the new version of easter demo which VSH isn't using
    // "materials/models/player/easter_demo/demoman_head_red_invun.vmt",
    // "materials/models/player/easter_demo/easter_rabbit_blue.vmt",
    // "materials/models/player/easter_demo/easter_rabbit_blue.vtf",
    // "materials/models/player/easter_demo/easter_rabbit_invun.vmt",
    // "materials/models/player/easter_demo/easter_rabbit_invun.vtf",
    // "materials/models/player/easter_demo/easter_rabbit_invun_blue.vmt",
    // "materials/models/player/easter_demo/easter_rabbit_invun_blue.vtf",
    // "materials/models/player/easter_demo/eyeball_invun.vmt"
};

// SFX
static const String:BunnyWin[][] = {
    "vo/demoman_gibberish01.mp3",
    "vo/demoman_gibberish12.mp3",
    "vo/demoman_cheers02.mp3",
    "vo/demoman_cheers03.mp3",
    "vo/demoman_cheers06.mp3",
    "vo/demoman_cheers07.mp3",
    "vo/demoman_cheers08.mp3",
    "vo/taunts/demoman_taunts12.mp3"
};

static const String:BunnyJump[][] = {
    "vo/demoman_gibberish07.mp3",
    "vo/demoman_gibberish08.mp3",
    "vo/demoman_laughshort01.mp3",
    "vo/demoman_positivevocalization04.mp3"
};

static const String:BunnyRage[][] = {
    "vo/demoman_positivevocalization03.mp3",
    "vo/demoman_dominationscout05.mp3",
    "vo/demoman_cheers02.mp3"
};

static const String:BunnyFail[][] = {
    "vo/demoman_gibberish04.mp3",
    "vo/demoman_gibberish10.mp3",
    "vo/demoman_jeers03.mp3",
    "vo/demoman_jeers06.mp3",
    "vo/demoman_jeers07.mp3",
    "vo/demoman_jeers08.mp3"
};

static const String:BunnyKill[][] = {
    "vo/demoman_gibberish09.mp3",
    "vo/demoman_cheers02.mp3",
    "vo/demoman_cheers07.mp3",
    "vo/demoman_positivevocalization03.mp3"
};

static const String:BunnySpree[][] = {
    "vo/demoman_gibberish05.mp3",
    "vo/demoman_gibberish06.mp3",
    "vo/demoman_gibberish09.mp3",
    "vo/demoman_gibberish11.mp3",
    "vo/demoman_gibberish13.mp3",
    "vo/demoman_autodejectedtie01.mp3"
};

static const String:BunnyLast[][] = {
    "vo/taunts/demoman_taunts05.mp3",
    "vo/taunts/demoman_taunts04.mp3",
    "vo/demoman_specialcompleted07.mp3"
};

static const String:BunnyPain[][] = {
    "vo/demoman_sf12_badmagic01.mp3",
    "vo/demoman_sf12_badmagic07.mp3",
    "vo/demoman_sf12_badmagic10.mp3"
};

static const String:BunnyStart[][] = {
    "vo/demoman_gibberish03.mp3",
    "vo/demoman_gibberish11.mp3"
};

static const String:BunnyRandomVoice[][] = {
    "vo/demoman_positivevocalization03.mp3",
    "vo/demoman_jeers08.mp3",
    "vo/demoman_gibberish03.mp3",
    "vo/demoman_cheers07.mp3",
    "vo/demoman_sf12_badmagic01.mp3",
    "vo/burp02.mp3",
    "vo/burp03.mp3",
    "vo/burp04.mp3",
    "vo/burp05.mp3",
    "vo/burp06.mp3",
    "vo/burp07.mp3"
};

// Unused
//#define ReloadEggModel          "models/player/saxton_hale/c_easter_cannonball.mdl"
#endif

// END FILE DEFINTIONS

#define SOUNDEXCEPT_MUSIC 0
#define SOUNDEXCEPT_VOICE 1
new OtherTeam = 2;
new HaleTeam = 3;
new VSHRoundState = VSHRState_Disabled;
new playing;
new healthcheckused;
new RedAlivePlayers;
new RoundCount;
new Special;
new Incoming;

static bool:g_bReloadVSHOnRoundEnd = false;

static Damage[TF_MAX_PLAYERS];
static AirDamage[TF_MAX_PLAYERS]; // Air Strike
static curHelp[TF_MAX_PLAYERS];
static uberTarget[TF_MAX_PLAYERS];
#define VSHFLAG_HELPED          (1 << 0)
#define VSHFLAG_UBERREADY       (1 << 1)
#define VSHFLAG_NEEDSTODUCK (1 << 2)
#define VSHFLAG_BOTRAGE     (1 << 3)
#define VSHFLAG_CLASSHELPED (1 << 4)
#define VSHFLAG_HASONGIVED  (1 << 5)
static VSHFlags[TF_MAX_PLAYERS];
static Hale = -1;
static HaleHealthMax;
static HaleHealth;
static HaleHealthLast;
static HaleCharge = 0;
static HaleRage;
static NextHale;
static Float:g_flStabbed;
static Float:g_flMarketed;
//static Float:HPTime;
//static Float:KSpreeTimer;
static Float:WeighDownTimer;
static KSpreeCount = 1;
static Float:UberRageCount;
static Float:GlowTimer;
static bool:bEnableSuperDuperJump;
//static bool:bTenSecStart[2] = {false, false};
static bool:bSpawnTeleOnTriggerHurt = false;
static HHHClimbCount;
//static bool:bNoTaunt = false;
static Handle:cvarCanBossRTD;
static Handle:cvarReboundFromBossGoomba; // These apply when you goomba stomp the boss.
static Handle:cvarDmgMultFromBossGoomba; // To change what happens when the boss goomba stomps mercenaries, use goomba stomp's original convars.
static Handle:cvarDmgAddFromBossGoomba;
static Handle:cvarCanBossGoombaStompPlayers; // Whether or not the boss can trigger goomba stomp against mercenaries. Does not affect whether or not players can goomba the boss.
static Handle:cvarCanWeMantreadGoomba;
static Handle:cvarVersion;
static Handle:cvarHaleSpeed;
static Handle:cvarPointDelay;
static Handle:cvarRageDMG;
static Handle:cvarRageDist;
static Handle:cvarAnnounce;
static Handle:cvarSpecials;
static Handle:cvarEnabled;
static Handle:cvarAliveToEnable;
static Handle:cvarPointType;
static Handle:cvarCrits;
static Handle:cvarRageSentry;
static Handle:cvarFirstRound;
static Handle:cvarDemoShieldCrits;
static Handle:cvarDisplayHaleHP;
//static Handle:cvarCircuitStun;
//static Handle:cvarForceSpecToHale;
static Handle:cvarEnableEurekaEffect;
static Handle:cvarForceHaleTeam;
static Handle:PointCookie;
static Handle:MusicCookie;
static Handle:VoiceCookie;
static Handle:ClasshelpinfoCookie;
static Handle:doorchecktimer;
static Handle:jumpHUD;
static Handle:rageHUD;
static Handle:healthHUD;
static Handle:infoHUD;
static bool:g_bEnabled = false;
static bool:g_bAreEnoughPlayersPlaying = false;
static Float:HaleSpeed = 340.0;
static PointDelay = 6;
static RageDMG = 3500;
static Float:RageDist = 800.0;
static Float:Announce = 120.0;
static bSpecials = true;
static AliveToEnable = 5;
static PointType = 0;
static bool:haleCrits = false;
static bool:bDemoShieldCrits = false;
static bool:bAlwaysShowHealth = true;
static bool:newRageSentry = true;
//static Float:circuitStun = 0.0;
static Handle:MusicTimer;
static TeamRoundCounter;
static botqueuepoints = 0;
static String:currentmap[99];
static bool:checkdoors = false;
static bool:PointReady;
static tf_arena_use_queue;
static mp_teams_unbalance_limit;
static tf_arena_first_blood;
static mp_forcecamera;
static Float:tf_scout_hype_pep_max;
static tf_dropped_weapon_lifetime;
static Float:tf_feign_death_activate_damage_scale, Float:tf_feign_death_damage_scale, Float:tf_stealth_damage_reduction, Float:tf_feign_death_duration, Float:tf_feign_death_speed_duration; // Cloak damage fixes
static defaulttakedamagetype;

static const String:haleversiontitles[][] =     //the last line of this is what determines the displayed plugin version
{
    "1.0", "1.1", "1.11", "1.12", "1.2", "1.22", "1.23", "1.24", "1.25", "1.26", "Christian Brutal Sniper", "1.28", "1.29", "1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.35_3", "1.36", "1.36", "1.36", "1.36", "1.36", "1.36", "1.362", "1.363", "1.364", "1.365", "1.366", "1.367", "1.368", "1.369", "1.369", "1.369", "1.37", "1.37b", "1.38", "1.38", "1.39beta", "1.39beta", "1.39beta", "1.39c", "1.39c", "1.39c", "1.40", "1.41", "1.42", "1.43", "1.43", "1.43", "1.44", "1.44", "1.45", "1.45", "1.45", "1.45", "1.45", "1.46", "1.46", "1.46", "1.47", "1.47", "1.48", "1.48", "1.49", "1.50",
    "1.51", // 1.38 - (15 Nov 2011)
    "1.52",
    "1.53",
    "1.53",
    "1.54",
    "1.54",
    "1.54"
    ,PLUGIN_VERSION
};
static const String:haleversiondates[][] =
{
    "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "--", "25 Aug 2011", "26 Aug 2011", "09 Oct 2011", "09 Oct 2011", "09 Oct 2011", "15 Nov 2011", "15 Nov 2011", "17 Dec 2011", "17 Dec 2011", "05 Mar 2012", "05 Mar 2012", "05 Mar 2012", "16 Jul 2012", "16 Jul 2012", "16 Jul 2012", "10 Oct 2012", "25 Feb 2013", "30 Mar 2013", "14 Jul 2014", "15 Jul 2014", "15 Jul 2014", "15 Jul 2014", "15 Jul 2014", "18 Jul 2014", "17 Jul 2014", "17 Jul 2014", "17 Jul 2014", "17 Jul 2014", "27 Jul 2014", "19 Jul 2014", "19 Jul 2014", "04 Aug 2014", "04 Aug 2014", "14 Aug 2014", "14 Aug 2014", "18 Aug 2014", "04 Oct 2014",
    "29 Oct 2014", //  An update I never bothered to throw outdate
    "25 Dec 2014", //  Merry Xmas
    "10 Sep 2015",
    "9 Mar 2015",  // This has to do with page ordering
    "11 Sep 2015", // This will appear as the final page of the 1.54 updates
    "10 Sep 2015",
    "10 Sep 2015",
    "12 Sep 2015"  // 1.55 update
};
static const maxversion = (sizeof(haleversiontitles) - 1);
new Handle:OnHaleJump;
new Handle:OnHaleRage;
new Handle:OnHaleWeighdown;
new Handle:OnMusic;
new Handle:OnHaleNext;

//new Handle:hEquipWearable;
//new Handle:hSetAmmoVelocity;

/*new Handle:OnIsVSHMap;
new Handle:OnIsEnabled;
new Handle:OnGetHale;
new Handle:OnGetTeam;
new Handle:OnGetSpecial;
new Handle:OnGetHealth;
new Handle:OnGetHealthMax;
new Handle:OnGetDamage;
new Handle:OnGetRoundState;*/

//new bool:ACH_Enabled;
public Plugin:myinfo = {
    name = "Versus Saxton Hale",
    author = "Rainbolt Dash, FlaminSarge, Chdata, nergal, fiagram",
    description = "RUUUUNN!! COWAAAARRDSS!",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2167912",
};

// Check for whether or not optional plugins are running and relay that info to VSH.
public OnAllPluginsLoaded()
{
    g_bSteamToolsIsRunning    = LibraryExists("SteamTools");
    g_bTF2AttributesIsRunning = LibraryExists("tf2attributes");
    //g_bGoombaStompIsRunning   = LibraryExists("goomba");
    //g_bRollTheDiceIsRunning   = LibraryExists("TF2: Roll the Dice");
}

public OnLibraryAdded(const String:name[])
{
    SetPluginDetection(name, true);
}

public OnLibraryRemoved(const String:name[])
{
    SetPluginDetection(name, false);
}

SetPluginDetection(const String:name[], bool:bBool)
{
    if (StrEqual(name, "SteamTools"))
    {
        g_bSteamToolsIsRunning = bBool;
    }
    else if (StrEqual(name, "tf2attributes"))
    {
        g_bTF2AttributesIsRunning = bBool;
    }
    /*else if (StrEqual(name, "goomba"))
    {
        g_bGoombaStompIsRunning = bBool;
    }
    else if (StrEqual(name, "TF2: Roll the Dice"))
    {
        g_bRollTheDiceIsRunning = bBool;
    }*/
    /*else if (StrEqual(name, "hale_achievements"))
    {
        ACH_Enabled = bBool;
    }*/
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    MarkNativeAsOptional("GetUserMessageType");
    MarkNativeAsOptional("PbSetInt");
    MarkNativeAsOptional("PbSetBool");
    MarkNativeAsOptional("PbSetString");
    MarkNativeAsOptional("PbAddString");
/*  CreateNative("VSH_IsSaxtonHaleModeMap", Native_IsVSHMap);
    OnIsVSHMap = CreateGlobalForward("VSH_OnIsSaxtonHaleModeMap", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_IsSaxtonHaleModeEnabled", Native_IsEnabled);
    OnIsEnabled = CreateGlobalForward("VSH_OnIsSaxtonHaleModeEnabled", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetSaxtonHaleUserId", Native_GetHale);
    OnGetHale = CreateGlobalForward("VSH_OnGetSaxtonHaleUserId", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetSaxtonHaleTeam", Native_GetTeam);
    OnGetTeam = CreateGlobalForward("VSH_OnGetSaxtonHaleTeam", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetSpecialRoundIndex", Native_GetSpecial);
    OnGetSpecial = CreateGlobalForward("VSH_OnGetSpecialRoundIndex", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetSaxtonHaleHealth", Native_GetHealth);
    OnGetHealth = CreateGlobalForward("VSH_OnGetSaxtonHaleHealth", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetSaxtonHaleHealthMax", Native_GetHealthMax);
    OnGetHealthMax = CreateGlobalForward("VSH_OnGetSaxtonHaleHealthMax", ET_Hook, Param_CellByRef);
    
    CreateNative("VSH_GetClientDamage", Native_GetDamage);
    OnGetDamage = CreateGlobalForward("VSH_OnGetClientDamage", ET_Hook, Param_Cell,Param_CellByRef);
    
    CreateNative("VSH_GetRoundState", Native_GetRoundState);
    OnGetRoundState = CreateGlobalForward("VSH_OnGetRoundState", ET_Hook, Param_CellByRef);*/

    CreateNative("VSH_IsSaxtonHaleModeMap", Native_IsVSHMap);
    CreateNative("VSH_IsSaxtonHaleModeEnabled", Native_IsEnabled);
    CreateNative("VSH_GetSaxtonHaleUserId", Native_GetHale);
    CreateNative("VSH_GetSaxtonHaleTeam", Native_GetTeam);
    CreateNative("VSH_GetSpecialRoundIndex", Native_GetSpecial);
    CreateNative("VSH_GetSaxtonHaleHealth", Native_GetHealth);
    CreateNative("VSH_GetSaxtonHaleHealthMax", Native_GetHealthMax);
    CreateNative("VSH_GetClientDamage", Native_GetDamage);
    CreateNative("VSH_GetRoundState", Native_GetRoundState);
    OnHaleJump = CreateGlobalForward("VSH_OnDoJump", ET_Hook, Param_CellByRef);
    OnHaleRage = CreateGlobalForward("VSH_OnDoRage", ET_Hook, Param_FloatByRef);
    OnHaleWeighdown = CreateGlobalForward("VSH_OnDoWeighdown", ET_Hook);
    OnMusic = CreateGlobalForward("VSH_OnMusic", ET_Hook, Param_String, Param_FloatByRef);
    OnHaleNext = CreateGlobalForward("VSH_OnHaleNext", ET_Hook, Param_Cell);
    RegPluginLibrary("saxtonhale");
#if defined _steamtools_included
    MarkNativeAsOptional("Steam_SetGameDescription");
#endif
    return APLRes_Success;
}
/*InitGamedata()
{
#if defined EASTER_BUNNY_ON
    new Handle:hGameConf = LoadGameConfigFile("saxtonhale");
    if (hGameConf == INVALID_HANDLE)
    {
        SetFailState("[VSH] Unable to load gamedata file 'saxtonhale.txt'");
        return;
    }
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    hEquipWearable = EndPrepSDKCall();
    if (hEquipWearable == INVALID_HANDLE)
    {
        SetFailState("[VSH] Failed to initialize call to CTFPlayer::EquipWearable");
        return;
    }
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFAmmoPack::SetInitialVelocity");
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    hSetAmmoVelocity = EndPrepSDKCall();
    if (hSetAmmoVelocity == INVALID_HANDLE)
    {
        SetFailState("[VSH] Failed to initialize call to CTFAmmoPack::SetInitialVelocity");
        CloseHandle(hGameConf);
        return;
    }
    CloseHandle(hGameConf);
#endif
}*/
/*public Action:Command_Eggs(client, args)
{
    SpawnManyAmmoPacks(client, EggModel, 1);
}*/
public OnPluginStart()
{
//  InitGamedata();
//  RegAdminCmd("hale_eggs", Command_Eggs, ADMFLAG_ROOT);   //WILL CRASH.
    //ACH_Enabled=LibraryExists("hale_achievements");
    LogMessage("===Versus Saxton Hale Initializing - v%s===", haleversiontitles[maxversion]);
    cvarVersion = CreateConVar("hale_version", haleversiontitles[maxversion], "VS Saxton Hale Version", FCVAR_VERSION);
    cvarHaleSpeed = CreateConVar("hale_speed", "340.0", "Speed of Saxton Hale", FCVAR_NOTIFY);
    cvarPointType = CreateConVar("hale_point_type", "0", "Select condition to enable point (0 - alive players, 1 - time)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarPointDelay = CreateConVar("hale_point_delay", "6", "Addition (for each player) delay before point's activation.", FCVAR_NOTIFY);
    cvarAliveToEnable = CreateConVar("hale_point_alive", "5", "Enable control points when there are X people left alive.", FCVAR_NOTIFY);
    cvarRageDMG = CreateConVar("hale_rage_damage", "3500", "Damage required for Hale to gain rage", FCVAR_NOTIFY, true, 0.0);
    cvarRageDist  = CreateConVar("hale_rage_dist", "800.0", "Distance to stun in Hale's rage. Vagineer and CBS are /3 (/2 for sentries)", FCVAR_NOTIFY, true, 0.0);
    cvarAnnounce = CreateConVar("hale_announce", "120.0", "Info about mode will show every X seconds. Must be greater than 1.0 to show.", FCVAR_NOTIFY, true, 0.0);
    cvarSpecials = CreateConVar("hale_specials", "1", "Enable Special Rounds (Vagineer, HHH, CBS)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarEnabled = CreateConVar("hale_enabled", "1", "Do you really want set it to 0?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarCrits = CreateConVar("hale_crits", "0", "Can Hale get crits?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarDemoShieldCrits = CreateConVar("hale_shield_crits", "0", "Does Demoman's shield grant crits (1) or minicrits (0)?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarDisplayHaleHP = CreateConVar("hale_hp_display", "1", "Display Hale Health at all times.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarRageSentry = CreateConVar("hale_ragesentrydamagemode", "1", "If 0, to repair a sentry that has been damaged by rage, the Engineer must pick it up and put it back down.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarFirstRound = CreateConVar("hale_first_round", "0", "Disable(0) or Enable(1) VSH in 1st round.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    //cvarCircuitStun = CreateConVar("hale_circuit_stun", "0", "0 to disable Short Circuit stun, >0 to make it stun Hale for x seconds", FCVAR_NOTIFY, true, 0.0);
    //cvarForceSpecToHale = CreateConVar("hale_spec_force_boss", "0", "1- if a spectator is up next, will force them to Hale + spectators will gain queue points, else spectators are ignored by plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarEnableEurekaEffect = CreateConVar("hale_enable_eureka", "0", "1- allow Eureka Effect, else disallow", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarForceHaleTeam = CreateConVar("hale_force_team", "0", "0- Use plugin logic, 1- random team, 2- red, 3- blue", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    
    // 3rd Party Plugin integrations
    cvarCanBossGoombaStompPlayers = CreateConVar("hale_can_boss_goomba_stomp", "0", "Can the boss goomba mercenaries? 0 to disallow boss, 1 to allow boss (requires Goomba Stomp)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarCanWeMantreadGoomba = CreateConVar("hale_mantread_goomba", "0", "Can Soldier/Demo goomba and mantread at the same time? 0 = Soldier/Demo can only mantread if using boots | 1 = Soldier/Demo can get double stomps (requires Goomba Stomp)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarDmgMultFromBossGoomba = CreateConVar("vsh_boss_goomba_dmg_lifemultiplier", "0.025", "How much damage the boss will receive based on its remaining health. (requires Goomba Stomp)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarDmgAddFromBossGoomba = CreateConVar("vsh_boss_goomba_dmg_add", "450.0", "Add this amount of damage against the boss after vsh_boss_goomba_dmg_lifemultiplier calculation. (requires Goomba Stomp)", FCVAR_NOTIFY, true, 0.0);
    cvarReboundFromBossGoomba = CreateConVar("vsh_boss_goomba_rebound_power", "300.0", "How much velocity players should rebound after goomba stomping the boss (requires Goomba Stomp)", FCVAR_NOTIFY, true, 0.0);
    cvarCanBossRTD = CreateConVar("hale_boss_rtd", "0", "Can the boss use rtd? 0 to disallow boss, 1 to allow boss (requires Roll The Dice)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    // bFriendlyFire = GetConVarBool(FindConVar("mp_friendlyfire"));
    // HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_bot_count"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_arena_use_queue"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_arena_first_blood"), HideCvarNotify);
    HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_feign_death_activate_damage_scale"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_feign_death_damage_scale"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_feign_death_duration"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_feign_death_speed_duration"), HideCvarNotify);
    HookConVarChange(FindConVar("tf_stealth_damage_reduction"), HideCvarNotify);

    HookEvent("teamplay_round_start", event_round_start);
    HookEvent("teamplay_round_win", event_round_end);
    HookEvent("player_changeclass", event_changeclass);
    HookEvent("player_spawn", event_player_spawn);
    HookEvent("player_death", event_player_death, EventHookMode_Pre);
    HookEvent("player_chargedeployed", event_uberdeployed);
    HookEvent("player_hurt", event_hurt, EventHookMode_Pre);
    HookEvent("object_destroyed", event_destroy, EventHookMode_Pre);
    HookEvent("object_deflected", event_deflect, EventHookMode_Pre);

    OnPluginStart_TeleportToMultiMapSpawn(); // Setup adt_array

    HookUserMessage(GetUserMessageId("PlayerJarated"), event_jarate);
    HookConVarChange(cvarEnabled, CvarChange);
    HookConVarChange(cvarHaleSpeed, CvarChange);
    HookConVarChange(cvarRageDMG, CvarChange);
    HookConVarChange(cvarRageDist, CvarChange);
    HookConVarChange(cvarAnnounce, CvarChange);
    HookConVarChange(cvarSpecials, CvarChange);
    HookConVarChange(cvarPointType, CvarChange);
    HookConVarChange(cvarPointDelay, CvarChange);
    HookConVarChange(cvarAliveToEnable, CvarChange);
    HookConVarChange(cvarCrits, CvarChange);
    HookConVarChange(cvarDemoShieldCrits, CvarChange);
    HookConVarChange(cvarDisplayHaleHP, CvarChange);
    HookConVarChange(cvarRageSentry, CvarChange);
    //HookConVarChange(cvarCircuitStun, CvarChange);
    g_bReloadVSHOnRoundEnd = false;
    RegAdminCmd("sm_hale_reload", Debug_ReloadVSH, ADMFLAG_ROOT, "Reloads the VSH plugin safely and silently.");
    RegConsoleCmd("sm_hale", HalePanel);
    RegConsoleCmd("sm_hale_hp", Command_GetHPCmd);
    RegConsoleCmd("sm_halehp", Command_GetHPCmd);
    RegConsoleCmd("sm_hale_next", QueuePanelCmd);
    RegConsoleCmd("sm_halenext", QueuePanelCmd);
    RegConsoleCmd("sm_hale_help", HelpPanelCmd);
    RegConsoleCmd("sm_halehelp", HelpPanelCmd);
    RegConsoleCmd("sm_hale_class", HelpPanel2Cmd);
    RegConsoleCmd("sm_haleclass", HelpPanel2Cmd);
    RegConsoleCmd("sm_hale_classinfotoggle", ClasshelpinfoCmd);
    RegConsoleCmd("sm_haleclassinfotoggle", ClasshelpinfoCmd);
    RegConsoleCmd("sm_infotoggle", ClasshelpinfoCmd);
    RegConsoleCmd("sm_hale_new", NewPanelCmd);
    RegConsoleCmd("sm_halenew", NewPanelCmd);
//  RegConsoleCmd("hale_me", SkipHalePanelCmd);
//  RegConsoleCmd("haleme", SkipHalePanelCmd);
    RegConsoleCmd("sm_halemusic", MusicTogglePanelCmd);
    RegConsoleCmd("sm_hale_music", MusicTogglePanelCmd);
    RegConsoleCmd("sm_halevoice", VoiceTogglePanelCmd);
    RegConsoleCmd("sm_hale_voice", VoiceTogglePanelCmd);
    RegAdminCmd("sm_hale_resetqueuepoints", ResetQueuePointsCmd, 0);
    RegAdminCmd("sm_hale_resetq", ResetQueuePointsCmd, 0);
    RegAdminCmd("sm_halereset", ResetQueuePointsCmd, 0);
    RegAdminCmd("sm_resetq", ResetQueuePointsCmd, 0);
    RegAdminCmd("sm_hale_special", Command_MakeNextSpecial, 0, "Call a special to next round.");
    AddCommandListener(DoTaunt, "taunt");
    AddCommandListener(DoTaunt, "+taunt");
    AddCommandListener(cdVoiceMenu, "voicemenu");
    AddCommandListener(DoSuicide, "explode");
    AddCommandListener(DoSuicide, "kill");
    AddCommandListener(DoSuicide2, "jointeam");
    AddCommandListener(Destroy, "destroy");
    RegAdminCmd("sm_hale_select", Command_HaleSelect, ADMFLAG_CHEATS, "hale_select <target> - Select a player to be next boss");
    //RegAdminCmd("sm_hale_special", Command_MakeNextSpecial, ADMFLAG_CHEATS, "Call a special to next round.");
    RegAdminCmd("sm_hale_addpoints", Command_Points, ADMFLAG_CHEATS, "hale_addpoints <target> <points> - Add queue points to user.");
    RegAdminCmd("sm_hale_point_enable", Command_Point_Enable, ADMFLAG_CHEATS, "Enable CP. Only with hale_point_type = 0");
    RegAdminCmd("sm_hale_point_disable", Command_Point_Disable, ADMFLAG_CHEATS, "Disable CP. Only with hale_point_type = 0");
    RegAdminCmd("sm_hale_stop_music", Command_StopMusic, ADMFLAG_CHEATS, "Stop any currently playing Boss music.");
    AutoExecConfig(true, "SaxtonHale");
    PointCookie = RegClientCookie("hale_queuepoints1", "Amount of VSH Queue points player has", CookieAccess_Protected);
    MusicCookie = RegClientCookie("hale_music_setting", "HaleMusic setting", CookieAccess_Public);
    VoiceCookie = RegClientCookie("hale_voice_setting", "HaleVoice setting", CookieAccess_Public);
    ClasshelpinfoCookie = RegClientCookie("hale_classinfo", "HaleClassinfo setting", CookieAccess_Public);
    jumpHUD = CreateHudSynchronizer();
    rageHUD = CreateHudSynchronizer();
    healthHUD = CreateHudSynchronizer();
    infoHUD = CreateHudSynchronizer();

    LoadTranslations("saxtonhale.phrases");
#if defined EASTER_BUNNY_ON
    LoadTranslations("saxtonhale_bunny.phrases");
#endif
    LoadTranslations("common.phrases");
    for (new client = 1; client <= MaxClients; client++)
    {
        VSHFlags[client] = 0;
        Damage[client] = 0;
        AirDamage[client] = 0;
        uberTarget[client] = -1;
        if (IsClientInGame(client)) // IsValidClient(client, false)
        {
            SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
            SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);

#if defined _tf2attributes_included
            if (g_bTF2AttributesIsRunning && IsPlayerAlive(client))
            {
                TF2Attrib_RemoveByName(client, "damage force reduction");
            }
#endif
        }
    }

    AddNormalSoundHook(HookSound);

    AddMultiTargetFilter("@hale", HaleTargetFilter, "the current Boss", false);
    AddMultiTargetFilter("@!hale", HaleTargetFilter, "all non-Boss players", false);
}
public bool:HaleTargetFilter(const String:pattern[], Handle:clients)
{
    new bool:non = StrContains(pattern, "!", false) != -1;
    for (new client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && FindValueInArray(clients, client) == -1)
        {
            if (g_bEnabled && client == Hale)
            {
                if (!non)
                {
                    PushArrayCell(clients, client);
                }
            }
            else if (non)
            {
                PushArrayCell(clients, client);
            }
        }
    }

    return true;
}

public OnConfigsExecuted()
{
    decl String:oldversion[64];
    GetConVarString(cvarVersion, oldversion, sizeof(oldversion));
    if (strcmp(oldversion, haleversiontitles[maxversion], false) != 0) LogError("[VS Saxton Hale] Warning: your config may be outdated. Back up your tf/cfg/sourcemod/SaxtonHale.cfg file and delete it, and this plugin will generate a new one that you can then modify to your original values.");
    SetConVarString(FindConVar("hale_version"), haleversiontitles[maxversion]);
    HaleSpeed = GetConVarFloat(cvarHaleSpeed);
    RageDMG = GetConVarInt(cvarRageDMG);
    RageDist = GetConVarFloat(cvarRageDist);
    Announce = GetConVarFloat(cvarAnnounce);
    bSpecials = GetConVarBool(cvarSpecials);
    PointType = GetConVarInt(cvarPointType);
    PointDelay = GetConVarInt(cvarPointDelay);
    if (PointDelay < 0) PointDelay *= -1;
    AliveToEnable = GetConVarInt(cvarAliveToEnable);
    haleCrits = GetConVarBool(cvarCrits);
    bDemoShieldCrits = GetConVarBool(cvarDemoShieldCrits);
    bAlwaysShowHealth = GetConVarBool(cvarDisplayHaleHP);
    newRageSentry = GetConVarBool(cvarRageSentry);
    //circuitStun = GetConVarFloat(cvarCircuitStun);
    if (IsSaxtonHaleMap() && GetConVarBool(cvarEnabled))
    {
        tf_arena_use_queue = GetConVarInt(FindConVar("tf_arena_use_queue"));
        mp_teams_unbalance_limit = GetConVarInt(FindConVar("mp_teams_unbalance_limit"));
        tf_arena_first_blood = GetConVarInt(FindConVar("tf_arena_first_blood"));
        mp_forcecamera = GetConVarInt(FindConVar("mp_forcecamera"));
        tf_scout_hype_pep_max = GetConVarFloat(FindConVar("tf_scout_hype_pep_max"));
        tf_dropped_weapon_lifetime = GetConVarInt(FindConVar("tf_dropped_weapon_lifetime"));
        tf_feign_death_activate_damage_scale = GetConVarFloat(FindConVar("tf_feign_death_activate_damage_scale"));
        tf_feign_death_damage_scale = GetConVarFloat(FindConVar("tf_feign_death_damage_scale"));
        tf_stealth_damage_reduction = GetConVarFloat(FindConVar("tf_stealth_damage_reduction"));
        tf_feign_death_duration = GetConVarFloat(FindConVar("tf_feign_death_duration"));
        tf_feign_death_speed_duration = GetConVarFloat(FindConVar("tf_feign_death_speed_duration"));
        
        SetConVarInt(FindConVar("tf_arena_use_queue"), 0);
        SetConVarInt(FindConVar("mp_teams_unbalance_limit"), TF2_GetRoundWinCount() ? 0 : 1); // s_bLateLoad ? 0 : 
        //SetConVarInt(FindConVar("mp_teams_unbalance_limit"), GetConVarBool(cvarFirstRound)?0:1);
        SetConVarInt(FindConVar("tf_arena_first_blood"), 0);
        SetConVarInt(FindConVar("mp_forcecamera"), 0);
        SetConVarFloat(FindConVar("tf_scout_hype_pep_max"), 100.0);
        SetConVarInt(FindConVar("tf_damage_disablespread"), 1);
        SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), 0);

        SetConVarFloat(FindConVar("tf_feign_death_activate_damage_scale"), 0.1);
        SetConVarFloat(FindConVar("tf_feign_death_damage_scale"), 0.1);
        SetConVarFloat(FindConVar("tf_stealth_damage_reduction"), 0.1);
        SetConVarFloat(FindConVar("tf_feign_death_duration"), 7.0);
        SetConVarFloat(FindConVar("tf_feign_death_speed_duration"), 0.0);

#if defined _steamtools_included
        if (g_bSteamToolsIsRunning)
        {
            decl String:gameDesc[64];
            Format(gameDesc, sizeof(gameDesc), "VS Saxton Hale (%s)", haleversiontitles[maxversion]);
            Steam_SetGameDescription(gameDesc);
        }
#endif

        g_bEnabled = true;
        g_bAreEnoughPlayersPlaying = true;
        if (Announce > 1.0)
        {
            CreateTimer(Announce, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else
    {
        g_bAreEnoughPlayersPlaying = false;
        g_bEnabled = false;
    }
}
public OnMapStart()
{
    //HPTime = 0.0;
    //KSpreeTimer = 0.0;
    TeamRoundCounter = 0;
    MusicTimer = INVALID_HANDLE;
    doorchecktimer = INVALID_HANDLE;
    Hale = -1;
    for (new i = 1; i <= MaxClients; i++)
    {
        VSHFlags[i] = 0;
    }
    if (IsSaxtonHaleMap(true))
    {
        AddToDownload();
        IsDate(.bForceRecalc = true);
        MapHasMusic(true);
        CheckToChangeMapDoors();
        CheckToTeleportToSpawn();
    }
    RoundCount = 0;
}
public OnMapEnd()
{
    if (g_bAreEnoughPlayersPlaying || g_bEnabled)
    {
        SetConVarInt(FindConVar("tf_arena_use_queue"), tf_arena_use_queue);
        SetConVarInt(FindConVar("mp_teams_unbalance_limit"), mp_teams_unbalance_limit);
        SetConVarInt(FindConVar("tf_arena_first_blood"), tf_arena_first_blood);
        SetConVarInt(FindConVar("mp_forcecamera"), mp_forcecamera);
        SetConVarFloat(FindConVar("tf_scout_hype_pep_max"), tf_scout_hype_pep_max);
        SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), tf_dropped_weapon_lifetime);

        SetConVarFloat(FindConVar("tf_feign_death_activate_damage_scale"), tf_feign_death_activate_damage_scale);
        SetConVarFloat(FindConVar("tf_feign_death_damage_scale"), tf_feign_death_damage_scale);
        SetConVarFloat(FindConVar("tf_stealth_damage_reduction"), tf_stealth_damage_reduction);
        SetConVarFloat(FindConVar("tf_feign_death_duration"), tf_feign_death_duration);
        SetConVarFloat(FindConVar("tf_feign_death_speed_duration"), tf_feign_death_speed_duration);
#if defined _steamtools_included
        if (g_bSteamToolsIsRunning)
        {
            Steam_SetGameDescription("Team Fortress");
        }
#endif
    }

    ClearTimer(MusicTimer);
}
public OnPluginEnd()
{
    OnMapEnd();

    if (!g_bReloadVSHOnRoundEnd && VSHRoundState == VSHRState_Active)
    {
        ServerCommand("mp_restartround 5");
        CPrintToChatAll("{olive}[VSH]{default} The plugin has been unexpectedly unloaded!");
    }
}

AddToDownload()
{
    /*
        Files to precache that are originally part of TF2 or HL2 / etc and don't need to be downloaded
    */

    PrecacheSound("vo/announcer_am_capincite01.mp3", true);
    PrecacheSound("vo/announcer_am_capincite03.mp3", true);
    PrecacheSound("vo/announcer_am_capenabled02.mp3", true);

    //PrecacheSound("weapons/barret_arm_zap.wav", true);
    PrecacheSound("player/doubledonk.wav", true);
#if defined EASTER_BUNNY_ON
    PrecacheSound("items/pumpkin_pickup.wav", true); // Only necessary for servers that don't have halloween holiday mode enabled.
#endif

    PrecacheParticleSystem("ghost_appearation");
    PrecacheParticleSystem("yikes_fx");

    /*
        Files to download + precache that are not originally part of TF2 or HL2 / etc
    */
    
    PrepareSound("saxton_hale/9000.wav");

    /*
        All boss related files
    */

    // Saxton Hale

    // Precache
    // None.. he's all custom

    // Download

    PrepareModel(HaleModel);

    PrepareMaterial("materials/models/player/saxton_hale/eye"); // Some of these materials are used by Christian Brutal Sniper
    PrepareMaterial("materials/models/player/saxton_hale/hale_head");
    PrepareMaterial("materials/models/player/saxton_hale/hale_body");
    PrepareMaterial("materials/models/player/saxton_hale/hale_misc");
    PrepareMaterial("materials/models/player/saxton_hale/sniper_red");
    PrepareMaterial("materials/models/player/saxton_hale/sniper_lens");

    //Saxton Hale Materials
    AddFileToDownloadsTable("materials/models/player/saxton_hale/sniper_head.vtf"); // So we're keeping ALL of them.
    AddFileToDownloadsTable("materials/models/player/saxton_hale/sniper_head_red.vmt");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/hale_misc_normal.vtf");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/hale_body_normal.vtf");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/eyeball_l.vmt");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/eyeball_r.vmt");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/hale_egg.vtf");
    AddFileToDownloadsTable("materials/models/player/saxton_hale/hale_egg.vmt");

    DownloadMaterialList(HaleMatsV2, sizeof(HaleMatsV2)); // New material files for Saxton Hale's new model.

    PrepareSound(HaleComicArmsFallSound);
    PrepareSound(HaleKSpree);

    decl i, String:s[PLATFORM_MAX_PATH];
    for (i = 1; i <= 4; i++)
    {
        Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HaleLastB, i);
        PrecacheSound(s, true);
        /*Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHLaught, i);
        PrecacheSound(s, true);
        Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHAttack, i);
        PrecacheSound(s, true);*/
    }

    PrepareSound(HaleKillMedic);
    PrepareSound(HaleKillSniper1);
    PrepareSound(HaleKillSniper2);
    PrepareSound(HaleKillSpy1);
    PrepareSound(HaleKillSpy2);
    PrepareSound(HaleKillEngie1);
    PrepareSound(HaleKillEngie2);
    PrepareSound(HaleKillDemo132);

    PrepareSound(HaleKillHeavy132);
    PrepareSound(HaleKillScout132);
    PrepareSound(HaleKillSpy132);
    PrepareSound(HaleKillPyro132);
    PrepareSound(HaleSappinMahSentry132);
    PrepareSound(HaleKillLast132);
    PrepareSound(HaleKillDemo132);
    PrepareSound(HaleKillDemo132);
    PrepareSound(HaleKillDemo132);
    PrepareSound(HaleKillDemo132);
    PrepareSound(HaleKillDemo132);

    for (i = 1; i <= 5; i++)
    {
        if (i <= 2)
        {
            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleJump, i);
            PrepareSound(s);

            /*Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerJump, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerRageSound2, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerFail, i);
            PrepareSound(s);*/

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleWin, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleJump132, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKillEngie132, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKillKSpree132, i);
            PrepareSound(s);
        }

        if (i <= 3)
        {
            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleFail, i);
            PrepareSound(s);
        }

        if (i <= 4)
        {
            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleRageSound, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleStubbed132, i);
            PrepareSound(s);
        }

        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleRoundStart, i);
        PrepareSound(s);

        //Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerKSpreeNew, i);
        //PrepareSound(s);

        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKSpreeNew, i);
        PrepareSound(s);

        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleLastMan, i);
        PrepareSound(s);

        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleStart132, i);
        PrepareSound(s);
    }

    if (!bSpecials)
    {
        return;
    }

    // Christian Brutal Sniper

    // Precache

    PrecacheSound(CBS0, true);
    PrecacheSound(CBS1, true);
    PrecacheSound(CBS3, true);
    PrecacheSound(CBSJump1, true);

    for (i = 1; i <= 25; i++)
    {
        if (i <= 9)
        {
            Format(s, PLATFORM_MAX_PATH, "%s%02i.mp3", CBS2, i);
            PrecacheSound(s, true);
        }
        Format(s, PLATFORM_MAX_PATH, "%s%02i.mp3", CBS4, i);
        PrecacheSound(s, true);
    }

    PrecacheSound("vo/sniper_dominationspy04.mp3", true);

    // Download

    PrepareModel(CBSModel);

    PrepareSound(CBSTheme);


    // Horseless Headless Horsemann

    // Precache

    PrecacheSound(HHHRage, true);
    PrecacheSound(HHHRage2, true);

    for (i = 1; i <= 4; i++)
    {
        Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHLaught, i);
        PrecacheSound(s, true);
        Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHAttack, i);
        PrecacheSound(s, true);
    }

    PrecacheSound("ui/halloween_boss_summoned_fx.wav", true);
    PrecacheSound("ui/halloween_boss_defeated_fx.wav", true);

    PrecacheSound("vo/halloween_boss/knight_pain01.mp3", true);
    PrecacheSound("vo/halloween_boss/knight_pain02.mp3", true);
    PrecacheSound("vo/halloween_boss/knight_pain03.mp3", true);
    PrecacheSound("vo/halloween_boss/knight_death01.mp3", true);
    PrecacheSound("vo/halloween_boss/knight_death02.mp3", true);

    PrecacheSound("misc/halloween/spell_teleport.wav", true);

    PrecacheSound(HHHTheme, true);

    // Download

    PrepareModel(HHHModel);
    

    // Vagineer

    // Precache

    PrecacheSound("vo/engineer_no01.mp3", true);
    PrecacheSound("vo/engineer_jeers02.mp3", true);

    // Download

    PrepareModel(VagineerModel);

    PrepareSound(VagineerLastA);
    PrepareSound(VagineerStart);
    PrepareSound(VagineerRageSound);
    PrepareSound(VagineerKSpree);
    PrepareSound(VagineerKSpree2);
    PrepareSound(VagineerHit);

    for (i = 1; i <= 5; i++)
    {
        if (i <= 2)
        {
            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerJump, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerRageSound2, i);
            PrepareSound(s);

            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerFail, i);
            PrepareSound(s);
        }

        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerKSpreeNew, i);
        PrepareSound(s);
    }

    PrepareSound(VagineerRoundStart);

#if defined EASTER_BUNNY_ON
    // Easter Bunny

    // Precache

    PrecacheSoundList(BunnyWin, sizeof(BunnyWin));
    PrecacheSoundList(BunnyJump, sizeof(BunnyJump));
    PrecacheSoundList(BunnyRage, sizeof(BunnyRage));
    PrecacheSoundList(BunnyFail, sizeof(BunnyFail));
    PrecacheSoundList(BunnyKill, sizeof(BunnyKill));
    PrecacheSoundList(BunnySpree, sizeof(BunnySpree));
    PrecacheSoundList(BunnyLast, sizeof(BunnyLast));
    PrecacheSoundList(BunnyPain, sizeof(BunnyPain));
    PrecacheSoundList(BunnyStart, sizeof(BunnyStart));
    PrecacheSoundList(BunnyRandomVoice, sizeof(BunnyRandomVoice));

    // Download

    PrepareModel(BunnyModel);
    PrepareModel(EggModel);
    // PrepareModel(ReloadEggModel);

    DownloadMaterialList(BunnyMaterials, sizeof(BunnyMaterials));

    PrepareMaterial("materials/models/props_easteregg/c_easteregg");
    AddFileToDownloadsTable("materials/models/props_easteregg/c_easteregg_gold.vmt");
#endif
}

public HideCvarNotify(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new Handle:svtags = FindConVar("sv_tags");
    new sflags = GetConVarFlags(svtags);
    sflags &= ~FCVAR_NOTIFY;
    SetConVarFlags(svtags, sflags);

    new flags = GetConVarFlags(convar);
    flags &= ~FCVAR_NOTIFY;
    SetConVarFlags(convar, flags);
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (convar == cvarHaleSpeed)
        HaleSpeed = GetConVarFloat(convar);
    else if (convar == cvarPointDelay)
    {
        PointDelay = GetConVarInt(convar);
        if (PointDelay < 0) PointDelay *= -1;
    }
    else if (convar == cvarRageDMG)
        RageDMG = GetConVarInt(convar);
    else if (convar == cvarRageDist)
        RageDist = GetConVarFloat(convar);
    else if (convar == cvarAnnounce)
        Announce = GetConVarFloat(convar);
    else if (convar == cvarSpecials)
        bSpecials = GetConVarBool(convar);
    else if (convar == cvarPointType)
        PointType = GetConVarInt(convar);
    else if (convar == cvarAliveToEnable)
        AliveToEnable = GetConVarInt(convar);
    else if (convar == cvarCrits)
        haleCrits = GetConVarBool(convar);
    else if (convar == cvarDemoShieldCrits)
        bDemoShieldCrits = GetConVarBool(cvarDemoShieldCrits);
    else if (convar == cvarDisplayHaleHP)
        bAlwaysShowHealth = GetConVarBool(cvarDisplayHaleHP);
    else if (convar == cvarRageSentry)
        newRageSentry = GetConVarBool(convar);
    //else if (convar == cvarCircuitStun)
    //  circuitStun = GetConVarFloat(convar);
    else if (convar == cvarEnabled)
    {
        if (GetConVarBool(convar) && IsSaxtonHaleMap())
        {
            g_bAreEnoughPlayersPlaying = true;
#if defined _steamtools_included
            if (g_bSteamToolsIsRunning)
            {
                decl String:gameDesc[64];
                Format(gameDesc, sizeof(gameDesc), "VS Saxton Hale (%s)", haleversiontitles[maxversion]);
                Steam_SetGameDescription(gameDesc);
            }
#endif
        }
    }
}

public Action:Timer_Announce(Handle:hTimer)
{
    static announcecount=-1;
    announcecount++;
    if (Announce > 1.0 && g_bAreEnoughPlayersPlaying)
    {
        switch (announcecount)
        {
            case 1:
            {
                CPrintToChatAll("{olive}[VSH]{default} VS Saxton Hale group: {olive}http://steamcommunity.com/groups/vssaxtonhale{default}");
            }
            case 3:
            {
                CPrintToChatAll("{default}VSH v%s by {olive}Rainbolt Dash{default}, {olive}FlaminSarge{default}, & {lightsteelblue}Chdata{default}.", haleversiontitles[maxversion]);
            }
            case 5:
            {
                announcecount = 0;
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_last_update", haleversiontitles[maxversion], haleversiondates[maxversion]);
            }
            default:
            {
//              if (ACH_Enabled)
//                  CPrintToChatAll("{olive}[VSH]{default} %t\n%t (experimental)", "vsh_open_menu", "vsh_open_ach");
//              else
                    CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_open_menu");
            }
        }
    }
    return Plugin_Continue;
}
/*public Action:OnGetGameDescription(String:gameDesc[64])
{
    if (g_bAreEnoughPlayersPlaying)
    {
        Format(gameDesc, sizeof(gameDesc), "VS Saxton Hale (%s)", haleversiontitles[maxversion]);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}*/
bool:IsSaxtonHaleMap(bool:forceRecalc = false)
{
    static bool:found = false;
    static bool:isVSHMap = false;
    if (forceRecalc)
    {
        isVSHMap = false;
        found = false;
    }
    if (!found)
    {
        decl String:s[PLATFORM_MAX_PATH];
        GetCurrentMap(currentmap, sizeof(currentmap));
        if (FileExists("bNextMapToHale"))
        {
            isVSHMap = true;
            found = true;
            return true;
        }
        BuildPath(Path_SM, s, PLATFORM_MAX_PATH, "configs/saxton_hale/saxton_hale_maps.cfg");
        if (!FileExists(s))
        {
            LogError("[VSH] Unable to find %s, disabling plugin.", s);
            isVSHMap = false;
            found = true;
            return false;
        }
        new Handle:fileh = OpenFile(s, "r");
        if (fileh == INVALID_HANDLE)
        {
            LogError("[VSH] Error reading maps from %s, disabling plugin.", s);
            isVSHMap = false;
            found = true;
            return false;
        }
        new pingas = 0;
        while (!IsEndOfFile(fileh) && ReadFileLine(fileh, s, sizeof(s)) && (pingas < 100))
        {
            pingas++;
            if (pingas == 100)
                LogError("[VS Saxton Hale] Breaking infinite loop when trying to check the map.");
            Format(s, strlen(s)-1, s);
            if (strncmp(s, "//", 2, false) == 0) continue;
            if ((StrContains(currentmap, s, false) != -1) || (StrContains(s, "all", false) == 0))
            {
                CloseHandle(fileh);
                isVSHMap = true;
                found = true;
                return true;
            }
        }
        CloseHandle(fileh);
    }
    return isVSHMap;
}
bool:MapHasMusic(bool:forceRecalc = false)
{
    static bool:hasMusic;
    static bool:found = false;
    if (forceRecalc)
    {
        found = false;
        hasMusic = false;
    }
    if (!found)
    {
        new i = -1;
        decl String:name[64];
        while ((i = FindEntityByClassname2(i, "info_target")) != -1)
        {
            GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
            if (strcmp(name, "hale_no_music", false) == 0) hasMusic = true;
        }
        found = true;
    }
    return hasMusic;
}
bool:CheckToChangeMapDoors()
{
    decl String:s[PLATFORM_MAX_PATH];
    GetCurrentMap(currentmap, sizeof(currentmap));
    checkdoors = false;
    BuildPath(Path_SM, s, PLATFORM_MAX_PATH, "configs/saxton_hale/saxton_hale_doors.cfg");
    if (!FileExists(s))
    {
        if (strncmp(currentmap, "vsh_lolcano_pb1", 15, false) == 0)
            checkdoors = true;
        return;
    }
    new Handle:fileh = OpenFile(s, "r");
    if (fileh == INVALID_HANDLE)
    {
        if (strncmp(currentmap, "vsh_lolcano_pb1", 15, false) == 0)
            checkdoors = true;
        return;
    }
    while (!IsEndOfFile(fileh) && ReadFileLine(fileh, s, sizeof(s)))
    {
        Format(s, strlen(s)-1, s);
        if (strncmp(s, "//", 2, false) == 0) continue;
        if (StrContains(currentmap, s, false) != -1 || StrContains(s, "all", false) == 0)
        {
            CloseHandle(fileh);
            checkdoors = true;
            return;
        }
    }
    CloseHandle(fileh);
}
CheckToTeleportToSpawn()
{
    decl String:s[PLATFORM_MAX_PATH];
    GetCurrentMap(currentmap, sizeof(currentmap));
    bSpawnTeleOnTriggerHurt = false;

    BuildPath(Path_SM, s, PLATFORM_MAX_PATH, "configs/saxton_hale/saxton_spawn_teleport.cfg");

    if (!FileExists(s))
    {
        return;
    }

    new Handle:fileh = OpenFile(s, "r");

    if (fileh == INVALID_HANDLE)
    {
        return;
    }

    while (!IsEndOfFile(fileh) && ReadFileLine(fileh, s, sizeof(s)))
    {
        Format(s, strlen(s) - 1, s);
        if (strncmp(s, "//", 2, false) == 0)
        {
            continue;
        }

        if (StrContains(currentmap, s, false) != -1 || StrContains(s, "all", false) == 0)
        {
            bSpawnTeleOnTriggerHurt = true;
            CloseHandle(fileh);
            return;
        }
    }

    CloseHandle(fileh);
}
bool:CheckNextSpecial()
{
    if (!bSpecials)
    {
        Special = VSHSpecial_Hale;
        return true;
    }
    if (Incoming != VSHSpecial_None)
    {
        Special = Incoming;
        Incoming = VSHSpecial_None;
        return true;
    }
    while (Incoming == VSHSpecial_None || (Special && Special == Incoming))
    {
        Incoming = GetRandomInt(0, 8);
        if (Special != VSHSpecial_Hale && !GetRandomInt(0, 5)) Incoming = VSHSpecial_Hale;
        else
        {
            switch (Incoming)
            {
                case 1: Incoming = VSHSpecial_Vagineer;
                case 2: Incoming = VSHSpecial_HHH;
                case 3: Incoming = VSHSpecial_CBS;
#if defined EASTER_BUNNY_ON
                case 4: Incoming = VSHSpecial_Bunny;
#endif
                default: Incoming = VSHSpecial_Hale;
            }
//            if (IsDate(Month_Oct, 15) && !GetRandomInt(0, 7)) Incoming = VSHSpecial_HHH; //IsHalloweenHoliday()
            if (IsDate(Month_Dec, 15) && !GetRandomInt(0, 7)) Incoming = VSHSpecial_CBS; //IsDecemberHoliday()
#if defined EASTER_BUNNY_ON
            if (IsDate(Month_Mar, 25, Month_Apr, 20) && !GetRandomInt(0, 7)) Incoming = VSHSpecial_Bunny; //IsEasterHoliday()
#endif
        }
    }
    Special = Incoming;
    Incoming = VSHSpecial_None;
    return true;        //OH GOD WHAT AM I DOING THIS ALWAYS RETURNS TRUE (still better than using QueuePanelH as a dummy)
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
    // TF2C 64-bit: teamplay_round_start_TeleportToMultiMapSpawn() causes native
    // segfault when iterating info_player_teamspawn entities. Disabled for now.
    // teamplay_round_start_TeleportToMultiMapSpawn();

    if (!GetConVarBool(cvarEnabled))
    {
#if defined _steamtools_included
        if (g_bAreEnoughPlayersPlaying && g_bSteamToolsIsRunning)
        {
            Steam_SetGameDescription("Team Fortress");
        }
#endif
        g_bAreEnoughPlayersPlaying = false;
    }
    g_bEnabled = g_bAreEnoughPlayersPlaying;
    if (CheckNextSpecial() && !g_bEnabled) //QueuePanelH(Handle:0, MenuAction:0, 9001, 0) is HaleEnabled
        return Plugin_Continue;
    if (FileExists("bNextMapToHale"))
        DeleteFile("bNextMapToHale");
    ClearTimer(MusicTimer);
    KSpreeCount = 0;
    CheckArena();
    GetCurrentMap(currentmap, sizeof(currentmap));
    new bool:bBluHale;
    new convarsetting = GetConVarInt(cvarForceHaleTeam);
    switch (convarsetting)
    {
        case 3: bBluHale = true;
        case 2: bBluHale = false;
        case 1: bBluHale = GetRandomInt(0, 1) == 1;
        default:
        {
            if (strncmp(currentmap, "vsh_", 4, false) == 0) bBluHale = true;
            else if (TeamRoundCounter >= 3 && GetRandomInt(0, 1))
            {
                bBluHale = (HaleTeam != 3);
                TeamRoundCounter = 0;
            }
            else bBluHale = (HaleTeam == 3);
        }
    }
    if (bBluHale)
    {
        new score1 = GetTeamScore(OtherTeam);
        new score2 = GetTeamScore(HaleTeam);
        SetTeamScore(2, score1);
        SetTeamScore(3, score2);
        OtherTeam = 2;
        HaleTeam = 3;
        bBluHale = false;
    }
    else
    {
        new score1 = GetTeamScore(HaleTeam);
        new score2 = GetTeamScore(OtherTeam);
        SetTeamScore(2, score1);
        SetTeamScore(3, score2);
        HaleTeam = 2;
        OtherTeam = 3;
        bBluHale = true;
    }
    playing = 0;
    for (new ionplay = 1; ionplay <= MaxClients; ionplay++)
    {
        Damage[ionplay] = 0;
        AirDamage[ionplay] = 0;
        uberTarget[ionplay] = -1;
        if (IsClientInGame(ionplay))
        {
#if defined _tf2attributes_included
            if (g_bTF2AttributesIsRunning && IsPlayerAlive(ionplay))
            {
                TF2Attrib_RemoveByName(ionplay, "damage force reduction");
            }
#endif

            StopHaleMusic(ionplay);
            if (IsClientParticipating(ionplay))
            {
                playing++;
            }
            //if (GetEntityTeamNum(ionplay) > _:TFTeam_Spectator) playing++;
        }
    }
    if (GetClientCount() <= 1 || playing < 2)
    {
        CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_needmoreplayers");
        g_bEnabled = false;
        VSHRoundState = VSHRState_Disabled;
        SetControlPoint(true);
        return Plugin_Continue;
    }
    else if (RoundCount >= 0 && GetConVarBool(cvarFirstRound)) // This line was breaking the first round sometimes
    {
        g_bEnabled = true;
    }
    else if (RoundCount <= 0 && !GetConVarBool(cvarFirstRound))
    {
        CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_first_round");

        g_bEnabled = false;
        VSHRoundState = VSHRState_Disabled;
        SetArenaCapEnableTime(60.0);

        SearchForItemPacks();
        SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 1);

        CreateTimer(71.0, Timer_EnableCap, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Continue;
    }

    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), TF2_GetRoundWinCount() ? 0 : 1); // s_bLateLoad ? 0 :

    if (FixUnbalancedTeams())
    {
        return Plugin_Continue;
    }
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)) continue;
        if (!IsPlayerAlive(i)) continue;
        if (!(VSHFlags[i] & VSHFLAG_HASONGIVED)) TF2_RespawnPlayer(i);
    }
    new bool:see[TF_MAX_PLAYERS];
    new tHale = FindNextHale(see);
    if (tHale == -1)
    {
        CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_needmoreplayers");
        g_bEnabled = false;
        VSHRoundState = VSHRState_Disabled;
        SetControlPoint(true);
        return Plugin_Continue;
    }
    if (NextHale > 0)
    {
        Hale = NextHale;
        NextHale = -1;
    }
    else
    {
        Hale = tHale;
    }
    SetNextTime(e_flNextAllowBossSuicide, 29.1);
    SetNextTime(e_flNextAllowOtherSpawnTele, 60.0);

    // bTenSecStart[0] = true;
    // bTenSecStart[1] = true;
    // CreateTimer(29.1, tTenSecStart, 0);
    // CreateTimer(60.0, tTenSecStart, 1);

    CreateTimer(9.1, StartHaleTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(3.5, StartResponceTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(9.6, MessageTimer, true, TIMER_FLAG_NO_MAPCHANGE);
    //bNoTaunt = false;
    HaleRage = 0;
    g_flStabbed = 0.0;
    g_flMarketed = 0.0;
    HHHClimbCount = 0;
    PointReady = false;
    new ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_regenerate")) != -1)
        AcceptEntityInput(ent, "Disable");
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_respawnroomvisualizer")) != -1)
        AcceptEntityInput(ent, "Disable");
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "obj_dispenser")) != -1)
    {
        SetVariantInt(OtherTeam);
        AcceptEntityInput(ent, "SetTeam");
        AcceptEntityInput(ent, "skin");
        SetEntProp(ent, Prop_Send, "m_nSkin", OtherTeam-2);
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "mapobj_cart_dispenser")) != -1)
    {
        SetVariantInt(OtherTeam);
        AcceptEntityInput(ent, "SetTeam");
        AcceptEntityInput(ent, "skin");
    }

    SearchForItemPacks();

    CreateTimer(0.3, MakeHale);

    healthcheckused = 0;
    VSHRoundState = VSHRState_Waiting;
    return Plugin_Continue;
}

bool:FixUnbalancedTeams()
{
    if (GetTeamClientCount(HaleTeam) <= 0 || GetTeamClientCount(OtherTeam) <= 0)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                ChangeTeam(i, i==Hale?HaleTeam:OtherTeam);
            }
        }
        return true;
    }
    return false;
}

SearchForItemPacks()
{
    new bool:foundAmmo = false, bool:foundHealth = false;
    new ent = -1;
    decl Float:pos[3];
    while ((ent = FindEntityByClassname2(ent, "item_ammopack_full")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);

        if (g_bEnabled)
        {
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
            AcceptEntityInput(ent, "Kill");
            new ent2 = CreateEntityByName("item_ammopack_small");
            TeleportEntity(ent2, pos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(ent2);
            SetEntProp(ent2, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
            foundAmmo = true;
        }
        
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "item_ammopack_medium")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);

        if (g_bEnabled)
        {
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
            AcceptEntityInput(ent, "Kill");
            new ent2 = CreateEntityByName("item_ammopack_small");
            TeleportEntity(ent2, pos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(ent2);
            SetEntProp(ent2, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
        }
        
        foundAmmo = true;
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "Item_ammopack_small")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
        foundAmmo = true;
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "item_healthkit_small")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
        foundHealth = true;
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "item_healthkit_medium")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
        foundHealth = true;
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "item_healthkit_full")) != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
        foundHealth = true;
    }
    if (!foundAmmo) SpawnRandomAmmo();
    if (!foundHealth) SpawnRandomHealth();
}

SpawnRandomAmmo()
{
    new iEnt = MaxClients + 1;
    decl Float:vPos[3];
    decl Float:vAng[3];
    while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
    {
        if (GetRandomInt(0, 4))
        {
            continue;
        }

        // Technically you'll never find a map without a spawn point.
        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
        GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);

        new iEnt2 = !GetRandomInt(0, 3) ? CreateEntityByName("item_ammopack_medium") : CreateEntityByName("item_ammopack_small");
        TeleportEntity(iEnt2, vPos, vAng, NULL_VECTOR);
        DispatchSpawn(iEnt2);
        SetEntProp(iEnt2, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
    }
}

SpawnRandomHealth()
{
    new iEnt = MaxClients + 1;
    decl Float:vPos[3];
    decl Float:vAng[3];
    while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
    {
        if (GetRandomInt(0, 4))
        {
            continue;
        }

        // Technically you'll never find a map without a spawn point.
        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
        GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);

        new iEnt2 = !GetRandomInt(0, 3) ? CreateEntityByName("item_healthkit_medium") : CreateEntityByName("item_healthkit_small");
        TeleportEntity(iEnt2, vPos, vAng, NULL_VECTOR);
        DispatchSpawn(iEnt2);
        SetEntProp(iEnt2, Prop_Send, "m_iTeamNum", g_bEnabled?OtherTeam:0, 4);
    }
}

public Action:Timer_EnableCap(Handle:timer)
{
    if (VSHRoundState == VSHRState_Disabled)
    {
        SetControlPoint(true);
        if (checkdoors)
        {
            new ent = -1;
            while ((ent = FindEntityByClassname2(ent, "func_door")) != -1)
            {
                AcceptEntityInput(ent, "Open");
                AcceptEntityInput(ent, "Unlock");
            }
            if (doorchecktimer == INVALID_HANDLE)
                doorchecktimer = CreateTimer(5.0, Timer_CheckDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
        }
    }
}

public Action:Timer_CheckDoors(Handle:hTimer)
{
    if (!checkdoors)
    {
        doorchecktimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    if ((!g_bEnabled && VSHRoundState != VSHRState_Disabled) || (g_bEnabled && VSHRoundState != VSHRState_Active)) return Plugin_Continue;
    new ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_door")) != -1)
    {
        AcceptEntityInput(ent, "Open");
        AcceptEntityInput(ent, "Unlock");
    }
    return Plugin_Continue;
}
public CheckArena()
{
    if (PointType)
    {
        SetArenaCapEnableTime(float(45 + PointDelay * (playing - 1)));
    }
    else
    {
        SetArenaCapEnableTime(0.0);
        SetControlPoint(false);
    }
}
public numHaleKills = 0;    //See if the Hale was boosting his buddies or afk
public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
    new String:s[265];
    decl String:s2[265];
    new bool:see = false;
    GetNextMap(s, 64);
    if (!strncmp(s, "Hale ", 5, false))
    {
        see = true;
        strcopy(s2, sizeof(s2), s[5]);
    }
    else if (!strncmp(s, "(Hale) ", 7, false))
    {
        see = true;
        strcopy(s2, sizeof(s2), s[7]);
    }
    else if (!strncmp(s, "(Hale)", 6, false))
    {
        see = true;
        strcopy(s2, sizeof(s2), s[6]);
    }
    if (see)
    {
        new Handle:fileh = OpenFile("bNextMapToHale", "w");
        WriteFileString(fileh, s2, false);
        CloseHandle(fileh);
        SetNextMap(s2);
        CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_nextmap", s2);
    }
    RoundCount++;

    if (g_bReloadVSHOnRoundEnd)
    {
        SetClientQueuePoints(Hale, 0);
        ServerCommand("sm plugins reload saxtonhale");
    }

    if (!g_bEnabled)
    {
        return Plugin_Continue;
    }
    VSHRoundState = VSHRState_End;
    TeamRoundCounter++;
    if (GetEventInt(event, "team") == HaleTeam)
    {
        switch (Special)
        {
            case VSHSpecial_Hale:
            {
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleWin, GetRandomInt(1, 2));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);
            }
            case VSHSpecial_Vagineer:
            {
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerKSpreeNew, GetRandomInt(1, 5));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);
            }
#if defined EASTER_BUNNY_ON
            case VSHSpecial_Bunny:
            {
                strcopy(s, PLATFORM_MAX_PATH, BunnyWin[GetRandomInt(0, sizeof(BunnyWin)-1)]);
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, _, NULL_VECTOR, false, 0.0);  
            }
#endif
        }
    }
    for (new i = 1 ; i <= MaxClients; i++)
    {
        VSHFlags[i] &= ~VSHFLAG_HASONGIVED;
        if (!IsClientInGame(i)) continue;
        StopHaleMusic(i);
    }
    ClearTimer(MusicTimer);
    if (IsClientInGame(Hale))
    {
        SetEntProp(Hale, Prop_Send, "m_bGlowEnabled", 0);
        GlowTimer = 0.0;
        if (IsPlayerAlive(Hale))
        {
            decl String:translation[32];
            switch (Special)
            {
                case VSHSpecial_Bunny:      strcopy(translation, sizeof(translation), "vsh_bunny_is_alive");
                case VSHSpecial_Vagineer:   strcopy(translation, sizeof(translation), "vsh_vagineer_is_alive");
                case VSHSpecial_HHH:        strcopy(translation, sizeof(translation), "vsh_hhh_is_alive");
                case VSHSpecial_CBS:        strcopy(translation, sizeof(translation), "vsh_cbs_is_alive");
                default:                    strcopy(translation, sizeof(translation), "vsh_hale_is_alive");
            }
            CPrintToChatAll("{olive}[VSH]{default} %t", translation, Hale, HaleHealth, HaleHealthMax);
            SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
            for (new i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && !(GetClientButtons(i) & IN_SCORE))
                {
                    ShowHudText(i, -1, "%T", translation, i, Hale, HaleHealth, HaleHealthMax);
                }
            }
        }
        else
        {
            ChangeTeam(Hale, HaleTeam);
        }
        new top[3];
        Damage[0] = 0;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (Damage[i] >= Damage[top[0]])
            {
                top[2]=top[1];
                top[1]=top[0];
                top[0]=i;
            }
            else if (Damage[i] >= Damage[top[1]])
            {
                top[2]=top[1];
                top[1]=i;
            }
            else if (Damage[i] >= Damage[top[2]])
            {
                top[2]=i;
            }
        }
        if (Damage[top[0]] > 9000)
        {
            CreateTimer(1.0, Timer_NineThousand, _, TIMER_FLAG_NO_MAPCHANGE);
        }
        decl String:s1[80];
        if (IsClientInGame(top[0]) && (GetEntityTeamNum(top[0]) >= 1))
            GetClientName(top[0], s, 80);
        else
        {
            Format(s, 80, "---");
            top[0]=0;
        }
        if (IsClientInGame(top[1]) && (GetEntityTeamNum(top[1]) >= 1))
            GetClientName(top[1], s1, 80);
        else
        {
            Format(s1, 80, "---");
            top[1]=0;
        }
        if (IsClientInGame(top[2]) && (GetEntityTeamNum(top[2]) >= 1))
            GetClientName(top[2], s2, 80);
        else
        {
            Format(s2, 80, "---");
            top[2]=0;
        }
        SetHudTextParams(-1.0, 0.3, 10.0, 255, 255, 255, 255);
        PriorityCenterTextAll(_, ""); //Should clear center text
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !(GetClientButtons(i) & IN_SCORE))
            {
                SetGlobalTransTarget(i);
//              if (numHaleKills < 2 && false) ShowHudText(i, -1, "%t\n1)%i - %s\n2)%i - %s\n3)%i - %s\n\n%t %i\n%t %i", "vsh_top_3", Damage[top[0]], s, Damage[top[1]], s1, Damage[top[2]], s2, "vsh_damage_fx", Damage[i], "vsh_scores", RoundFloat(Damage[i] / 600.0));
//              else
                ShowSyncHudText(i, infoHUD, "%t\n1)%i - %s\n2)%i - %s\n3)%i - %s\n\n%t %i\n%t %i", "vsh_top_3",
                    Damage[top[0]], s,
                    Damage[top[1]], s1,
                    Damage[top[2]], s2,
                    "vsh_damage_fx",Damage[i],
                    "vsh_scores", RoundFloat(Damage[i] / 600.0)
                );
            }
        }
    }
    CreateTimer(3.0, Timer_CalcScores, _, TIMER_FLAG_NO_MAPCHANGE);     //CalcScores();
    return Plugin_Continue;
}
public Action:Timer_NineThousand(Handle:timer)
{
    EmitSoundToAll("saxton_hale/9000.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, false, 0.0);
    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, "saxton_hale/9000.wav", _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, false, 0.0);
    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, "saxton_hale/9000.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, false, 0.0);
}
public Action:Timer_CalcScores(Handle:timer)
{
    CalcScores();
}
CalcScores()
{
    decl j, damage;
    //new bool:spec = GetConVarBool(cvarForceSpecToHale);
    botqueuepoints += 5;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            damage = Damage[i];
            new Handle:aevent = CreateEvent("player_escort_score", true);
            SetEventInt(aevent, "player", i);
            for (j = 0; damage - 600 > 0; damage -= 600, j++){}
            SetEventInt(aevent, "points", j);
            FireEvent(aevent);
            if (i == Hale)
            {
                if (IsFakeClient(Hale)) botqueuepoints = 0;
                else SetClientQueuePoints(i, 0);
            }
            else if (!IsFakeClient(i) && (GetEntityTeamNum(i) > _:TFTeam_Spectator))
            {
                CPrintToChat(i, "{olive}[VSH]{default} %t", "vsh_add_points", 10);
                SetClientQueuePoints(i, GetClientQueuePoints(i)+10);
            }
        }
    }
}

public Action:StartResponceTimer(Handle:hTimer)
{
    decl String:s[PLATFORM_MAX_PATH];
    decl Float:pos[3];
    switch (Special)
    {
#if defined EASTER_BUNNY_ON
        case VSHSpecial_Bunny:
        {
            strcopy(s, PLATFORM_MAX_PATH, BunnyStart[GetRandomInt(0, sizeof(BunnyStart)-1)]);
        }
#endif
        case VSHSpecial_Vagineer:
        {
            if (!GetRandomInt(0, 1))
                strcopy(s, PLATFORM_MAX_PATH, VagineerStart);
            else
                strcopy(s, PLATFORM_MAX_PATH, VagineerRoundStart);
        }
        case VSHSpecial_HHH: Format(s, PLATFORM_MAX_PATH, "ui/halloween_boss_summoned_fx.wav");
        case VSHSpecial_CBS: strcopy(s, PLATFORM_MAX_PATH, CBS0);
        default:
        {
            if (!GetRandomInt(0, 1))
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleRoundStart, GetRandomInt(1, 5));
            else
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleStart132, GetRandomInt(1, 5));
        }
    }
    EmitSoundToAll(s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, false, 0.0);
    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, false, 0.0);
    if (Special == VSHSpecial_CBS)
    {
        EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, pos, NULL_VECTOR, false, 0.0);
        EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, pos, NULL_VECTOR, false, 0.0);
    }
    return Plugin_Continue;
}
// public Action:tTenSecStart(Handle:hTimer, any:ofs)
// {
//     bTenSecStart[ofs] = false;
// }
public Action:StartHaleTimer(Handle:hTimer)
{
    CreateTimer(0.1, GottamTimer);
    if (!IsClientInGame(Hale))
    {
        VSHRoundState = VSHRState_End;
        return Plugin_Continue;
    }
    FixUnbalancedTeams();
    if (!IsPlayerAlive(Hale))
    {
        TF2_RespawnPlayer(Hale);
    }
    playing = 0; // nergal's FRoG fix
    for (new client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || client == Hale) continue;
        playing++;
        CreateTimer(0.2, MakeNoHale, GetClientUserId(client));
    }
    //if (playing < 5)
    //  playing += 2;
    // Chdata's slightly reworked Hale HP calculation (in light of removing the above two lines)
    HaleHealthMax = RoundFloat(Pow(((760.8 + playing)*(playing - 1)), 1.0341));

    HaleHealthMax += 2048;

    if (HaleHealthMax <= 0) // Rare glitches can cause his health to become negative.
    {
        HaleHealthMax = 2048;
    }

    SetEntProp(Hale, Prop_Data, "m_iMaxHealth", HaleHealthMax);
    SetEntityHealth(Hale, HaleHealthMax);
    HaleHealth = HaleHealthMax;
    HaleHealthLast = HaleHealth;
    CreateTimer(0.2, CheckAlivePlayers);
    CreateTimer(0.2, HaleTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.2, StartRound);
    CreateTimer(0.2, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    if (!PointType && playing > GetConVarInt(cvarAliveToEnable))
    {
        SetControlPoint(false);
    }
    if (VSHRoundState == VSHRState_Waiting)
    {
        CreateTimer(2.0, Timer_MusicPlay, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}
public Action:Timer_MusicPlay(Handle:timer)
{
    if (VSHRoundState != VSHRState_Active) return Plugin_Stop;
    new String:sound[PLATFORM_MAX_PATH] = "";
    new Float:time = -1.0;
    ClearTimer(MusicTimer);
    if (MapHasMusic())
    {
        strcopy(sound, sizeof(sound), "");
        time = -1.0;
    }
    else
    {
        switch (Special)
        {
//          case VSHSpecial_Hale:
//          {
//              strcopy(sound, sizeof(sound), HaleTempTheme);
//              time = 162.0;
//          }
            case VSHSpecial_CBS:
            {
                strcopy(sound, sizeof(sound), CBSTheme);
                time = 137.0;
            }
            case VSHSpecial_HHH:
            {
                strcopy(sound, sizeof(sound), HHHTheme);
                time = 87.0;
            }
        }
    }
    new Action:act = Plugin_Continue;
    Call_StartForward(OnMusic);
    decl String:sound2[PLATFORM_MAX_PATH];
    new Float:time2 = time;
    strcopy(sound2, PLATFORM_MAX_PATH, sound);
    Call_PushStringEx(sound2, PLATFORM_MAX_PATH, 0, SM_PARAM_COPYBACK);
    Call_PushFloatRef(time2);
    Call_Finish(act);
    switch (act)
    {
        case Plugin_Stop, Plugin_Handled:
        {
            strcopy(sound, sizeof(sound), "");
            time = -1.0;
        }
        case Plugin_Changed:
        {
            strcopy(sound, PLATFORM_MAX_PATH, sound2);
            time = time2;
        }
    }
    if (sound[0] != '\0')
    {
//      Format(sound, sizeof(sound), "#%s", sound);
        EmitSoundToAllExcept(SOUNDEXCEPT_MUSIC, sound, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
    }
    if (time != -1.0)
    {
        new Handle:pack;
        MusicTimer = CreateDataTimer(time, Timer_MusicTheme, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
        WritePackString(pack, sound);
        WritePackFloat(pack, time);
    }
    return Plugin_Continue;
}
public Action:Timer_MusicTheme(Handle:timer, any:pack)
{
    decl String:sound[PLATFORM_MAX_PATH];
    ResetPack(pack);
    ReadPackString(pack, sound, sizeof(sound));
    new Float:time = ReadPackFloat(pack);
    if (g_bEnabled && VSHRoundState == VSHRState_Active)
    {
/*      new String:sound[PLATFORM_MAX_PATH] = "";
        switch (Special)
        {
            case VSHSpecial_CBS:
                strcopy(sound, sizeof(sound), CBSTheme);
            case VSHSpecial_HHH:
                strcopy(sound, sizeof(sound), HHHTheme);
        }*/
        new Action:act = Plugin_Continue;
        Call_StartForward(OnMusic);
        decl String:sound2[PLATFORM_MAX_PATH];
        new Float:time2 = time;
        strcopy(sound2, PLATFORM_MAX_PATH, sound);
        Call_PushStringEx(sound2, PLATFORM_MAX_PATH, 0, SM_PARAM_COPYBACK);
        Call_PushFloatRef(time2);
        Call_Finish(act);
        switch (act)
        {
            case Plugin_Stop, Plugin_Handled:
            {
                strcopy(sound, sizeof(sound), "");
                time = -1.0;
                MusicTimer = INVALID_HANDLE;
                return Plugin_Stop;
            }
            case Plugin_Changed:
            {
                strcopy(sound, PLATFORM_MAX_PATH, sound2);
                if (time2 != time)
                {
                    time = time2;
                    ClearTimer(MusicTimer);
                    if (time != -1.0)
                    {
                        new Handle:datapack;
                        MusicTimer = CreateDataTimer(time, Timer_MusicTheme, datapack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
                        WritePackString(datapack, sound);
                        WritePackFloat(datapack, time);
                    }
                }
            }
        }
        if (sound[0] != '\0')
        {
//          Format(sound, sizeof(sound), "#%s", sound);
            EmitSoundToAllExcept(SOUNDEXCEPT_MUSIC, sound, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
        }
    }
    else
    {
        MusicTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}
EmitSoundToAllExcept(exceptiontype = SOUNDEXCEPT_MUSIC, const String:sample[],
                 entity = SOUND_FROM_PLAYER,
                 channel = SNDCHAN_AUTO,
                 level = SNDLEVEL_NORMAL,
                 flags = SND_NOFLAGS,
                 Float:volume = SNDVOL_NORMAL,
                 pitch = SNDPITCH_NORMAL,
                 speakerentity = -1,
                 const Float:origin[3] = NULL_VECTOR,
                 const Float:dir[3] = NULL_VECTOR,
                 bool:updatePos = true,
                 Float:soundtime = 0.0)
{
    new clients[MaxClients];
    new total = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckSoundException(i, exceptiontype))
        {
            clients[total++] = i;
        }
    }
    if (!total)
    {
        return;
    }
    EmitSound(clients, total, sample, entity, channel,
        level, flags, volume, pitch, speakerentity,
        origin, dir, updatePos, soundtime);
}
bool:CheckSoundException(client, excepttype)
{
    if (!IsValidClient(client)) return false;
    if (IsFakeClient(client)) return true;
    if (!AreClientCookiesCached(client)) return true;
    decl String:strCookie[32];
    if (excepttype == SOUNDEXCEPT_VOICE) GetClientCookie(client, VoiceCookie, strCookie, sizeof(strCookie));
    else GetClientCookie(client, MusicCookie, strCookie, sizeof(strCookie));
    if (strCookie[0] == 0) return true;
    else return bool:StringToInt(strCookie);
}

SetClientSoundOptions(client, excepttype, bool:on)
{
    if (!IsValidClient(client)) return;
    if (IsFakeClient(client)) return;
    if (!AreClientCookiesCached(client)) return;
    new String:strCookie[32];
    if (on) strCookie = "1";
    else strCookie = "0";
    if (excepttype == SOUNDEXCEPT_VOICE) SetClientCookie(client, VoiceCookie, strCookie);
    else SetClientCookie(client, MusicCookie, strCookie);
}
public Action:GottamTimer(Handle:hTimer)
{
    for (new i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && IsPlayerAlive(i))
            SetEntityMoveType(i, MOVETYPE_WALK);
}
public Action:StartRound(Handle:hTimer)
{
    VSHRoundState = VSHRState_Active;
    if (IsValidClient(Hale))
    {
        if (!IsPlayerAlive(Hale) && TFTeam:GetEntityTeamNum(Hale) != TFTeam_Spectator && TFTeam:GetEntityTeamNum(Hale) != TFTeam_Unassigned)
        {
            TF2_RespawnPlayer(Hale);
        }
        ChangeTeam(Hale, HaleTeam);
        if (GetEntityTeamNum(Hale) == HaleTeam)
        {
            new bool:pri = IsValidEntity(GetPlayerWeaponSlot(Hale, TFWeaponSlot_Primary));
            new bool:sec = IsValidEntity(GetPlayerWeaponSlot(Hale, TFWeaponSlot_Secondary));
            new bool:mel = IsValidEntity(GetPlayerWeaponSlot(Hale, TFWeaponSlot_Melee));
            TF2_RemovePlayerDisguise(Hale);

            if (pri || sec || !mel)
                CreateTimer(0.05, Timer_ReEquipSaxton, _, TIMER_FLAG_NO_MAPCHANGE);
            //EquipSaxton(Hale);
        }
    }
    CreateTimer(10.0, Timer_SkipHalePanel);
    return Plugin_Continue;
}
public Action:Timer_ReEquipSaxton(Handle:timer)
{
    if (IsValidClient(Hale))
    {
        EquipSaxton(Hale);
    }
}
public Action:Timer_SkipHalePanel(Handle:hTimer)
{
    new bool:added[TF_MAX_PLAYERS];
    new i, j;
    new client = Hale;
    do
    {
        client = FindNextHale(added);
        if (client >= 0) added[client] = true;
        if (IsValidClient(client) && client != Hale)
        {
            if (!IsFakeClient(client))
            {
                CPrintToChat(client, "{olive}[VSH]{default} %t", "vsh_to0_near");
                if (i == 0) SkipHalePanelNotify(client);
            }
            i++;
        }
        j++;
    }
    while (i < 3 && j < TF_MAX_PLAYERS);
}

SkipHalePanelNotify(client) // , bool:newchoice = true
{
    if (!g_bEnabled || !IsValidClient(client) || IsVoteInProgress())
    {
        return;
    }

    new Action:result = Plugin_Continue;
    Call_StartForward(OnHaleNext);
    Call_PushCell(client);
    Call_Finish(_:result);

    switch(result)
    {
        case Plugin_Stop, Plugin_Handled:
            return;
    }

    new Handle:panel = CreatePanel();
    decl String:s[256];

    SetPanelTitle(panel, "[VSH] You're Hale next!");
    Format(s, sizeof(s), "%t\nAlternatively, use !resetq.", "vsh_to0_near");
    CRemoveTags(s, sizeof(s));

    ReplaceString(s, sizeof(s), "{olive}", "");
    ReplaceString(s, sizeof(s), "{default}", "");

    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, SkipHalePanelH, 30);
    CloseHandle(panel);
    
    return;
}

public SkipHalePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    return;
}
public Action:EnableSG(Handle:hTimer, any:iid)
{
    new i = EntRefToEntIndex(iid);
    if (VSHRoundState == VSHRState_Active && IsValidEdict(i) && i > MaxClients)
    {
        decl String:s[64];
        GetEdictClassname(i, s, 64);
        if (StrEqual(s, "obj_sentrygun"))
        {
            SetEntProp(i, Prop_Send, "m_bDisabled", 0);

            // We destroy this manually now
            /*for (new ent = MaxClients + 1; ent < MAX_ENTITIES; ent++)
            {
                if (IsValidEdict(ent))
                {
                    decl String:s2[64];

                    GetEdictClassname(ent, s2, 64);

                    if (StrEqual(s2, "info_particle_system") && (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == i))
                    {
                        AcceptEntityInput(ent, "Kill");
                    }
                }
            }*/
        }
    }
    return Plugin_Continue;
}

// public Action:RemoveEnt(Handle:timer, any:entid)
// {
//     new ent = EntRefToEntIndex(entid);
//     if (ent > 0 && IsValidEntity(ent))
//         AcceptEntityInput(ent, "Kill");
//     return Plugin_Continue;
// }

public Action:MessageTimer(Handle:hTimer, any:allclients)
{
    if (!IsValidClient(Hale)) // || ((client != 9001) && !IsValidClient(client))
        return Plugin_Continue;
    if (checkdoors)
    {
        new ent = -1;
        while ((ent = FindEntityByClassname2(ent, "func_door")) != -1)
        {
            AcceptEntityInput(ent, "Open");
            AcceptEntityInput(ent, "Unlock");
        }
        if (doorchecktimer == INVALID_HANDLE)
            doorchecktimer = CreateTimer(5.0, Timer_CheckDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    }
    decl String:translation[32];
    switch (Special)
    {
        case VSHSpecial_Bunny: strcopy(translation, sizeof(translation), "vsh_start_bunny");
        case VSHSpecial_Vagineer: strcopy(translation, sizeof(translation), "vsh_start_vagineer");
        case VSHSpecial_HHH: strcopy(translation, sizeof(translation), "vsh_start_hhh");
        case VSHSpecial_CBS: strcopy(translation, sizeof(translation), "vsh_start_cbs");
        default: strcopy(translation, sizeof(translation), "vsh_start_hale");
    }
    SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
    //if (client != 9001 && !(GetClientButtons(client) & IN_SCORE)) //bad
    if (!allclients)    // FlaminSarge: Not a clue what this is for
    {                   // Chdata: "{1} became Saxton Hale with {2} HP!" .. I guess
        ShowSyncHudText(Hale, infoHUD, "%T", translation, Hale, Hale, HaleHealthMax);
        // ShowHudText(client, -1, "%T", translation, client, Hale, HaleHealthMax);
    }
    else
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i)) //&& !(GetClientButtons(i) & IN_SCORE)        //try without the scoreboard button check
                ShowSyncHudText(i, infoHUD, "%T", translation, i, Hale, HaleHealthMax);
        }
    }
    return Plugin_Continue;
}

public Action:MakeModelTimer(Handle:hTimer)
{
    if (!IsValidClient(Hale) || !IsPlayerAlive(Hale) || VSHRoundState == VSHRState_End)
    {
        return Plugin_Stop;
    }
    new body = 0;
    switch (Special)
    {
#if defined EASTER_BUNNY_ON
        case VSHSpecial_Bunny:
        {
            SetVariantString(BunnyModel);
        }
#endif
        case VSHSpecial_Vagineer:
        {
            SetVariantString(VagineerModel);
//          SetEntProp(Hale, Prop_Send, "m_nSkin", GetEntityTeamNum(Hale)-2);
        }
        case VSHSpecial_HHH:
            SetVariantString(HHHModel);
        case VSHSpecial_CBS:
            SetVariantString(CBSModel);
        default:
        {
            SetVariantString(HaleModel);
//          decl String:steamid[32];
//          GetClientAuthString(Hale, steamid, sizeof(steamid));
            if (GetUserFlagBits(Hale) & ADMFLAG_CUSTOM1) body = (1 << 0)|(1 << 1);
        }
    }
//  DispatchKeyValue(Hale, "targetname", "hale");
    AcceptEntityInput(Hale, "SetCustomModel");
    SetEntProp(Hale, Prop_Send, "m_bUseClassAnimations", 1);
    SetEntProp(Hale, Prop_Send, "m_nBody", body);
    return Plugin_Continue;
}
EquipSaxton(client)
{
    bEnableSuperDuperJump = false;
    new SaxtonWeapon;
    TF2_RemoveAllWeapons(client);
    HaleCharge = 0;
    switch (Special)
    {
        case VSHSpecial_Bunny:
        {
            SaxtonWeapon = SpawnWeapon(client, "tf_weapon_bottle", 1, 100, TFQual_Unusual, "68 ; 2.0 ; 2 ; 3.0 ; 259 ; 1.0 ; 326 ; 1.3 ; 252 ; 0.6");
        }
        case VSHSpecial_Vagineer:
        {
            SaxtonWeapon = SpawnWeapon(client, "tf_weapon_wrench", 7, 100, TFQual_Unusual, "68 ; 2.0 ; 2 ; 3.1 ; 259 ; 1.0 ; 436 ; 1.0");
        }
        case VSHSpecial_HHH:
        {
            SaxtonWeapon = SpawnWeapon(client, "tf_weapon_sword", 266, 100, TFQual_Unusual, "68 ; 2.0 ; 2 ; 3.1 ; 259 ; 1.0 ; 252 ; 0.6 ; 551 ; 1");
            SetEntPropFloat(SaxtonWeapon, Prop_Send, "m_flModelScale", 0.0001);
            HaleCharge = -1000;
        }
        case VSHSpecial_CBS:
        {
            SaxtonWeapon = SpawnWeapon(client, "tf_weapon_club", 171, 100, TFQual_Unusual, "68 ; 2.0 ; 2 ; 3.1 ; 259 ; 1.0");
            //SetEntProp(client, Prop_Send, "m_nBody", 0);
        }
        default:
        {
            decl String:attribs[64];
            Format(attribs, sizeof(attribs), "68 ; 2.0 ; 2 ; 3.1 ; 259 ; 1.0 ; 252 ; 0.6 ; 551 ; %i ; 214 ; %d", !IsDate(Month_Oct, 15), GetRandomInt(9999, 99999));
            SaxtonWeapon = SpawnWeapon(client, "tf_weapon_shovel", 5, 100, TFQual_Strange, attribs);
        }
    }

    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SaxtonWeapon);
}
public Action:MakeHale(Handle:hTimer)
{
    if (!IsValidClient(Hale))
    {
        return Plugin_Continue;
    }

    switch (Special)
    {
        case VSHSpecial_Hale:
            TF2_SetPlayerClass(Hale, TFClass_Soldier, _, false);
        case VSHSpecial_Vagineer:
            TF2_SetPlayerClass(Hale, TFClass_Engineer, _, false);
        case VSHSpecial_HHH, VSHSpecial_Bunny:
            TF2_SetPlayerClass(Hale, TFClass_DemoMan, _, false);
        case VSHSpecial_CBS:
            TF2_SetPlayerClass(Hale, TFClass_Sniper, _, false);
    }
    TF2_RemovePlayerDisguise(Hale);

    ChangeTeam(Hale, HaleTeam);

    if (VSHRoundState < VSHRState_Waiting)
        return Plugin_Continue;
    if (!IsPlayerAlive(Hale))
    {
        if (VSHRoundState == VSHRState_Waiting) TF2_RespawnPlayer(Hale);
        else return Plugin_Continue;
    }
    new iFlags = GetCommandFlags("r_screenoverlay");
    SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
    ClientCommand(Hale, "r_screenoverlay \"\"");
    SetCommandFlags("r_screenoverlay", iFlags);
    CreateTimer(0.2, MakeModelTimer, _);
    CreateTimer(20.0, MakeModelTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    new ent = -1;
    while ((ent = FindEntityByClassname2(ent, "tf_wearable")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == Hale)
        {
            new index = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
            switch (index)
            {
                case 438, 463, 167, 477, 493, 233, 234, 241, 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 536, 542, 577, 599, 673, 729, 791, 839, 1015, 5607: {}
                default:    TF2_RemoveWearable(Hale, ent); //AcceptEntityInput(ent, "kill");
            }
        }
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "tf_powerup_bottle")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == Hale)
        {
            new index = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
            switch (index)
            {
                case 438, 463, 167, 477, 493, 233, 234, 241, 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 536, 542, 577, 599, 673, 729, 791, 839, 1015, 5607: {}
                default:    TF2_RemoveWearable(Hale, ent); //AcceptEntityInput(ent, "kill");
            }
        }
    }
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "tf_wearable_demoshield")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == Hale)
        {
            TF2_RemoveWearable(Hale, ent);
            //AcceptEntityInput(ent, "kill");
        }
    }
    EquipSaxton(Hale);

    if (VSHRoundState >= VSHRState_Waiting && GetClientClasshelpinfoCookie(Hale))
    {
        HintPanel(Hale);
    }

    return Plugin_Continue;
}
#if defined _tf2items_included
public Action:TF2Items_OnGiveNamedItem(client, String:classname[], iItemDefinitionIndex, &Handle:hItem)
{
//    if (!g_bEnabled) return Plugin_Continue; // This messes up the first round sometimes


    //if (RoundCount <= 0 && !GetConVarBool(cvarFirstRound)) return Plugin_Continue;
/*
    7:52 AM - C:/hdata: may as well just comment this out and give the custom items during the first round too
    7:52 AM - C:/hdata: here's why it happens
    7:52 AM - C:/hdata: tf2_ongivenamed item sometimes only fires once between multiple rounds
    7:52 AM - C:/hdata: so if it doesn't fire on the first round
    7:52 AM - C:/hdata: then the custom stats never appear the second round (which becomes a hale round)
    7:53 AM - C:/hdata: it's what I did when I had the arena round
    7:53 AM - C:/hdata: just gave people the slightly modded weapons
    7:53 AM - C:/hdata: it didn't make much difference since it was only one round

     - It only refires if the player changes their class or loadout. No change in equipped items = no call of this native
*/

//  if (client == Hale) return Plugin_Continue;
//  if (hItem != INVALID_HANDLE) return Plugin_Continue;

    new Handle:hItemOverride = INVALID_HANDLE;
    new TFClassType:iClass = TF2_GetPlayerClass(client);

    switch (iItemDefinitionIndex)
    {
        case 39, 351, 1081: // Mega Detonator
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "551 ; 1 ; 25 ; 0.5 ; 207 ; 1.33 ; 144 ; 1 ; 58 ; 3.2", true);
        }
        case 740: // Mega Scorch shot
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "551 ; 1 ; 25 ; 0.5 ; 207 ; 1.33 ; 416 ; 3 ; 58 ; 2.08 ; 1 ; 0.65", true);
        }
        case 40, 1146: // Backburner
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "165 ; 1");
        }
        case 648: // Wrap assassin
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "279 ; 2.0");
        }
        case 224: // Letranger
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "166 ; 15 ; 1 ; 0.8", true);
        }
        case 225, 574: // YER
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "155 ; 1 ; 160 ; 1", true);
        }
        case 232, 401: // Bushwacka + Shahanshah
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "236 ; 1");
        }
        case 356: // Kunai
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "125 ; -60");
        }
        case 405, 608: // Demo boots have falling stomp damage
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "259 ; 1 ; 252 ; 0.25");
        }
        case 220: // Shortstop - Effects are no longer 'only while active'. Otherwise acts like post-gunmettle shortstop.
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "525 ; 1 ; 526 ; 1.2 ; 533 ; 1.4 ; 534 ; 1.4 ; 328 ; 1 ; 241 ; 1.5", true);
        }
        case 226: // The Battalion's Backup
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "252 ; 0.25"); //125 ; -10
        }
        case 305, 1079: // Medic Xbow
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "17 ; 0.15 ; 2 ; 1.45"); // ; 266 ; 1.0");
        }
        case 56, 1005, 1092: // Huntsman
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "2 ; 1.5 ; 76 ; 2.0");
        }
        case 38, 457, 154: // Axtinguisher
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "", true);
        }
        case 43, 239, 1100, 1084: // GRU
        {
            hItemOverride = PrepareItemHandle(hItem, _, _, "107 ; 1.5 ; 1 ; 0.5 ; 128 ; 1 ; 191 ; -7", true);
        }
        case 415: // Reserve Shooter
        {
            if (iClass == TFClass_Soldier) // Soldier shotguns get 40% rocket jump
            {
                hItemOverride = PrepareItemHandle(hItem, _, _, "135 ; 0.6 ; 179 ; 1 ; 265 ; 99999.0 ; 178 ; 0.6 ; 3 ; 0.67 ; 551 ; 1 ; 5 ; 1.15", true);
            }
            else
            {
                hItemOverride = PrepareItemHandle(hItem, _, _,             "179 ; 1 ; 265 ; 99999.0 ; 178 ; 0.6 ; 3 ; 0.67 ; 551 ; 1 ; 5 ; 1.15", true); //  ; 2 ; 1.1
            }
        
        }
    }

    if (hItemOverride != INVALID_HANDLE) // This has to be here, else stuff below can overwrite what's above
    {
        hItem = hItemOverride;

        return Plugin_Changed;
    }

    switch (iClass)
    {
        case TFClass_Sniper:
        {
            if (StrEqual(classname, "tf_weapon_club", false) || StrEqual(classname, "saxxy", false))
            {
                switch (iItemDefinitionIndex)
                {
                    case 401: // Shahanshah
                    {
                        hItemOverride = PrepareItemHandle(hItem, _, _, "236 ; 1 ; 224 ; 1.66 ; 225 ; 0.5");
                    }
                    default:
                    {
                        hItemOverride = PrepareItemHandle(hItem, _, _, "236 ; 1"); // Block healing while in use.
                    }
                }
            }
        }
        case TFClass_Soldier: // TODO if (TF2_GetPlayerClass(client) == TFClass_Soldier && (strncmp(classname, "tf_weapon_rocketlauncher", 24, false) == 0 || strncmp(classname, "tf_weapon_particle_cannon", 25, false) == 0 || strncmp(classname, "tf_weapon_shotgun", 17, false) == 0 || strncmp(classname, "tf_weapon_raygun", 16, false) == 0))
        {
            if (StrStarts(classname, "tf_weapon_shotgun", false) || GunmettleToIndex(iItemDefinitionIndex) == TFWeapon_Shotgun)
            {
                hItemOverride = PrepareItemHandle(hItem, _, _, "135 ; 0.6 ; 265 ; 99999.0"); // Soldier shotguns get 40% rocket jump dmg reduction     ; 265 ; 99999.0
            }
            else if (StrStarts(classname, "tf_weapon_rocketlauncher", false)  || GunmettleToIndex(iItemDefinitionIndex) == TFWeapon_RocketLauncher)
            {
                if (iItemDefinitionIndex == 127) // Direct hit
                {
                    hItemOverride = PrepareItemHandle(hItem, _, _, "265 ; 99999.0 ; 179 ; 1"); //  ; 215 ; 300.0
                }
                else
                {
                    hItemOverride = PrepareItemHandle(hItem, _, _, "265 ; 99999.0", (iItemDefinitionIndex == 237)); // Rocket jumper
                }
            }
        }
#if defined OVERRIDE_MEDIGUNS_ON
        case TFClass_Medic:
        {
            //Medic mediguns
            if (StrStarts(classname, "tf_weapon_medigun", false) || GunmettleToIndex(iItemDefinitionIndex) == TFWeapon_Medigun)
            {
                hItemOverride = PrepareItemHandle(hItem, _, _, "10 ; 1.25 ; 178 ; 0.75 ; 18 ; 0", true);
            }
        }
#endif
    }

    if (hItemOverride != INVALID_HANDLE)
    {
        hItem = hItemOverride;

        return Plugin_Changed;
    }

    return Plugin_Continue;
}
Handle:PrepareItemHandle(Handle:hItem, String:name[] = "", index = -1, const String:att[] = "", bool:dontpreserve = false)
{
    static Handle:hWeapon;
    new addattribs = 0;

    new String:weaponAttribsArray[32][32];
    new attribCount = ExplodeString(att, " ; ", weaponAttribsArray, 32, 32);

    new flags = OVERRIDE_ATTRIBUTES;
    if (!dontpreserve) flags |= PRESERVE_ATTRIBUTES;
    if (hWeapon == INVALID_HANDLE) hWeapon = TF2Items_CreateItem(flags);
    else TF2Items_SetFlags(hWeapon, flags);
//  new Handle:hWeapon = TF2Items_CreateItem(flags);    //INVALID_HANDLE;
    if (hItem != INVALID_HANDLE)
    {
        addattribs = TF2Items_GetNumAttributes(hItem);
        if (addattribs > 0)
        {
            for (new i = 0; i < 2 * addattribs; i += 2)
            {
                new bool:dontAdd = false;
                new attribIndex = TF2Items_GetAttributeId(hItem, i);
                for (new j = 0; j < attribCount+i; j += 2)
                {
                    if (StringToInt(weaponAttribsArray[j]) == attribIndex)
                    {
                        dontAdd = true;
                        break;
                    }
                }
                if (!dontAdd)
                {
                    IntToString(attribIndex, weaponAttribsArray[i+attribCount], 32);
                    FloatToString(TF2Items_GetAttributeValue(hItem, i), weaponAttribsArray[i+1+attribCount], 32);
                }
            }
            attribCount += 2 * addattribs;
        }
        CloseHandle(hItem); //probably returns false but whatever
    }

    if (name[0] != '\0')
    {
        flags |= OVERRIDE_CLASSNAME;
        TF2Items_SetClassname(hWeapon, name);
    }
    if (index != -1)
    {
        flags |= OVERRIDE_ITEM_DEF;
        TF2Items_SetItemIndex(hWeapon, index);
    }
    if (attribCount > 1)
    {
        TF2Items_SetNumAttributes(hWeapon, (attribCount/2));
        new i2 = 0;
        for (new i = 0; i < attribCount && i < 32; i += 2)
        {
            TF2Items_SetAttribute(hWeapon, i2, StringToInt(weaponAttribsArray[i]), StringToFloat(weaponAttribsArray[i+1]));
            i2++;
        }
    }
    else
    {
        TF2Items_SetNumAttributes(hWeapon, 0);
    }
    TF2Items_SetFlags(hWeapon, flags);
    return hWeapon;
}
#endif // _tf2items_included
public Action:MakeNoHale(Handle:hTimer, any:clientid)
{
    new client = GetClientOfUserId(clientid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || VSHRoundState == VSHRState_End || client == Hale)
        return Plugin_Continue;
//  SetVariantString("");
//  AcceptEntityInput(client, "SetCustomModel");

    ChangeTeam(client, OtherTeam);
    //TF2_RegeneratePlayer(client);   // Added fix by Chdata to correct team colors Edit: I guess it's not necessary

//  SetEntityRenderColor(client, 255, 255, 255, 255);
    if (!VSHRoundState && GetClientClasshelpinfoCookie(client) && !(VSHFlags[client] & VSHFLAG_CLASSHELPED))
        HelpPanel2(client);

#if defined _tf2attributes_included
    if (g_bTF2AttributesIsRunning)
    {
        if (IsValidEntity(FindPlayerBack(client, { 444 }, 1)))    //  Fixes mantreads to have jump height again
        {
            TF2Attrib_SetByDefIndex(client, 58, 1.8);             //  "self dmg push force increased"
        }
        else
        {
            TF2Attrib_RemoveByDefIndex(client, 58);
        }
    }
#endif

    new weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    new index = -1;
    if (weapon > MaxClients && IsValidEdict(weapon))
    {
        index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        switch (index)
        {
            case 41:    // ReplacelistPrimary
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                SpawnWeapon(client, "tf_weapon_minigun", 15, 1, 0, "");
                SetAmmo(client, 0, 200);
            }
            case 402:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                SpawnWeapon(client, "tf_weapon_sniperrifle", 14, 1, 0, "");
            }
            case 772, 448: // Block BFB and Soda Popper
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                SpawnWeapon(client, "tf_weapon_scattergun", 13, 1, 0, "");
            }
            case 237:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                SpawnWeapon(client, "tf_weapon_rocketlauncher", 18, 1, 0, "265 ; 99999.0");
                SetAmmo(client, 0, 20);
            }
            case 17, 204, 36, 412:
            {
                if (GetEntProp(weapon, Prop_Send, "m_iEntityQuality") != 10)
                {
                    TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                    SpawnWeapon(client, "tf_weapon_syringegun_medic", 17, 1, 10, "17 ; 0.05 ; 144 ; 1");
                }
            }
        }
    }
    weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon > MaxClients && IsValidEdict(weapon))
    {
        index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        switch (index)
        {
//          case 226:
//          {
//              TF2_RemoveWeaponSlot(client, 1);
//              weapon = SpawnWeapon(client, "tf_weapon_shotgun_soldier", 10, 1, 0, "");
//          }
            case 528:   // ReplacelistSecondary
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
                SpawnWeapon(client, "tf_weapon_laser_pointer", 140, 1, 0, "");
            }
            case 46, 1145:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
                SpawnWeapon(client, "tf_weapon_lunchbox_drink", 163, 1, 0, "144 ; 2");
            }
            case 57:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
                SpawnWeapon(client, "tf_weapon_smg", 16, 1, 0, "");
            }
            case 265:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
                SpawnWeapon(client, "tf_weapon_pipebomblauncher", 20, 1, 0, "");
                SetAmmo(client, 1, 24);
            }
//          case 39, 351:
//          {
//              if (GetEntProp(weapon, Prop_Send, "m_iEntityQuality") != 10)
//              {
//                  TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
//                  weapon = SpawnWeapon(client, "tf_weapon_flaregun", 39, 5, 10, "25 ; 0.5 ; 207 ; 1.33 ; 144 ; 1.0 ; 58 ; 3.2")
//              }
//          }
        }
    }
    if (IsValidEntity(FindPlayerBack(client, { 57 }, 1)))
    {
        RemovePlayerBack(client, { 57 }, 1);
        SpawnWeapon(client, "tf_weapon_smg", 16, 1, 0, "");
    }
    if (IsValidEntity(FindPlayerBack(client, { 642 }, 1)))
    {
        SpawnWeapon(client, "tf_weapon_smg", 16, 1, 6, "149 ; 1.5 ; 15 ; 0.0 ; 1 ; 0.85");
    }
    weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
    if (weapon > MaxClients && IsValidEdict(weapon))
    {
        index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        switch (index)
        {
            case 331:
            {
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
                SpawnWeapon(client, "tf_weapon_fists", 195, 1, 6, "");
            }
            case 357:
            {
                CreateTimer(1.0, Timer_NoHonorBound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
            }
            case 589:
            {
                if (!GetConVarBool(cvarEnableEurekaEffect))
                {
                    TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
                    SpawnWeapon(client, "tf_weapon_wrench", 7, 1, 0, "");
                }
            }
        }
    }
    weapon = GetPlayerWeaponSlot(client, 4);
    if (weapon > MaxClients && IsValidEdict(weapon) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 60)
    {
        TF2_RemoveWeaponSlot(client, 4);
        SpawnWeapon(client, "tf_weapon_invis", 30, 1, 0, "");
    }
    if (TF2_GetPlayerClass(client) == TFClass_Medic)
    {
        weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
#if defined OVERRIDE_MEDIGUNS_ON
        if (GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel") < 0.41)
            SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", 0.41);
#else
        new mediquality = (weapon > MaxClients && IsValidEdict(weapon) ? GetEntProp(weapon, Prop_Send, "m_iEntityQuality") : -1);
        if (mediquality != 10)
        {
            TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
            weapon = SpawnWeapon(client, "tf_weapon_medigun", 35, 5, 10, "18 ; 0.0 ; 10 ; 1.25 ; 178 ; 0.75");  //200 ; 1 for area of effect healing    // ; 178 ; 0.75 ; 128 ; 1.0 Faster switch-to
            if (GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 142)
            {
                SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
                SetEntityRenderColor(weapon, 255, 255, 255, 75); // What is the point of making gunslinger translucent? When will a medic ever even have a gunslinger equipped???  According to FlaminSarge: Randomizer Hale
            }
            SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", 0.41);
        }
#endif
    }
    return Plugin_Continue;
}
public Action:Timer_NoHonorBound(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsPlayerAlive(client))
    {
        new weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
        new index = ((IsValidEntity(weapon) && weapon > MaxClients) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
        new active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        new String:classname[64];
        if (IsValidEdict(active)) GetEdictClassname(active, classname, sizeof(classname));
        if (index == 357 && active == weapon && strcmp(classname, "tf_weapon_katana", false) == 0)
        {
            SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
            if (GetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy") < 1)
                SetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
        }
    }
}
public Action:event_destroy(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bEnabled)
    {
        new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
        new customkill = GetEventInt(event, "customkill");
        if (attacker == Hale) /* || (attacker == Companion)*/
        {
            if (Special == VSHSpecial_Hale)
            {
                if (customkill != TF_CUSTOM_BOOTS_STOMP) SetEventString(event, "weapon", "fists");
                if (!GetRandomInt(0, 4))
                {
                    decl String:s[PLATFORM_MAX_PATH];
                    strcopy(s, PLATFORM_MAX_PATH, HaleSappinMahSentry132);
                    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                }
            }
        }
    }
    return Plugin_Continue;
}
public Action:event_changeclass(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!g_bEnabled)
        return Plugin_Continue;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client == Hale)
    {
        switch(Special)
        {
            case VSHSpecial_Hale:
                if (TF2_GetPlayerClass(client) != TFClass_Soldier)
                    TF2_SetPlayerClass(client, TFClass_Soldier, _, false);
            case VSHSpecial_Vagineer:
                if (TF2_GetPlayerClass(client) != TFClass_Engineer)
                    TF2_SetPlayerClass(client, TFClass_Engineer, _, false);
            case VSHSpecial_HHH, VSHSpecial_Bunny:
                if (TF2_GetPlayerClass(client) != TFClass_DemoMan)
                    TF2_SetPlayerClass(client, TFClass_DemoMan, _, false);
            case VSHSpecial_CBS:
                if (TF2_GetPlayerClass(client) != TFClass_Sniper)
                    TF2_SetPlayerClass(client, TFClass_Sniper, _, false);
        }
        TF2_RemovePlayerDisguise(client);
    }
    return Plugin_Continue;
}
public Action:event_uberdeployed(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!g_bEnabled)
        return Plugin_Continue;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:s[64];
    if (client && IsClientInGame(client) && IsPlayerAlive(client))
    {
        new medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
        if (IsValidEntity(medigun))
        {
            GetEntityClassname(medigun, s, sizeof(s));
            if (strcmp(s, "tf_weapon_medigun", false) == 0)
            {
                TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.5, client);
                new target = GetHealingTarget(client);
                if (IsValidClient(target) && IsPlayerAlive(target)) // IsValidClient(target, false)
                {
                    TF2_AddCondition(target, TFCond_HalloweenCritCandy, 0.5, client);
                    uberTarget[client] = target;
                }
                else uberTarget[client] = -1;
                SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 1.51);
                CreateTimer(0.4, Timer_Lazor, EntIndexToEntRef(medigun), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
    return Plugin_Continue;
}
public Action:Timer_Lazor(Handle:hTimer, any:medigunid)
{
    new medigun = EntRefToEntIndex(medigunid);
    if (medigun && IsValidEntity(medigun) && VSHRoundState == VSHRState_Active)
    {
        new client = GetEntPropEnt(medigun, Prop_Send, "m_hOwnerEntity");
        new Float:charge = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
        if (IsValidClient(client)) // IsValidClient(client, false)
        {
            if (IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == medigun)
            {
                new target = GetHealingTarget(client);
                if (charge > 0.05)
                {
                    TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.5);
                    if (IsValidClient(target) && IsPlayerAlive(target)) // IsValidClient(target, false)
                    {
                        TF2_AddCondition(target, TFCond_HalloweenCritCandy, 0.5);
                        uberTarget[client] = target;
                    }
                    else uberTarget[client] = -1;
                }
            }
            
            if (charge <= 0.05)
            {
                CreateTimer(3.0, Timer_Lazor2, EntIndexToEntRef(medigun));
                VSHFlags[client] &= ~VSHFLAG_UBERREADY;
                return Plugin_Stop;
            }
        }
    }
    else
        return Plugin_Stop;
    return Plugin_Continue;
}
public Action:Timer_Lazor2(Handle:hTimer, any:medigunid)
{
    new medigun = EntRefToEntIndex(medigunid);
    if (IsValidEntity(medigun))
        SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")+0.31);
    return Plugin_Continue;
}
public Action:Command_GetHPCmd(client, args)
{
    if (!client) return Plugin_Handled;
    Command_GetHP(client);
    return Plugin_Handled;
}
public Action:Command_GetHP(client)
{
    if (!g_bEnabled || VSHRoundState != VSHRState_Active)
        return Plugin_Continue;
    if (client == Hale)
    {
        switch (Special)
        {
            case VSHSpecial_Bunny:
                PriorityCenterTextAll(_, "%t", "vsh_bunny_show_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_Vagineer:
                PriorityCenterTextAll(_, "%t", "vsh_vagineer_show_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_HHH:
                PriorityCenterTextAll(_, "%t", "vsh_hhh_show_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_CBS:
                PriorityCenterTextAll(_, "%t", "vsh_cbs_show_hp", HaleHealth, HaleHealthMax);
            default:
                PriorityCenterTextAll(_, "%t", "vsh_hale_show_hp", HaleHealth, HaleHealthMax);
        }
        HaleHealthLast = HaleHealth;
        return Plugin_Continue;
    }
    if (IsNextTime(e_flNextHealthQuery)) //  GetGameTime() >= HPTime
    {
        healthcheckused++;
        switch (Special)
        {
            case VSHSpecial_Bunny:
            {
                PriorityCenterTextAll(_, "%t", "vsh_bunny_hp", HaleHealth, HaleHealthMax);
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_bunny_hp", HaleHealth, HaleHealthMax);
            }
            case VSHSpecial_Vagineer:
            {
                PriorityCenterTextAll(_, "%t", "vsh_vagineer_hp", HaleHealth, HaleHealthMax);
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_vagineer_hp", HaleHealth, HaleHealthMax);
            }
            case VSHSpecial_HHH:
            {
                PriorityCenterTextAll(_, "%t", "vsh_hhh_hp", HaleHealth, HaleHealthMax);
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_hhh_hp", HaleHealth, HaleHealthMax);
            }
            case VSHSpecial_CBS:
            {
                PriorityCenterTextAll(_, "%t", "vsh_cbs_hp", HaleHealth, HaleHealthMax);
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_cbs_hp", HaleHealth, HaleHealthMax);
            }
            default:
            {
                PriorityCenterTextAll(_, "%t", "vsh_hale_hp", HaleHealth, HaleHealthMax);
                CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_hale_hp", HaleHealth, HaleHealthMax);
            }
        }
        HaleHealthLast = HaleHealth;
        SetNextTime(e_flNextHealthQuery, healthcheckused < 3 ? 20.0 : 80.0);
    }
    else if (RedAlivePlayers == 1)
        CPrintToChat(client, "{olive}[VSH]{default} %t", "vsh_already_see");
    else
        CPrintToChat(client, "{olive}[VSH]{default} %t", "vsh_wait_hp", GetSecsTilNextTime(e_flNextHealthQuery), HaleHealthLast);
    return Plugin_Continue;
}
public Action:Command_MakeNextSpecial(client, args)
{
    if (!CheckCommandAccess(client, "sm_hale_special", ADMFLAG_CHEATS, true))
    {
        ReplyToCommand(client, "[SM] You do not have access to this command.");
        return Plugin_Handled;
    }

    decl String:arg[32];
    decl String:name[64];
    if (!bSpecials)
    {
        CReplyToCommand(client, "{olive}[VSH]{default} This server isn't set up to use special bosses! Set the cvar hale_specials 1 in the VSH config to enable on next map!");
        return Plugin_Handled;
    }
    if (args < 1)
    {
        CReplyToCommand(client, "{olive}[VSH]{default} Usage: hale_special <hale, vagineer, hhh, christian>");
        return Plugin_Handled;
    }
    GetCmdArgString(arg, sizeof(arg));
    if (StrContains(arg, "hal", false) != -1)
    {
        Incoming = VSHSpecial_Hale;
        name = "Saxton Hale";
    }
    else if (StrContains(arg, "vag", false) != -1)
    {
        Incoming = VSHSpecial_Vagineer;
        name = "the Vagineer";
    }
    else if (StrContains(arg, "hhh", false) != -1)
    {
        Incoming = VSHSpecial_HHH;
        name = "the Horseless Headless Horsemann Jr.";
    }
    else if (StrContains(arg, "chr", false) != -1 || StrContains(arg, "cbs", false) != -1)
    {
        Incoming = VSHSpecial_CBS;
        name = "the Christian Brutal Sniper";
    }
#if defined EASTER_BUNNY_ON
    else if (StrContains(arg, "bun", false) != -1 || StrContains(arg, "eas", false) != -1)
    {
        Incoming = VSHSpecial_Bunny;
        name = "the Easter Bunny";
    }
#endif
    else
    {
        CReplyToCommand(client, "{olive}[VSH]{default} Usage: hale_special <hale, vagineer, hhh, christian>");
        return Plugin_Handled;
    }
    CReplyToCommand(client, "{olive}[VSH]{default} Set the next Special to %s", name);
    return Plugin_Handled;
}
public Action:Command_NextHale(client, args)
{
    if (g_bEnabled)
        CreateTimer(0.2, MessageTimer);
    return Plugin_Continue;
}
public Action:Command_HaleSelect(client, args)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;

    if (args < 1)
    {
        CReplyToCommand(client, "{olive}[VSH]{default} Usage: hale_select <target> [\"hidden\"]");
        return Plugin_Handled;
    }

    decl String:s2[12];
    decl String:targetname[32];

    GetCmdArg(1, targetname, sizeof(targetname));
    GetCmdArg(2, s2, sizeof(s2));

    new target = FindTarget(client, targetname);

    if (IsValidClient(target) && IsClientParticipating(target))
    {
        ForceHale(client, target, StrContains(s2, "hidden", false) >= 0);
    }
    else
    {
        CReplyToCommand(client, "{olive}[VSH]{default} Target is not valid for being selected as the boss.");
    }

    return Plugin_Handled;
}
public Action:Command_Points(client, args)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;
    if (args != 2)
    {
        CReplyToCommand(client, "{olive}[VSH]{default} Usage: hale_addpoints <target> <points>");
        return Plugin_Handled;
    }
    decl String:s2[MAX_DIGITS];
    decl String:targetname[PLATFORM_MAX_PATH];
    GetCmdArg(1, targetname, sizeof(targetname));
    GetCmdArg(2, s2, sizeof(s2));
    new points = StringToInt(s2);
    /**
     * target_name - stores the noun identifying the target(s)
     * target_list - array to store clients
     * target_count - variable to store number of clients
     * tn_is_ml - stores whether the noun must be translated
     */
    new String:target_name[MAX_TARGET_LENGTH];
    new target_list[TF_MAX_PLAYERS], target_count;
    new bool:tn_is_ml;
    if ((target_count = ProcessTargetString(
            targetname,
            client,
            target_list,
            TF_MAX_PLAYERS,
            0,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0)
    {
        /* This function replies to the admin with a failure message */
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    for (new i = 0; i < target_count; i++)
    {
        SetClientQueuePoints(target_list[i], GetClientQueuePoints(target_list[i])+points);
        LogAction(client, target_list[i], "\"%L\" added %d VSH queue points to \"%L\"", client, points, target_list[i]);
    }
    CReplyToCommand(client, "{olive}[VSH]{default} Added %d queue points to %s", points, target_name);
    return Plugin_Handled;
}
StopHaleMusic(client)
{
    if (!IsValidClient(client)) return;
//  StopSound(client, SNDCHAN_AUTO, HaleTempTheme);
    StopSound(client, SNDCHAN_AUTO, HHHTheme);
    StopSound(client, SNDCHAN_AUTO, CBSTheme);
}
public Action:Command_StopMusic(client, args)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)) continue;
        StopHaleMusic(i);
    }
    CReplyToCommand(client, "{olive}[VSH]{default} Stopped boss music.");
    return Plugin_Handled;
}
public Action:Command_Point_Disable(client, args)
{
    if (g_bEnabled) SetControlPoint(false);
    return Plugin_Handled;
}
public Action:Command_Point_Enable(client, args)
{
    if (g_bEnabled) SetControlPoint(true);
    return Plugin_Handled;
}

SetControlPoint(bool:enable)
{
    new CPm=-1; //CP = -1;
    while ((CPm = FindEntityByClassname2(CPm, "team_control_point")) != -1)
    {
        if (CPm > MaxClients && IsValidEdict(CPm))
        {
            AcceptEntityInput(CPm, (enable ? "ShowModel" : "HideModel"));
            SetVariantInt(enable ? 0 : 1);
            AcceptEntityInput(CPm, "SetLocked");
        }
    }
}

stock ForceHale(admin, client, bool:hidden, bool:forever = false)
{
    if (forever)
        Hale = client;
    else
        NextHale = client;
    if (!hidden)
    {
        CPrintToChatAllEx(client, "{olive}[VSH] {teamcolor}%N {default}%t", client, "vsh_hale_select_text");
    }
}
public OnClientPostAdminCheck(client)
{
    VSHFlags[client] = 0;
//  MusicDisabled[client] = false;
//  VoiceDisabled[client] = false;
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
    //bSkipNextHale[client] = false;
    Damage[client] = 0;
    AirDamage[client] = 0;
    uberTarget[client] = -1;
}
public OnClientDisconnect(client)
{
    Damage[client] = 0;
    AirDamage[client] = 0;
    uberTarget[client] = -1;
    VSHFlags[client] = 0;
    if (g_bEnabled)
    {
        if (client == Hale)
        {
            if (VSHRoundState >= VSHRState_Active)
            {
                decl String:authid[32];
                GetClientAuthId(client, AuthId_Steam2, authid, sizeof(authid));
                new Handle:pack;
                CreateDataTimer(3.0, Timer_SetDisconQueuePoints, pack, TIMER_FLAG_NO_MAPCHANGE);
                WritePackString(pack, authid);
                new bool:see[TF_MAX_PLAYERS];
                see[Hale] = true;
                new tHale = FindNextHale(see);
                if (NextHale > 0)
                {
                    tHale = NextHale;
                }
                if (IsValidClient(tHale))
                {
                    ChangeTeam(tHale, HaleTeam);
                }
            }
            if (VSHRoundState == VSHRState_Active)
            {
                ForceTeamWin(OtherTeam);
            }
            if (VSHRoundState == VSHRState_Waiting)
            {
                new bool:see[TF_MAX_PLAYERS];
                see[Hale] = true;
                new tHale = FindNextHale(see);
                if (NextHale > 0)
                {
                    tHale = NextHale;
                    NextHale = -1;
                }
                if (IsValidClient(tHale))
                {
                    Hale = tHale;
                    ChangeTeam(Hale, HaleTeam);
                    CreateTimer(0.1, MakeHale);
                    CPrintToChat(Hale, "{olive}[VSH]{default} Surprise! You're on NOW!");
                }
            }
            CPrintToChatAll("{olive}[VSH]{default} %t", "vsh_hale_disconnected");
        }
        else
        {
            if (IsClientInGame(client))
            {
                if (IsPlayerAlive(client)) CreateTimer(0.0, CheckAlivePlayers);
                if (client == FindNextHaleEx()) CreateTimer(1.0, Timer_SkipHalePanel, _, TIMER_FLAG_NO_MAPCHANGE);
            }
            if (client == NextHale)
            {
                NextHale = -1;
            }
        }
    }
}

public Action:Timer_SetDisconQueuePoints(Handle:timer, Handle:pack)
{
    ResetPack(pack);
    decl String:authid[32];
    ReadPackString(pack, authid, sizeof(authid));
    SetAuthIdQueuePoints(authid, 0);
}
public Action:Timer_RegenPlayer(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
    {
        TF2_RegeneratePlayer(client);
    }
}
public Action:event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client || !IsClientInGame(client)) return Plugin_Continue; // IsValidClient(client, false)   - You can probably assume the player is valid at this point though.. TODO
    if (!g_bEnabled) return Plugin_Continue;
    SetVariantString("");
    AcceptEntityInput(client, "SetCustomModel");
    if (client == Hale && VSHRoundState < VSHRState_End && VSHRoundState != VSHRState_Disabled)
    {
        CreateTimer(0.1, MakeHale);
    }

    if (VSHRoundState != VSHRState_Disabled)
    {
        CreateTimer(0.2, MakeNoHale, GetClientUserId(client));
        if (!(VSHFlags[client] & VSHFLAG_HASONGIVED))
        {
            VSHFlags[client] |= VSHFLAG_HASONGIVED;
            RemovePlayerBack(client, { 57, 133, 231, 405, 444, 608, 642 }, 7);
            RemoveDemoShield(client);
            TF2_RemoveAllWeapons(client);
            TF2_RegeneratePlayer(client);
            CreateTimer(0.1, Timer_RegenPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
    } 
    if (!(VSHFlags[client] & VSHFLAG_HELPED))
    {
        HelpPanel(client);
        VSHFlags[client] |= VSHFLAG_HELPED;
    }
    VSHFlags[client] &= ~VSHFLAG_UBERREADY;
    VSHFlags[client] &= ~VSHFLAG_CLASSHELPED;
    return Plugin_Continue;
}
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (g_bEnabled && client == Hale)
    {
        if (Special == VSHSpecial_HHH)
        {
            if (VSHFlags[client] & VSHFLAG_NEEDSTODUCK)
            {
                buttons |= IN_DUCK;
            }
            if (HaleCharge >= 47 && (buttons & IN_ATTACK))
            {
                buttons &= ~IN_ATTACK;
                return Plugin_Changed;
            }
        }
        if (Special == VSHSpecial_Bunny)
        {
            if (GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
            {
                buttons &= ~IN_ATTACK;
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}
public Action:ClientTimer(Handle:hTimer)
{
    if (VSHRoundState != VSHRState_Active)
    {
        return Plugin_Stop;
    }
    decl String:wepclassname[32];
    new i = -1;
    for (new client = 1; client <= MaxClients; client++)
    {
        if (client != Hale && IsClientInGame(client) && GetEntityTeamNum(client) == OtherTeam)
        {
            SetHudTextParams(-1.0, 0.88, 0.35, 90, 255, 90, 255, 0, 0.35, 0.0, 0.1);
            if (!IsPlayerAlive(client))
            {
                new obstarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
                if (obstarget != client && obstarget != Hale && IsValidClient(obstarget))
                {
                    if (!(GetClientButtons(client) & IN_SCORE)) ShowSyncHudText(client, rageHUD, "%t", "vsh_damage_others", Damage[client], obstarget, Damage[obstarget]);
                }
                else
                {
                    if (!(GetClientButtons(client) & IN_SCORE)) ShowSyncHudText(client, rageHUD, "%t: %d", "vsh_damage_own", Damage[client]);
                }
                continue;
            }
            if (!(GetClientButtons(client) & IN_SCORE)) ShowSyncHudText(client, rageHUD, "%t: %d", "vsh_damage_own", Damage[client]);
            new TFClassType:class = TF2_GetPlayerClass(client);
            new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            if (weapon <= MaxClients || !IsValidEntity(weapon) || !GetEntityClassname(weapon, wepclassname, sizeof(wepclassname))) strcopy(wepclassname, sizeof(wepclassname), "");
            new bool:validwep = (strncmp(wepclassname, "tf_wea", 6, false) == 0);
            new index = (validwep ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
            /*if (TF2_IsPlayerInCondition(client, TFCond_Cloaked))
            {
                if (GetClientCloakIndex(client) == 59)
                {
                    if (TF2_IsPlayerInCondition(client, TFCond_DeadRingered)) TF2_RemoveCondition(client, TFCond_DeadRingered);
                }
                else TF2_AddCondition(client, TFCond_DeadRingered, 0.3);
            }*/

            new bool:bHudAdjust = false;

            // Chdata's Deadringer Notifier
            if (TF2_GetPlayerClass(client) == TFClass_Spy)
            {
                if (GetClientCloakIndex(client) == 59)
                {
                    bHudAdjust = true;
                    new drstatus = TF2_IsPlayerInCondition(client, TFCond_Cloaked) ? 2 : GetEntProp(client, Prop_Send, "m_bFeignDeathReady") ? 1 : 0;

                    decl String:s[32];

                    switch (drstatus)
                    {
                        case 1:
                        {
                            SetHudTextParams(-1.0, 0.83, 0.35, 90, 255, 90, 255, 0, 0.0, 0.0, 0.0);
                            Format(s, sizeof(s), "Status: Feign Death Ready");
                        }
                        case 2:
                        {
                            SetHudTextParams(-1.0, 0.83, 0.35, 255, 64, 64, 255, 0, 0.0, 0.0, 0.0);
                            Format(s, sizeof(s), "Status: Deadringed");
                        }
                        default:
                        {
                            SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
                            Format(s, sizeof(s), "Status: Inactive");
                        }
                    }

                    if (!(GetClientButtons(client) & IN_SCORE))
                    {
                        ShowSyncHudText(client, jumpHUD, "%s", s);
                    }
                }
            }

            if (class == TFClass_Medic)
            {
                new medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

                decl String:mediclassname[64];

                if (IsValidEdict(medigun) && GetEdictClassname(medigun, mediclassname, sizeof(mediclassname)) && strcmp(mediclassname, "tf_weapon_medigun", false) == 0)
                {
                    bHudAdjust = true;
                    SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);

                    new charge = RoundToFloor(GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel") * 100);

                    if (!(GetClientButtons(client) & IN_SCORE))
                    {
                        ShowSyncHudText(client, jumpHUD, "%T: %i", "vsh_uber-charge", client, charge);
                    }

                    if (charge == 100 && !(VSHFlags[client] & VSHFLAG_UBERREADY))
                    {
                        FakeClientCommandEx(client, "voicemenu 1 7");
                        VSHFlags[client] |= VSHFLAG_UBERREADY;
                    }
                }

                if (weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary))
                {
                    new healtarget = GetHealingTarget(client);
                    if (IsValidClient(healtarget) && TF2_GetPlayerClass(healtarget) == TFClass_Scout)
                    {
                        TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.3);
                    }
                }
            }

            if (class == TFClass_Soldier)
            {
                if (GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary) == 1104)
                {
                    bHudAdjust = true;
                    SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);

                    if (!(GetClientButtons(client) & IN_SCORE))
                    {
                        ShowSyncHudText(client, jumpHUD, "Air Strike Damage: %i", AirDamage[client]);
                    }
                }
            }

            if (bAlwaysShowHealth)
            {
                SetHudTextParams(-1.0, bHudAdjust?0.78:0.83, 0.35, 255, 255, 255, 255);
                if (!(GetClientButtons(client) & IN_SCORE)) ShowSyncHudText(client, healthHUD, "%t", "vsh_health", HaleHealth, HaleHealthMax);
            }
            
//          else if (AirBlastReload[client]>0)
//          {
//              SetHudTextParams(-1.0, 0.83, 0.15, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
//              ShowHudText(client, -1, "%t", "vsh_airblast", RoundFloat(AirBlastReload[client])+1);
//              AirBlastReload[client]-=0.2;
//          }
            if (RedAlivePlayers == 1 && !TF2_IsPlayerInCondition(client, TFCond_Cloaked))
            {
                TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.3);
                new primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
                if (class == TFClass_Engineer && weapon == primary && StrEqual(wepclassname, "tf_weapon_sentry_revenge", false)) SetEntProp(client, Prop_Send, "m_iRevengeCrits", 3);
                TF2_AddCondition(client, TFCond_Buffed, 0.3);
                continue;
            }
            if (RedAlivePlayers == 2 && !TF2_IsPlayerInCondition(client, TFCond_Cloaked))
                TF2_AddCondition(client, TFCond_Buffed, 0.3);
            new TFCond:cond = TFCond_HalloweenCritCandy;
            if (TF2_IsPlayerInCondition(client, TFCond_CritCola) && (class == TFClass_Scout || class == TFClass_Heavy))
            {
                TF2_AddCondition(client, cond, 0.3);
                continue;
            }
            new bool:addmini = false;
            for (i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetHealingTarget(i) == client)
                {
                    addmini = true;
                    break;
                }
            }
            new bool:addthecrit = false;
            if (validwep && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))  //&& index != 4 && index != 194 && index != 225 && index != 356 && index != 461 && index != 574) addthecrit = true; //class != TFClass_Spy
            {
                //slightly longer check but makes sure that any weapon that can backstab will not crit (e.g. Saxxy)
                if (strcmp(wepclassname, "tf_weapon_knife", false) != 0 && index != 416)
                    addthecrit = true;
            }
            switch (index) //Specific (mini)critlist
            {
                /*case :
                {
                    addthecrit = true;
                }*/
                case 656: //Holiday Punch
                {
                    addthecrit = true;
                    cond = TFCond_Buffed;
                }
            }
            if (validwep && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary)) // Primary weapon crit list
            {
                if (strncmp(wepclassname, "tf_weapon_comp", 14, false) == 0 || // Sniper bows
                   strncmp(wepclassname, "tf_weapon_cros", 14, false) == 0 || // Medic crossbows
                   strncmp(wepclassname, "tf_weapon_shotgun_buil", 22, false) == 0 || // Engineer Rescue Ranger
                   strncmp(wepclassname, "tf_weapon_drg_pom", 17, false) == 0) // Engineer Pomson
                    addthecrit = true;
            }
            if (validwep && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)) // Secondary weapon crit list
            {
                if (strncmp(wepclassname, "tf_weapon_pis", 13, false) == 0 || // Engineer/Scout pistols
                   strncmp(wepclassname, "tf_weapon_han", 13, false) == 0 || // Scout pistols
                   strncmp(wepclassname, "tf_weapon_flar", 14, false) == 0 || // Flare guns
                   strncmp(wepclassname, "tf_weapon_smg", 13, false) == 0 || // Sniper SMGs
                   strncmp(wepclassname, "tf_weapon_jar", 13, false) == 0 || // Throwables (Jarate, Mad Milk)
                   strncmp(wepclassname, "tf_weapon_clea", 14, false) == 0) // Throwables (Flying Guillotine)
                {
                    if (class == TFClass_Scout && cond == TFCond_HalloweenCritCandy) cond = TFCond_Buffed;

                    new flindex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary);

                    if ((TF2_GetPlayerClass(client) == TFClass_Pyro && flindex == 594) || (IsValidEntity(FindPlayerBack(client, { 642 }, 1)))) // No crits if using Phlogistinator or Cozy Camper
                        addthecrit = false;
                    else
                        addthecrit = true;
                }
            }
            if (class == TFClass_DemoMan && !IsValidEntity(GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)))
            {
                addthecrit = true;

                if (!bDemoShieldCrits && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
                {
                    cond = TFCond_Buffed;
                }
            }

/*          if (Special != VSHSpecial_HHH && index != 56 && index != 1005 && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
            {
                new meleeindex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee);
                new melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
                if (melee <= MaxClients || !IsValidEntity(melee) || !GetEdictClassname(melee, wepclassname, sizeof(wepclassname))) strcopy(wepclassname, sizeof(wepclassname), "");
                new meleeindex = ((strncmp(wepclassname, "tf_wea", 6, false) == 0) ? GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex") : -1);
                if (meleeindex == 232) addthecrit = false;
            }
*/
            if (addthecrit)
            {
                TF2_AddCondition(client, cond, 0.3);
                if (addmini && cond != TFCond_Buffed) TF2_AddCondition(client, TFCond_Buffed, 0.3);
            }
            if (class == TFClass_Spy && validwep && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
            {
                if (!TF2_IsPlayerCritBuffed(client) && !TF2_IsPlayerInCondition(client, TFCond_Buffed) && !TF2_IsPlayerInCondition(client, TFCond_Cloaked) && !TF2_IsPlayerInCondition(client, TFCond_Disguised) && !GetEntProp(client, Prop_Send, "m_bFeignDeathReady"))
                {
                    TF2_AddCondition(client, TFCond_CritCola, 0.3);
                }
            }
            if (class == TFClass_Engineer && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && StrEqual(wepclassname, "tf_weapon_sentry_revenge", false))
            {
                new sentry = FindSentry(client);
                if (IsValidEntity(sentry) && GetEntPropEnt(sentry, Prop_Send, "m_hEnemy") == Hale)
                {
                    SetEntProp(client, Prop_Send, "m_iRevengeCrits", 3);
                    TF2_AddCondition(client, TFCond_Kritzkrieged, 0.3);
                }
                else
                {
                    if (GetEntProp(client, Prop_Send, "m_iRevengeCrits")) SetEntProp(client, Prop_Send, "m_iRevengeCrits", 0);
                    else if (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) && !TF2_IsPlayerInCondition(client, TFCond_Healing))
                    {
                        TF2_RemoveCondition(client, TFCond_Kritzkrieged);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

/*
Runs every frame for clients

*/
public OnPreThinkPost(client)
{
    if (IsNearSpencer(client) && TF2_IsPlayerInCondition(client, TFCond_Cloaked))
    {
        new Float:cloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") - 0.5;

        if (cloak < 0.0)
        {
            cloak = 0.0;
        }

        SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", cloak);

        /*if (RoundFloat(GetGameTime()) == GetGameTime())
        {
            CPrintToChdata("%N DISPENSE %f", client, GetGameTime());
        }*/
    }
}

public Action:HaleTimer(Handle:hTimer)
{
    if (VSHRoundState == VSHRState_End)
    {
        if (IsValidClient(Hale) && IsPlayerAlive(Hale)) TF2_AddCondition(Hale, TFCond_SpeedBuffAlly, 14.0); // IsValidClient(Hale, false)
        return Plugin_Stop;
    }
    if (!IsValidClient(Hale))
        return Plugin_Continue;
    if (TF2_IsPlayerInCondition(Hale, TFCond_Jarated))
        TF2_RemoveCondition(Hale, TFCond_Jarated);
    if (TF2_IsPlayerInCondition(Hale, TFCond_MarkedForDeath))
        TF2_RemoveCondition(Hale, TFCond_MarkedForDeath);
    if (TF2_IsPlayerInCondition(Hale, TFCond_Disguised))
        TF2_RemoveCondition(Hale, TFCond_Disguised);
    if (TF2_IsPlayerInCondition(Hale, TFCond:42) && TF2_IsPlayerInCondition(Hale, TFCond_Dazed))
        TF2_RemoveCondition(Hale, TFCond_Dazed);
    new Float:speed = HaleSpeed + 0.7 * (100 - HaleHealth * 100 / HaleHealthMax);
    SetEntPropFloat(Hale, Prop_Send, "m_flMaxspeed", speed);
    if (HaleHealth <= 0 && IsPlayerAlive(Hale)) HaleHealth = 1;
    SetEntityHealth(Hale, HaleHealth);
    SetHudTextParams(-1.0, 0.77, 0.35, 255, 255, 255, 255);
    SetGlobalTransTarget(Hale);
    if (!(GetClientButtons(Hale) & IN_SCORE)) ShowSyncHudText(Hale, healthHUD, "%t", "vsh_health", HaleHealth, HaleHealthMax);
    if (HaleRage/RageDMG >= 1)
    {
        if (IsFakeClient(Hale) && !(VSHFlags[Hale] & VSHFLAG_BOTRAGE))
        {
            CreateTimer(1.0, Timer_BotRage, _, TIMER_FLAG_NO_MAPCHANGE);
            VSHFlags[Hale] |= VSHFLAG_BOTRAGE;
        }
        else if (!(GetClientButtons(Hale) & IN_SCORE))
        {
            SetHudTextParams(-1.0, 0.83, 0.35, 255, 64, 64, 255);
            ShowSyncHudText(Hale, rageHUD, "%t", "vsh_do_rage");
        }
    }
    else if (!(GetClientButtons(Hale) & IN_SCORE))
    {
        SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255);
        ShowSyncHudText(Hale, rageHUD, "%t", "vsh_rage_meter", HaleRage*100/RageDMG);
    }
    SetHudTextParams(-1.0, 0.88, 0.35, 255, 255, 255, 255);
    if (GlowTimer <= 0.0)
    {
        SetEntProp(Hale, Prop_Send, "m_bGlowEnabled", 0);
        GlowTimer = 0.0;
    }
    else
        GlowTimer -= 0.2;
    if (bEnableSuperDuperJump)
    {
        /*if (HaleCharge <= 0)
        {
            HaleCharge = 0;
            if (!(GetClientButtons(Hale) & IN_SCORE)) ShowSyncHudText(Hale, jumpHUD, "%t", "vsh_super_duper_jump");
        }*/
        SetHudTextParams(-1.0, 0.88, 0.35, 255, 64, 64, 255);
    }

    new buttons = GetClientButtons(Hale);
    if (((buttons & IN_DUCK) || (buttons & IN_ATTACK2)) && (HaleCharge >= 0)) // && !(buttons & IN_JUMP)
    {
        if (Special == VSHSpecial_HHH)
        {
            if (HaleCharge + 5 < HALEHHH_TELEPORTCHARGE)
                HaleCharge += 5;
            else
                HaleCharge = HALEHHH_TELEPORTCHARGE;
            if (!(GetClientButtons(Hale) & IN_SCORE))
            {
                if (bEnableSuperDuperJump)
                {
                    ShowSyncHudText(Hale, jumpHUD, "%t", "vsh_super_duper_jump");
                }
                else
                {
                    ShowSyncHudText(Hale, jumpHUD, "%t", "vsh_teleport_status", HaleCharge * 2);
                }
            }
        }
        else
        {
            if (HaleCharge + 5 < HALE_JUMPCHARGE)
                HaleCharge += 5;
            else
                HaleCharge = HALE_JUMPCHARGE;
            if (!(GetClientButtons(Hale) & IN_SCORE))
            {
                if (bEnableSuperDuperJump)
                {
                    ShowSyncHudText(Hale, jumpHUD, "%t", "vsh_super_duper_jump");
                }
                else
                {
                    ShowSyncHudText(Hale, jumpHUD, "%t", "vsh_jump_status", HaleCharge * 4);
                }

            }
        }
    }
    else if (HaleCharge < 0)
    {
        HaleCharge += 5;
        if (Special == VSHSpecial_HHH)
        {
            if (!(GetClientButtons(Hale) & IN_SCORE)) ShowSyncHudText(Hale, jumpHUD, "%t %i", "vsh_teleport_status_2", -HaleCharge/20);
        }
        else if (!(GetClientButtons(Hale) & IN_SCORE)) ShowSyncHudText(Hale, jumpHUD, "%t %i", "vsh_jump_status_2", -HaleCharge/20);
    }
    else
    {
        decl Float:ang[3];
        GetClientEyeAngles(Hale, ang);
        if ((ang[0] < -45.0) && (HaleCharge > 1))
        {
            new Action:act = Plugin_Continue;
            new bool:super = bEnableSuperDuperJump;
            Call_StartForward(OnHaleJump);
            Call_PushCellRef(super);
            Call_Finish(act);
            if (act != Plugin_Continue && act != Plugin_Changed)
                return Plugin_Continue;
            if (act == Plugin_Changed) bEnableSuperDuperJump = super;
            decl Float:pos[3];
            if (Special == VSHSpecial_HHH && (HaleCharge == HALEHHH_TELEPORTCHARGE || bEnableSuperDuperJump))
            {
                new target = -1;

                do
                {
                    target = GetRandomInt(1, MaxClients);
                }
                while ((RedAlivePlayers > 0) && (!IsClientInGame(target) || (target == Hale) || !IsPlayerAlive(target) || GetEntityTeamNum(target) != OtherTeam)); // IsValidClient(target, false)
                
                if (IsValidClient(target)) // Maybe it can fail it we teleport to nobody?
                {
                    // Chdata's HHH teleport rework
                    if (TF2_GetPlayerClass(target) != TFClass_Scout && TF2_GetPlayerClass(target) != TFClass_Soldier)
                    {
                        SetEntProp(Hale, Prop_Send, "m_CollisionGroup", 2); //Makes HHH clipping go away for player and some projectiles
                        CreateTimer(bEnableSuperDuperJump ? 4.0:2.0, HHHTeleTimer, _, TIMER_FLAG_NO_MAPCHANGE);
                    }

                    SetEntPropFloat(Hale, Prop_Send, "m_flNextAttack", GetGameTime() + (bEnableSuperDuperJump ? 4.0 : 2.0));
                    SetEntProp(Hale, Prop_Send, "m_bGlowEnabled", 0);
                    GlowTimer = 0.0;

                    AttachParticle(Hale, "ghost_appearation", 3.0);             // One is parented and one is not

                    if (TeleMeToYou(Hale, target)) // This returns true if teleport to a ducking player happened
                    {
                        VSHFlags[Hale] |= VSHFLAG_NEEDSTODUCK;

                        new Handle:timerpack;
                        CreateDataTimer(0.2, Timer_StunHHH, timerpack, TIMER_FLAG_NO_MAPCHANGE);
                        WritePackCell(timerpack, bEnableSuperDuperJump);
                        WritePackCell(timerpack, GetClientUserId(target));
                    }
                    else
                    {
                        TF2_StunPlayer(Hale, (bEnableSuperDuperJump ? 4.0 : 2.0), 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT, target);
                    }

                    AttachParticle(Hale, "ghost_appearation", 3.0, _, true);    // So the teleport smoke appears at both destinations
                    
                    // Chdata's HHH teleport rework
                    decl Float:vPos[3];
                    GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);

                    EmitSoundToClient(Hale, "misc/halloween/spell_teleport.wav", _, _, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, vPos, NULL_VECTOR, false, 0.0);
                    EmitSoundToClient(target, "misc/halloween/spell_teleport.wav", _, _, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, vPos, NULL_VECTOR, false, 0.0);

                    PriorityCenterText(target, true, "You've been teleported to!");

                    HaleCharge = -1100;
                }
                if (bEnableSuperDuperJump)
                    bEnableSuperDuperJump = false;
            }
            else if (Special != VSHSpecial_HHH)
            {
                decl Float:vel[3];
                GetEntPropVector(Hale, Prop_Data, "m_vecVelocity", vel);
                if (bEnableSuperDuperJump)
                {
                    vel[2]=750 + HaleCharge * 13.0 + 2000;
                    bEnableSuperDuperJump = false;
                }
                else
                    vel[2]=750 + HaleCharge * 13.0;
                SetEntProp(Hale, Prop_Send, "m_bJumping", 1);
                vel[0] *= (1+Sine(float(HaleCharge) * FLOAT_PI / 50));
                vel[1] *= (1+Sine(float(HaleCharge) * FLOAT_PI / 50));
                TeleportEntity(Hale, NULL_VECTOR, NULL_VECTOR, vel);
                HaleCharge=-120;
                new String:s[PLATFORM_MAX_PATH];
                switch (Special)
                {
                    case VSHSpecial_Vagineer:
                        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerJump, GetRandomInt(1, 2));
                    case VSHSpecial_CBS:
                        strcopy(s, PLATFORM_MAX_PATH, CBSJump1);
#if defined EASTER_BUNNY_ON
                    case VSHSpecial_Bunny:
                        strcopy(s, PLATFORM_MAX_PATH, BunnyJump[GetRandomInt(0, sizeof(BunnyJump)-1)]);
#endif
                    case VSHSpecial_Hale:
                    {
                        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", GetRandomInt(0, 1) ? HaleJump : HaleJump132, GetRandomInt(1, 2));
                    }
                }
                if (s[0] != '\0')
                {
                    GetEntPropVector(Hale, Prop_Send, "m_vecOrigin", pos);
                    EmitSoundToAll(s, Hale, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, true, 0.0);
                    EmitSoundToAll(s, Hale, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, true, 0.0);
                    for (new i = 1; i <= MaxClients; i++)
                        if (IsClientInGame(i) && (i != Hale))
                        {
                            EmitSoundToClient(i, s, Hale, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, true, 0.0);
                            EmitSoundToClient(i, s, Hale, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, true, 0.0);
                        }
                }
            }
        }
        else
            HaleCharge = 0;
    }
    if (RedAlivePlayers == 1)
    {
        switch (Special)
        {
            case VSHSpecial_Bunny:
                PriorityCenterTextAll(_, "%t", "vsh_bunny_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_Vagineer:
                PriorityCenterTextAll(_, "%t", "vsh_vagineer_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_HHH:
                PriorityCenterTextAll(_, "%t", "vsh_hhh_hp", HaleHealth, HaleHealthMax);
            case VSHSpecial_CBS:
                PriorityCenterTextAll(_, "%t", "vsh_cbs_hp", HaleHealth, HaleHealthMax);
            default:
                PriorityCenterTextAll(_, "%t", "vsh_hale_hp", HaleHealth, HaleHealthMax);
        }
    }
    if (OnlyScoutsLeft())
    {
        new Float:rage = 0.001*RageDMG;
        HaleRage += RoundToCeil(rage);
        if (HaleRage > RageDMG)
            HaleRage = RageDMG;
    }

    if (!(GetEntityFlags(Hale) & FL_ONGROUND))
    {
        WeighDownTimer += 0.2;
    }
    else
    {
        HHHClimbCount = 0;
        WeighDownTimer = 0.0;
    }

    if (WeighDownTimer >= 4.0 && buttons & IN_DUCK && GetEntityGravity(Hale) != 6.0)
    {
        decl Float:ang[3];
        GetClientEyeAngles(Hale, ang);
        if ((ang[0] > 60.0))
        {
            new Action:act = Plugin_Continue;
            Call_StartForward(OnHaleWeighdown);
            Call_Finish(act);
            if (act != Plugin_Continue)
                return Plugin_Continue;
            new Float:fVelocity[3];
            GetEntPropVector(Hale, Prop_Data, "m_vecVelocity", fVelocity);
            fVelocity[2] = -1000.0;
            TeleportEntity(Hale, NULL_VECTOR, NULL_VECTOR, fVelocity);
            SetEntityGravity(Hale, 6.0);
            CreateTimer(2.0, Timer_GravityCat, GetClientUserId(Hale), TIMER_FLAG_NO_MAPCHANGE);
            CPrintToChat(Hale, "{olive}[VSH]{default} %t", "vsh_used_weighdown");
            WeighDownTimer = 0.0;
        }
    }
    return Plugin_Continue;
}

public Action:HHHTeleTimer(Handle:timer)
{
    if (IsValidClient(Hale))
    {
        SetEntProp(Hale, Prop_Send, "m_CollisionGroup", 5); //Fix HHH's clipping.
    }
}

public Action:Timer_StunHHH(Handle:timer, Handle:pack)
{
    if (!IsValidClient(Hale)) return; // IsValidClient(Hale, false)
    ResetPack(pack);
    new superduper = ReadPackCell(pack);
    new targetid = ReadPackCell(pack);
    new target = GetClientOfUserId(targetid);
    if (!IsValidClient(target)) target = 0; // IsValidClient(target, false)
    VSHFlags[Hale] &= ~VSHFLAG_NEEDSTODUCK;
    TF2_StunPlayer(Hale, (superduper ? 4.0 : 2.0), 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT, target);
}
public Action:Timer_BotRage(Handle:timer)
{
    if (!IsValidClient(Hale)) return; // IsValidClient(Hale, false)
    if (!TF2_IsPlayerInCondition(Hale, TFCond_Taunting)) FakeClientCommandEx(Hale, "taunt");
}
OnlyScoutsLeft()
{
    for (new client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && IsPlayerAlive(client) && client != Hale && TF2_GetPlayerClass(client) != TFClass_Scout)
            return false;
    }
    return true;
}
public Action:Timer_GravityCat(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) SetEntityGravity(client, 1.0);
}
public Action:Destroy(client, const String:command[], argc)
{
    if (!g_bEnabled || client == Hale)
        return Plugin_Continue;
    if (IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Engineer && TF2_IsPlayerInCondition(client, TFCond_Taunting) && GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 589)
        return Plugin_Handled;
    return Plugin_Continue;
}

static bool:s_bPreventDeadringEffects[TF_MAX_PLAYERS] = {false, ...};

public TF2_OnConditionAdded(client, TFCond:cond)
{
    if (!g_bEnabled)
    {
        return;
    }

    if (client != Hale)
    {
        switch (cond)
        {
            case TFCond_Cloaked:
            {
                switch (GetClientCloakIndex(client))
                {
                    case 59: // Deadringer
                    {
                        s_bPreventDeadringEffects[client] = true;
                        RequestFrame(Frame_AllowDeadringEffects, client);
                    }
                }
            }
            case TFCond_DeadRingered, TFCond_SpeedBuffAlly: //, TFCond:102
            {
                if (s_bPreventDeadringEffects[client])
                {
                    TF2_RemoveCondition(client, cond);
                }
            }
        }
    }
}

public Frame_AllowDeadringEffects(any:client)
{
    s_bPreventDeadringEffects[client] = false;
    if (IsClientInGame(client))
    {
        SetVariantString("ParticleEffectStop");
        AcceptEntityInput(client, "DispatchEffect");
    }
}

public TF2_OnConditionRemoved(client, TFCond:condition)
{
    if (TF2_GetPlayerClass(client) == TFClass_Scout && condition == TFCond_CritHype)
    {
        TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);   //recalc their speed
    }
}


/*
 Call medic to rage update by Chdata

*/
public Action:cdVoiceMenu(iClient, const String:sCommand[], iArgc)
{
    if (iArgc < 2) return Plugin_Handled;

    decl String:sCmd1[8], String:sCmd2[8];
    
    GetCmdArg(1, sCmd1, sizeof(sCmd1));
    GetCmdArg(2, sCmd2, sizeof(sCmd2));
    
    // Capture call for medic commands (represented by "voicemenu 0 0")

    if (sCmd1[0] == '0' && sCmd2[0] == '0' && IsPlayerAlive(iClient) && iClient == Hale)
    {
        if (HaleRage / RageDMG >= 1)
        {
            DoTaunt(iClient, "", 0);
            return Plugin_Handled;
        }
    }
    
    return (iClient == Hale && Special != VSHSpecial_CBS && Special != VSHSpecial_Bunny) ? Plugin_Handled : Plugin_Continue;
}

public Action:DoTaunt(client, const String:command[], argc)
{
    if (!g_bEnabled || (client != Hale))
        return Plugin_Continue;

    if (!IfDoNextTime(e_flNextBossTaunt, 1.5)) // Prevent double-tap rages
    {
        return Plugin_Handled;
    }

    decl String:s[PLATFORM_MAX_PATH];
    if (HaleRage/RageDMG >= 1)
    {
        decl Float:pos[3];
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
        pos[2] += 20.0;
        new Action:act = Plugin_Continue;
        Call_StartForward(OnHaleRage);
        new Float:dist;
        new Float:newdist;
        switch (Special)
        {
            case VSHSpecial_Vagineer: dist = RageDist/(1.5);
            case VSHSpecial_Bunny: dist = RageDist/(1.5);
            case VSHSpecial_CBS: dist = RageDist/(2.5);
            default: dist = RageDist;
        }
        newdist = dist;
        Call_PushFloatRef(newdist);
        Call_Finish(act);
        if (act != Plugin_Continue && act != Plugin_Changed)
            return Plugin_Continue;
        if (act == Plugin_Changed) dist = newdist;
        TF2_AddCondition(Hale, TFCond:42, 4.0);
        switch (Special)
        {
            case VSHSpecial_Vagineer:
            {
                if (GetRandomInt(0, 2))
                    strcopy(s, PLATFORM_MAX_PATH, VagineerRageSound);
                else
                    Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerRageSound2, GetRandomInt(1, 2));
                TF2_AddCondition(Hale, TFCond_Ubercharged, 99.0);
                UberRageCount = 0.0;

                CreateTimer(0.6, UseRage, dist);
                CreateTimer(0.1, UseUberRage, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            }
            case VSHSpecial_HHH:
            {
                Format(s, PLATFORM_MAX_PATH, "%s", HHHRage2);
                CreateTimer(0.6, UseRage, dist);
            }
#if defined EASTER_BUNNY_ON
            case VSHSpecial_Bunny:
            {
                strcopy(s, PLATFORM_MAX_PATH, BunnyRage[GetRandomInt(1, sizeof(BunnyRage)-1)]);
                EmitSoundToAll(s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, pos, NULL_VECTOR, false, 0.0);
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                new weapon = SpawnWeapon(client, "tf_weapon_grenadelauncher", 19, 100, 5, "6 ; 0.1 ; 411 ; 150.0 ; 413 ; 1.0 ; 37 ; 0.0 ; 280 ; 17 ; 477 ; 1.0 ; 467 ; 1.0 ; 181 ; 2.0 ; 252 ; 0.7");
                SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
                SetEntProp(weapon, Prop_Send, "m_iClip1", 50);
//              new vm = CreateVM(client, ReloadEggModel);
//              SetEntPropEnt(vm, Prop_Send, "m_hWeaponAssociatedWith", weapon);
//              SetEntPropEnt(weapon, Prop_Send, "m_hExtraWearableViewModel", vm);
                SetAmmo(client, TFWeaponSlot_Primary, 0);
                //add charging?
                CreateTimer(0.6, UseRage, dist);
            }
#endif
            case VSHSpecial_CBS:
            {
                if (GetRandomInt(0, 1))
                    Format(s, PLATFORM_MAX_PATH, "%s", CBS1);
                else
                    Format(s, PLATFORM_MAX_PATH, "%s", CBS3);
                EmitSoundToAll(s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, pos, NULL_VECTOR, false, 0.0);
                TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
                SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_compound_bow", 1005, 100, 5, "2 ; 2.1 ; 6 ; 0.5 ; 37 ; 0.0 ; 280 ; 19 ; 551 ; 1"));
                SetAmmo(client, TFWeaponSlot_Primary, ((RedAlivePlayers >= CBS_MAX_ARROWS) ? CBS_MAX_ARROWS : RedAlivePlayers));
                CreateTimer(0.6, UseRage, dist);
                CreateTimer(0.1, UseBowRage);
            }
            default:
            {
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleRageSound, GetRandomInt(1, 4));
                CreateTimer(0.6, UseRage, dist);
            }
        }
        EmitSoundToAll(s, client, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
        EmitSoundToAll(s, client, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && i != Hale)
            {
                EmitSoundToClient(i, s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
                EmitSoundToClient(i, s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
            }
        }
        HaleRage = 0;
        VSHFlags[Hale] &= ~VSHFLAG_BOTRAGE;
    }

    // bNoTaunt = true;
    // CreateTimer(1.5, Timer_NoTaunting, _, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

// public Action:Timer_NoTaunting(Handle:timer)
// {
//     bNoTaunt = false;
// }

public Action:DoSuicide(client, const String:command[], argc)
{
    if (g_bEnabled && (VSHRoundState == VSHRState_Waiting || VSHRoundState == VSHRState_Active))
    {
        if (client == Hale && !IsNextTime(e_flNextAllowBossSuicide))
        {
            CPrintToChat(client, "Do not suicide as Hale. Use !resetq instead.");
            return Plugin_Handled;
            //KickClient(client, "Next time, please remember to !hale_resetq");
            //if (VSHRoundState == VSHRState_Waiting) return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}
public Action:DoSuicide2(client, const String:command[], argc)
{
    if (g_bEnabled && client == Hale && !IsNextTime(e_flNextAllowBossSuicide))
    {
        CPrintToChat(client, "You can't change teams this early.");
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
public Action:UseRage(Handle:hTimer, any:dist)
{
    decl Float:pos[3];
    decl Float:pos2[3];
    decl i;
    decl Float:distance;
    if (!IsValidClient(Hale)) return Plugin_Continue; // IsValidClient(Hale, false)
    if (!GetEntProp(Hale, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(Hale, Prop_Send, "m_hHighFivePartner")))
    {
        TF2_RemoveCondition(Hale, TFCond_Taunting);
        MakeModelTimer(INVALID_HANDLE); // should reset Hale's animation
    }
    GetEntPropVector(Hale, Prop_Send, "m_vecOrigin", pos);
    for (i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && (i != Hale))
        {
            GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
            distance = GetVectorDistance(pos, pos2);
            if (!TF2_IsPlayerInCondition(i, TFCond_Ubercharged) && distance < dist)
            {
                new flags = TF_STUNFLAGS_GHOSTSCARE;
                if (Special != VSHSpecial_HHH)
                {
                    flags |= TF_STUNFLAG_NOSOUNDOREFFECT;
                    AttachParticle(i, "yikes_fx", 5.0, Float:{0.0,0.0,75.0}, true);
                }
                if (VSHRoundState != VSHRState_Waiting) TF2_StunPlayer(i, 5.0, _, flags, (Special == VSHSpecial_HHH ? 0 : Hale));
            }
        }
    }
    i = -1;
    while ((i = FindEntityByClassname2(i, "obj_sentrygun")) != -1)
    {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        distance = GetVectorDistance(pos, pos2);
        if (dist <= RageDist/3) dist = RageDist/2;
        if (distance < dist)    //(!mode && (distance < RageDist)) || (mode && (distance < RageDist/2)))
        {
            SetEntProp(i, Prop_Send, "m_bDisabled", 1);
            AttachParticle(i, "yikes_fx", 3.0, Float:{0.0,0.0,75.0}, true);
            if (newRageSentry)
            {
                SetVariantInt(GetEntProp(i, Prop_Send, "m_iHealth")/2);
                AcceptEntityInput(i, "RemoveHealth");
            }
            else
            {
                SetEntProp(i, Prop_Send, "m_iHealth", GetEntProp(i, Prop_Send, "m_iHealth")/2);
            }
            CreateTimer(8.0, EnableSG, EntIndexToEntRef(i));
        }
    }
    i = -1;
    while ((i = FindEntityByClassname2(i, "obj_dispenser")) != -1)
    {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        distance = GetVectorDistance(pos, pos2);
        if (dist <= RageDist/3) dist = RageDist/2;
        if (distance < dist)    //(!mode && (distance < RageDist)) || (mode && (distance < RageDist/2)))
        {
            SetVariantInt(1);
            AcceptEntityInput(i, "RemoveHealth");
        }
    }
    i = -1;
    while ((i = FindEntityByClassname2(i, "obj_teleporter")) != -1)
    {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        distance = GetVectorDistance(pos, pos2);
        if (dist <= RageDist/3) dist = RageDist/2;
        if (distance < dist)    //(!mode && (distance < RageDist)) || (mode && (distance < RageDist/2)))
        {
            SetVariantInt(1);
            AcceptEntityInput(i, "RemoveHealth");
        }
    }

    return Plugin_Continue;
}
public Action:UseUberRage(Handle:hTimer, any:param)
{
    if (!IsValidClient(Hale))
        return Plugin_Stop;
    if (UberRageCount == 1)
    {
        if (!GetEntProp(Hale, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(Hale, Prop_Send, "m_hHighFivePartner")))
        {
            TF2_RemoveCondition(Hale, TFCond_Taunting);
            MakeModelTimer(INVALID_HANDLE); // should reset Hale's animation
        }
//      TF2_StunPlayer(Hale, 0.0, _, TF_STUNFLAG_NOSOUNDOREFFECT);
    }
    else if (UberRageCount >= 100)
    {
        if (defaulttakedamagetype == 0) defaulttakedamagetype = 2;
        SetEntProp(Hale, Prop_Data, "m_takedamage", defaulttakedamagetype);
        defaulttakedamagetype = 0;
        TF2_RemoveCondition(Hale, TFCond_Ubercharged);
        return Plugin_Stop;
    }
    else if (UberRageCount >= 85 && !TF2_IsPlayerInCondition(Hale, TFCond_UberchargeFading))
    {
        TF2_AddCondition(Hale, TFCond_UberchargeFading, 3.0);
    }
    if (!defaulttakedamagetype)
    {
        defaulttakedamagetype = GetEntProp(Hale, Prop_Data, "m_takedamage");
        if (defaulttakedamagetype == 0) defaulttakedamagetype = 2;
    }
    SetEntProp(Hale, Prop_Data, "m_takedamage", 0);
    UberRageCount += 1.0;
    return Plugin_Continue;
}
public Action:UseBowRage(Handle:hTimer)
{
    if (!GetEntProp(Hale, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(Hale, Prop_Send, "m_hHighFivePartner")))
    {
        TF2_RemoveCondition(Hale, TFCond_Taunting);
        MakeModelTimer(INVALID_HANDLE); // should reset Hale's animation
    }
//  TF2_StunPlayer(Hale, 0.0, _, TF_STUNFLAG_NOSOUNDOREFFECT);
//  UberRageCount = 9.0;
    SetAmmo(Hale, 0, ((RedAlivePlayers >= CBS_MAX_ARROWS) ? CBS_MAX_ARROWS : RedAlivePlayers));
    return Plugin_Continue;
}
public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
    decl String:s[PLATFORM_MAX_PATH];
    if (!g_bEnabled)
        return Plugin_Continue;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client || !IsClientInGame(client))
        return Plugin_Continue;
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new deathflags = GetEventInt(event, "death_flags");
    new customkill = GetEventInt(event, "customkill");
#if defined EASTER_BUNNY_ON
    if (attacker == Hale && Special == VSHSpecial_Bunny && VSHRoundState == VSHRState_Active)  SpawnManyAmmoPacks(client, EggModel, 1, 5, 120.0);
#endif
    if (attacker == Hale && VSHRoundState == VSHRState_Active && (deathflags & TF_DEATHFLAG_DEADRINGER))
    {
        numHaleKills++;
        if (customkill != TF_CUSTOM_BOOTS_STOMP)
        {
            if (Special == VSHSpecial_Hale) SetEventString(event, "weapon", "fists");
        }
        return Plugin_Continue;
    }
    if (GetClientHealth(client) > 0)
        return Plugin_Continue;
    CreateTimer(0.1, CheckAlivePlayers);
    if (client != Hale && VSHRoundState == VSHRState_Active)
        CreateTimer(1.0, Timer_Damage, GetClientUserId(client));
    if (client == Hale && VSHRoundState == VSHRState_Active)
    {
        switch (Special)
        {
            case VSHSpecial_HHH:
            {
                Format(s, PLATFORM_MAX_PATH, "vo/halloween_boss/knight_death0%d.mp3", GetRandomInt(1, 2));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAll("ui/halloween_boss_defeated_fx.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
//              CreateTimer(0.1, Timer_ChangeRagdoll, any:GetEventInt(event, "userid"));
            }
            case VSHSpecial_Hale:
            {
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleFail, GetRandomInt(1, 3));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
//              CreateTimer(0.1, Timer_ChangeRagdoll, any:GetEventInt(event, "userid"));
            }
            case VSHSpecial_Vagineer:
            {
                Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerFail, GetRandomInt(1, 2));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
//              CreateTimer(0.1, Timer_ChangeRagdoll, any:GetEventInt(event, "userid"));
            }
#if defined EASTER_BUNNY_ON
            case VSHSpecial_Bunny:
            {
                strcopy(s, PLATFORM_MAX_PATH, BunnyFail[GetRandomInt(0, sizeof(BunnyFail)-1)]);
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, NULL_VECTOR, NULL_VECTOR, false, 0.0);
//              CreateTimer(0.1, Timer_ChangeRagdoll, any:GetEventInt(event, "userid"));
                SpawnManyAmmoPacks(client, EggModel, 1);
            }
#endif
        }
        if (HaleHealth < 0)
            HaleHealth = 0;
        ForceTeamWin(OtherTeam);
        return Plugin_Continue;
    }
    if (attacker == Hale && VSHRoundState == VSHRState_Active)
    {
        numHaleKills++;
        switch (Special)
        {
            case VSHSpecial_Hale:
            {
                if (customkill != TF_CUSTOM_BOOTS_STOMP) SetEventString(event, "weapon", "fists");
                if (!GetRandomInt(0, 2) && RedAlivePlayers != 1)
                {
                    strcopy(s, PLATFORM_MAX_PATH, "");
                    new TFClassType:playerclass = TF2_GetPlayerClass(client);
                    switch (playerclass)
                    {
                        case TFClass_Scout:     strcopy(s, PLATFORM_MAX_PATH, HaleKillScout132);
                        case TFClass_Pyro:      strcopy(s, PLATFORM_MAX_PATH, HaleKillPyro132);
                        case TFClass_DemoMan:   strcopy(s, PLATFORM_MAX_PATH, HaleKillDemo132);
                        case TFClass_Heavy:     strcopy(s, PLATFORM_MAX_PATH, HaleKillHeavy132);
                        case TFClass_Medic:     strcopy(s, PLATFORM_MAX_PATH, HaleKillMedic);
                        case TFClass_Sniper:
                        {
                            if (GetRandomInt(0, 1)) strcopy(s, PLATFORM_MAX_PATH, HaleKillSniper1);
                            else strcopy(s, PLATFORM_MAX_PATH, HaleKillSniper2);
                        }
                        case TFClass_Spy:
                        {
                            new see = GetRandomInt(0, 2);
                            if (!see) strcopy(s, PLATFORM_MAX_PATH, HaleKillSpy1);
                            else if (see == 1) strcopy(s, PLATFORM_MAX_PATH, HaleKillSpy2);
                            else strcopy(s, PLATFORM_MAX_PATH, HaleKillSpy132);
                        }
                        case TFClass_Engineer:
                        {
                            new see = GetRandomInt(0, 3);
                            if (!see) strcopy(s, PLATFORM_MAX_PATH, HaleKillEngie1);
                            else if (see == 1) strcopy(s, PLATFORM_MAX_PATH, HaleKillEngie2);
                            else Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKillEngie132, GetRandomInt(1, 2));
                        }
                    }
                    if (!StrEqual(s, ""))
                    {
                        EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                    }
                }
            }
            case VSHSpecial_Vagineer:
            {
                strcopy(s, PLATFORM_MAX_PATH, VagineerHit);
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAll(s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
//              CreateTimer(0.1, Timer_DissolveRagdoll, any:GetEventInt(event, "userid"));
            }
            case VSHSpecial_HHH:
            {
                Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHAttack, GetRandomInt(1, 4));
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAll(s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
            }
#if defined EASTER_BUNNY_ON
            case VSHSpecial_Bunny:
            {
                strcopy(s, PLATFORM_MAX_PATH, BunnyKill[GetRandomInt(0, sizeof(BunnyKill)-1)]);
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                EmitSoundToAll(s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
            }
#endif
            case VSHSpecial_CBS:
            {
                if (!GetRandomInt(0, 3) && RedAlivePlayers != 1)
                {
                    new TFClassType:playerclass = TF2_GetPlayerClass(client);
                    switch (playerclass)
                    {
                        case TFClass_Spy:
                        {
                            strcopy(s, PLATFORM_MAX_PATH, "vo/sniper_dominationspy04.mp3");
                            EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                            EmitSoundToAll(s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        }
                    }
                }
                new weapon = GetEntPropEnt(Hale, Prop_Send, "m_hActiveWeapon");
                if (weapon == GetPlayerWeaponSlot(Hale, TFWeaponSlot_Melee))
                {
                    TF2_RemoveWeaponSlot(Hale, TFWeaponSlot_Melee);
                    new clubindex, wepswitch = GetRandomInt(0, 3);
                    switch (wepswitch)
                    {
                        case 0: clubindex = 171;
                        case 1: clubindex = 3;
                        case 2: clubindex = 232;
                        case 3: clubindex = 401;
                    }
                    weapon = SpawnWeapon(Hale, "tf_weapon_club", clubindex, 100, TFQual_Unusual, "68 ; 2.0 ; 2 ; 3.1 ; 259 ; 1.0");
                    SetEntPropEnt(Hale, Prop_Send, "m_hActiveWeapon", weapon); // Technically might be pointless, as SpawnWeapon already calls EquipPlayerWeapon
                }
            }
        }
        if (IsNextTime(e_flNextBossKillSpreeEnd, 5.0)) //GetGameTime() <= KSpreeTimer)
        {
            KSpreeCount = 1;
        }
        else
        {
            KSpreeCount++;
        }

        if (KSpreeCount == 3 && RedAlivePlayers != 1)
        {
            switch (Special)
            {
                case VSHSpecial_Hale:
                {
                    new see = GetRandomInt(0, 7);
                    if (!see || see == 1)
                        strcopy(s, PLATFORM_MAX_PATH, HaleKSpree);
                    else if (see < 5)
                        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKSpreeNew, GetRandomInt(1, 5));
                    else
                        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleKillKSpree132, GetRandomInt(1, 2));
                }
                case VSHSpecial_Vagineer:
                {
                    if (GetRandomInt(0, 4) == 1)
                        strcopy(s, PLATFORM_MAX_PATH, VagineerKSpree);
                    else if (GetRandomInt(0, 3) == 1)
                        strcopy(s, PLATFORM_MAX_PATH, VagineerKSpree2);
                    else
                        Format(s, PLATFORM_MAX_PATH, "%s%i.wav", VagineerKSpreeNew, GetRandomInt(1, 5));
                }
                case VSHSpecial_HHH: Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHLaught, GetRandomInt(1, 4));
                case VSHSpecial_CBS:
                {
                    if (!GetRandomInt(0, 3))
                        Format(s, PLATFORM_MAX_PATH, CBS0);
                    else if (!GetRandomInt(0, 3))
                        Format(s, PLATFORM_MAX_PATH, CBS1);
                    else
                        Format(s, PLATFORM_MAX_PATH, "%s%02i.mp3", CBS2, GetRandomInt(1, 9));
                    EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                }
#if defined EASTER_BUNNY_ON
                case VSHSpecial_Bunny:
                {
                    strcopy(s, PLATFORM_MAX_PATH, BunnySpree[GetRandomInt(0, sizeof(BunnySpree)-1)]);
                }
#endif
            }
            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
            KSpreeCount = 0;
        }
        else
        {
            SetNextTime(e_flNextBossKillSpreeEnd, 5.0);
            //KSpreeTimer = GetGameTime() + 5.0;
        }
    }
    if ((TF2_GetPlayerClass(client) == TFClass_Engineer) && !(deathflags & TF_DEATHFLAG_DEADRINGER))
    {
        new ent = -1;
        while ((ent = FindEntityByClassname2(ent, "obj_sentrygun")) != -1)
        {
            if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
            {
                SetVariantInt(GetEntProp(ent, Prop_Send, "m_iMaxHealth") + 8);
                AcceptEntityInput(ent, "RemoveHealth");
            }
        }
    }
    return Plugin_Continue;
}
stock SpawnManyAmmoPacks(client, String:model[], skin=0, num=14, Float:offsz = 30.0)
{
//  if (hSetAmmoVelocity == INVALID_HANDLE) return;
    decl Float:pos[3], Float:vel[3], Float:ang[3];
    ang[0] = 90.0;
    ang[1] = 0.0;
    ang[2] = 0.0;
    GetClientAbsOrigin(client, pos);
    pos[2] += offsz;
    for (new i = 0; i < num; i++)
    {
        vel[0] = GetRandomFloat(-400.0, 400.0);
        vel[1] = GetRandomFloat(-400.0, 400.0);
        vel[2] = GetRandomFloat(300.0, 500.0);
        pos[0] += GetRandomFloat(-5.0, 5.0);
        pos[1] += GetRandomFloat(-5.0, 5.0);
        new ent = CreateEntityByName("tf_ammo_pack");
        if (!IsValidEntity(ent)) continue;
        SetEntityModel(ent, model);
        DispatchKeyValue(ent, "OnPlayerTouch", "!self,Kill,,0,-1"); //for safety, but it shouldn't act like a normal ammopack
        SetEntProp(ent, Prop_Send, "m_nSkin", skin);
        SetEntProp(ent, Prop_Send, "m_nSolidType", 6);
//      SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
//      SetEntProp(ent, Prop_Send, "movetype", 5);
//      SetEntProp(ent, Prop_Send, "movecollide", 0);
        SetEntProp(ent, Prop_Send, "m_usSolidFlags", 152);
        SetEntProp(ent, Prop_Send, "m_triggerBloat", 24);
        SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
        SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
        SetEntProp(ent, Prop_Send, "m_iTeamNum", 2);
        TeleportEntity(ent, pos, ang, vel);
        DispatchSpawn(ent);
        TeleportEntity(ent, pos, ang, vel);
//      SDKCall(hSetAmmoVelocity, ent, vel);
        SetEntProp(ent, Prop_Data, "m_iHealth", 900);
        new offs = GetEntSendPropOffs(ent, "m_vecInitialVelocity", true);
        SetEntData(ent, offs-4, 1, _, true);    //Sets to crit candy, offs-8 sets crit candy duration (is a float, 3*float = duration)
        //1358 is offs-14, that byte is for being a sandwich with +50hp, +75 for scouts. The byte after that, 1359, is to... not give the health? I don't know.
/*      SetEntData(ent, offs-13, 0, 1, true);
        SetEntData(ent, offs-11, 1, 1, true);
        SetEntData(ent, offs-15, 1, 1, true);
        SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
        SetEntProp(ent, Prop_Data, "m_nNextThinkTick", GetEntProp(client, Prop_Send, "m_nTickBase") + 3);
        SetEntPropVector(ent, Prop_Data, "m_vecAbsVelocity", vel);
        SetEntPropVector(ent, Prop_Data, "m_vecVelocity", vel);
        SetEntPropVector(ent, Prop_Send, "m_vecInitialVelocity", vel);
        SetEntProp(ent, Prop_Send, "m_bClientSideAnimation", 1);
        PrintToChatAll("aeiou %d %d %d %d %d", GetEntData(ent, offs-16, 1), GetEntData(ent, offs-15, 1), GetEntData(ent, offs-14, 1), GetEntData(ent, offs-13, 1), GetEntData(ent, offs-12, 1));
        */
    }
}
public Action:Timer_Damage(Handle:hTimer, any:id)
{
    new client = GetClientOfUserId(id);
    if (IsValidClient(client)) // IsValidClient(client, false)
        CPrintToChat(client, "{olive}[VSH]{default} %t. %t %i",
            "vsh_damage", Damage[client],
            "vsh_scores", RoundFloat(Damage[client] / 600.0)
        );
    return Plugin_Continue;
}
/*public Action:Timer_DissolveRagdoll(Handle:timer, any:userid)
{
    new victim = GetClientOfUserId(userid);
    new ragdoll = (IsValidClient(victim) ? GetEntPropEnt(victim, Prop_Send, "m_hRagdoll") : -1);
    if (IsValidEntity(ragdoll))
    {
        DissolveRagdoll(ragdoll);
    }
}
DissolveRagdoll(ragdoll)
{
    new dissolver = CreateEntityByName("env_entity_dissolver");

    if (!IsValidEntity(dissolver))
    {
        return;
    }
    DispatchKeyValue(dissolver, "dissolvetype", "0");
    DispatchKeyValue(dissolver, "magnitude", "200");
    DispatchKeyValue(dissolver, "target", "!activator");
    AcceptEntityInput(dissolver, "Dissolve", ragdoll);
    AcceptEntityInput(dissolver, "Kill");
    return;
}*/
/*public Action:Timer_ChangeRagdoll(Handle:timer, any:userid)
{
    new victim = GetClientOfUserId(userid);
    new ragdoll;
    if (IsValidClient(victim)) ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
    else ragdoll = -1;
    if (IsValidEntity(ragdoll))
    {
        switch (Special)
        {
            case VSHSpecial_Hale:       SetEntityModel(ragdoll, HaleModel);
            case VSHSpecial_Vagineer:   SetEntityModel(ragdoll, VagineerModel);
            case VSHSpecial_HHH:        SetEntityModel(ragdoll, HHHModel);
            case VSHSpecial_CBS:        SetEntityModel(ragdoll, CBSModel);
            case VSHSpecial_Bunny:      SetEntityModel(ragdoll, BunnyModel);
        }
    }
}*/
public Action:event_deflect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!g_bEnabled) return Plugin_Continue;
    new deflector = GetClientOfUserId(GetEventInt(event, "userid"));
    new owner = GetClientOfUserId(GetEventInt(event, "ownerid"));
    new weaponid = GetEventInt(event, "weaponid");
    if (owner != Hale) return Plugin_Continue;
    if (weaponid != 0) return Plugin_Continue;
    new Float:rage = 0.04*RageDMG;
    HaleRage += RoundToCeil(rage);
    if (HaleRage > RageDMG)
        HaleRage = RageDMG;
    if (Special != VSHSpecial_Vagineer) return Plugin_Continue;
    if (!TF2_IsPlayerInCondition(owner, TFCond_Ubercharged)) return Plugin_Continue;
    if (UberRageCount > 11) UberRageCount -= 10;
    new newammo = GetAmmo(deflector, 0) - 5;
    SetAmmo(deflector, 0, newammo <= 0 ? 0 : newammo);
    return Plugin_Continue;
}
public Action:event_jarate(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
    new client = BfReadByte(bf);
    new victim = BfReadByte(bf);
    if (victim != Hale) return Plugin_Continue;
    new jar = GetPlayerWeaponSlot(client, 1);

    new jindex = GetEntProp(jar, Prop_Send, "m_iItemDefinitionIndex");

    if (jar != -1 && (jindex == 58 || jindex == 1083 || jindex == 1105) && GetEntProp(jar, Prop_Send, "m_iEntityLevel") != -122)    //-122 is the Jar of Ants and should not be used in this
    {
        new Float:rage = 0.08*RageDMG;
        HaleRage -= RoundToFloor(rage);
        if (HaleRage < 0)
            HaleRage = 0;
        if (Special == VSHSpecial_Vagineer && TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && UberRageCount < 99)
        {
            UberRageCount += 7.0;
            if (UberRageCount > 99) UberRageCount = 99.0;
        }
        new ammo = GetAmmo(Hale, 0);
        if (Special == VSHSpecial_CBS && ammo > 0) SetAmmo(Hale, 0, ammo - 1);
    }
    return Plugin_Continue;
}
public Action:CheckAlivePlayers(Handle:hTimer)
{
    if (VSHRoundState != VSHRState_Active) //(VSHRoundState == VSHRState_End || VSHRoundState == VSHRState_Disabled)
    {
        return Plugin_Continue;
    }
    RedAlivePlayers = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && (GetEntityTeamNum(i) == OtherTeam))
            RedAlivePlayers++;
    }
    if (Special == VSHSpecial_CBS && GetAmmo(Hale, 0) > RedAlivePlayers && RedAlivePlayers != 0) SetAmmo(Hale, 0, RedAlivePlayers);
    if (RedAlivePlayers == 0)
        ForceTeamWin(HaleTeam);
    else if (RedAlivePlayers == 1 && IsValidClient(Hale) && VSHRoundState == VSHRState_Active)
    {
        decl Float:pos[3];
        decl String:s[PLATFORM_MAX_PATH];
        GetEntPropVector(Hale, Prop_Send, "m_vecOrigin", pos);
        if (Special != VSHSpecial_HHH)
        {
            if (Special == VSHSpecial_CBS)
            {
                if (!GetRandomInt(0, 2))
                    Format(s, PLATFORM_MAX_PATH, "%s", CBS0);
                else
                {
                    Format(s, PLATFORM_MAX_PATH, "%s%02i.mp3", CBS4, GetRandomInt(1, 25));
                }
                EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, pos, NULL_VECTOR, false, 0.0);
            }
#if defined EASTER_BUNNY_ON
            else if (Special == VSHSpecial_Bunny)
                strcopy(s, PLATFORM_MAX_PATH, BunnyLast[GetRandomInt(0, sizeof(BunnyLast)-1)]);
#endif
            else if (Special == VSHSpecial_Vagineer)
                strcopy(s, PLATFORM_MAX_PATH, VagineerLastA);
            else
            {
                new see = GetRandomInt(0, 5);
                switch (see)
                {
                    case 0: strcopy(s, PLATFORM_MAX_PATH, HaleComicArmsFallSound);
                    case 1: Format(s, PLATFORM_MAX_PATH, "%s0%i.mp3", HaleLastB, GetRandomInt(1, 4));
                    case 2: strcopy(s, PLATFORM_MAX_PATH, HaleKillLast132);
                    default: Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleLastMan, GetRandomInt(1, 5));
                }
            }
            EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, false, 0.0);
            EmitSoundToAll(s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, pos, NULL_VECTOR, false, 0.0);
        }
    }
    
    if (!PointType && (RedAlivePlayers <= (AliveToEnable = GetConVarInt(cvarAliveToEnable))) && !PointReady)
    {
        PrintHintTextToAll("%t", "vsh_point_enable", RedAlivePlayers);
        if (RedAlivePlayers == AliveToEnable) EmitSoundToAll("vo/announcer_am_capenabled02.mp3");
        else if (RedAlivePlayers < AliveToEnable)
        {
            decl String:s[PLATFORM_MAX_PATH];
            Format(s, PLATFORM_MAX_PATH, "vo/announcer_am_capincite0%i.mp3", GetRandomInt(0, 1) ? 1 : 3);
            EmitSoundToAll(s);
        }
        SetControlPoint(true);
        PointReady = true;
    }
    return Plugin_Continue;
}
public Action:event_hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!g_bEnabled)
        return Plugin_Continue;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new damage = GetEventInt(event, "damageamount");
    new custom = GetEventInt(event, "custom");
    new weapon = GetEventInt(event, "weaponid");
    if (client != Hale) // || !IsValidEdict(client) || !IsValidEdict(attacker) || (client <= 0) || (attacker <= 0) || (attacker > MaxClients))
        return Plugin_Continue;

    if (!IsValidClient(attacker) || !IsValidClient(client) || client == attacker) // || custom == TF_CUSTOM_BACKSTAB)
        return Plugin_Continue;

    if (custom == TF_CUSTOM_TELEFRAG) damage = (IsPlayerAlive(attacker) ? 9001:1);

    if (GetEventBool(event, "minicrit") && GetEventBool(event, "allseecrit")) SetEventBool(event, "allseecrit", false);

    HaleHealth -= damage;
    HaleRage += damage;

    if (custom == TF_CUSTOM_TELEFRAG) SetEventInt(event, "damageamount", damage);

    Damage[attacker] += damage;

    if (TF2_GetPlayerClass(attacker) == TFClass_Soldier && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 1104)
    {
        if (weapon == TF_WEAPON_ROCKETLAUNCHER)
        {
            AirDamage[attacker] += damage;
        }

        SetEntProp(attacker, Prop_Send, "m_iDecapitations", AirDamage[attacker]/200);
    }

    new healers[TF_MAX_PLAYERS];
    new healercount = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && (GetHealingTarget(i) == attacker))
        {
            healers[healercount] = i;
            healercount++;
        }
    }
    for (new i = 0; i < healercount; i++)
    {
        if (IsValidClient(healers[i]) && IsPlayerAlive(healers[i]))
        {
            if (damage < 10 || uberTarget[healers[i]] == attacker)
                Damage[healers[i]] += damage;
            else
                Damage[healers[i]] += damage/(healercount+1);
        }
    }

    if (HaleRage > RageDMG)
        HaleRage = RageDMG;
    return Plugin_Continue;
}

#if defined _rtd_included
public Action:RTD_CanRollDice(iClient)
{
    if (g_bEnabled && iClient == Hale && !GetConVarBool(cvarCanBossRTD))
    {
        return Plugin_Handled; // Prevent boss from RTDing if setting is disabled.
    }
    return Plugin_Continue;
}
#endif

#if defined _goomba_included_
public Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageAdd, &Float:JumpPower)
{
    if (!g_bEnabled) //  || !IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim
    {
        return Plugin_Continue; // ... All of those checks are pointless.
    }
        
    if (attacker == Hale)
    {
        if (!GetConVarBool(cvarCanBossGoombaStompPlayers))
        {
            return Plugin_Handled;
        }

        if (RemoveDemoShield(victim)) // If the demo had a shield to break
        {
            EmitSoundToClient(victim, "player/spy_shield_break.wav", _, _, _, SND_CHANGEVOL, 0.7);
            EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, SND_CHANGEVOL, 0.7);
            EmitSoundToClient(victim, "player/crit_received3.wav", _, _, _, SND_CHANGEVOL, 0.7);
            EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, SND_CHANGEVOL, 0.7);

            TF2_AddCondition(victim, TFCond_Bonked, 0.1);
            TF2_AddCondition(victim, TFCond_SpeedBuffAlly, 1.0);
            damageAdd = 0.0;
            damageMultiplier = 0.0;
            //JumpPower = 0.0;
            return Plugin_Changed;
        }
        //PrintHintText(victim, "%t", "vsh_you_got_stomped");
        //PrintHintText(attacker, "%t", "vsh_you_stomped_hale", victim);
    }
    else if (victim == Hale)
    {
        if (IsValidEntity(FindPlayerBack(attacker, { 444, 405, 608 }, 3)) && !GetConVarBool(cvarCanWeMantreadGoomba))
        {
            return Plugin_Handled; // Prevent goomba stomp for mantreads if being able to is disabled.
        }

        damageAdd = GetConVarFloat(cvarDmgAddFromBossGoomba);
        damageMultiplier = GetConVarFloat(cvarDmgMultFromBossGoomba);
        JumpPower = GetConVarFloat(cvarReboundFromBossGoomba);
        //PrintHintText(victim, "%t", "vsh_you_got_stomped_hale", attacker);
        //PrintHintText(attacker, "%t", "vsh_you_stomped");
        //UpdateHealthBar();
        return Plugin_Changed;
    }
    return Plugin_Continue;
}
#endif

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    if (!g_bEnabled || !IsValidEdict(attacker) || ((attacker <= 0) && (client == Hale)) || TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
        return Plugin_Continue;
    if (VSHRoundState == VSHRState_Waiting && (client == Hale || (client != attacker && attacker != Hale)))
    {
        damage *= 0.0;
        return Plugin_Changed;
    }
    decl Float:vPos[3];
    GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", vPos);
    if ((attacker == Hale) && IsValidClient(client) && (client != Hale) && !TF2_IsPlayerInCondition(client, TFCond_Bonked) && !TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
    {
        if (TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed))
        {
            ScaleVector(damageForce, 9.0);
            damage *= 0.3;
            return Plugin_Changed;
        }
        if (TF2_IsPlayerInCondition(client, TFCond_DefenseBuffMmmph))
        {
            damage *= 9;
            TF2_AddCondition(client, TFCond_Bonked, 0.1);
            return Plugin_Changed;
        }
        if (TF2_IsPlayerInCondition(client, TFCond_CritMmmph))
        {
            damage *= 0.25;

            return Plugin_Changed;
        }

        if (RemoveDemoShield(client)) // If the demo had a shield to break
        {
            EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, _, _, 0.7, 100, _, vPos, _, false);
            EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, 100, _, vPos, _, false);

            TF2_AddCondition(client, TFCond_Bonked, 0.1);
            TF2_AddCondition(client, TFCond_SpeedBuffAlly, 1.0);
            return Plugin_Continue;
        }

        new bool:bDontDeadRingDamage = false;
        new TFClassType:iClass = TF2_GetPlayerClass(client);

        switch (iClass)
        {
            case TFClass_Spy:
            {
                if (damagecustom != TF_CUSTOM_BOOTS_STOMP)
                {
                    if (GetEntProp(client, Prop_Send, "m_bFeignDeathReady") || TF2_IsPlayerInCondition(client, TFCond_Cloaked))
                    {
                        damagetype &= ~DMG_CRIT;

                        new clk = GetClientCloakIndex(client);

                        if (damagetype & DMG_CLUB && !bDontDeadRingDamage) // Check melee damage so eggs from bunny don't get processed here.
                        {
                            damage = (clk == 59) ? 620.0 : 850.0;
                        }
                        else if (bDontDeadRingDamage) // This is in preparation for for future stuff.
                        {
                            damage *= 10.0; 
                        }

                        return Plugin_Changed;
                    }
                }
            }
        }

        new buffweapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
        new buffindex = (IsValidEntity(buffweapon) && buffweapon > MaxClients ? GetEntProp(buffweapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
        if (buffindex == 226)
        {
            CreateTimer(0.25, Timer_CheckBuffRage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
        if (damage <= 160.0 && !(Special == VSHSpecial_CBS && inflictor != attacker) && (Special != VSHSpecial_Bunny || weapon == -1 || weapon == GetPlayerWeaponSlot(Hale, TFWeaponSlot_Melee)))
        {
            damage *= 3;
            return Plugin_Changed;
        }
    }
    else if (attacker != Hale && client == Hale)
    {
        if (attacker <= MaxClients)
        {
            new bChanged = false;
            new iFlags = GetEntityFlags(Hale);

#if defined _tf2attributes_included
            if (g_bTF2AttributesIsRunning) // TODO: This probably isn't necessary at all!! The inflictor == weapon check below is why sentries never had DMG_PREVENT_PHYSICS_FORCE applied to it...
            {
                if ((iFlags & (FL_ONGROUND|FL_DUCKING)) == (FL_ONGROUND|FL_DUCKING))    //If Hale is ducking on the ground, it's harder to knock him back
                {
                    TF2Attrib_SetByDefIndex(Hale, 252, 0.0);        // "damage force reduction"
                    //damagetype |= DMG_PREVENT_PHYSICS_FORCE;
                    //bChanged = true;
                }
                else
                {
                    TF2Attrib_RemoveByDefIndex(Hale, 252);
                }
            }
            else
            {
                // Does not protect against sentries or FaN, but does against miniguns and rockets
                if ((iFlags & (FL_ONGROUND|FL_DUCKING)) == (FL_ONGROUND|FL_DUCKING))    
                {
                    damagetype |= DMG_PREVENT_PHYSICS_FORCE;
                    bChanged = true;
                }
            }
#else
            if ((iFlags & (FL_ONGROUND|FL_DUCKING)) == (FL_ONGROUND|FL_DUCKING))    
            {
                damagetype |= DMG_PREVENT_PHYSICS_FORCE;
                bChanged = true;
            }
#endif

            new wepindex = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
            if (inflictor == attacker || inflictor == weapon) // This prevents sentry damage and grenade/rocket damage from processing... not sure why this is here really.
            {
                if (damagecustom == TF_CUSTOM_BOOTS_STOMP)
                {
                    damage = 1024.0;

                    return Plugin_Changed;
                }
                if (damagecustom == TF_CUSTOM_TELEFRAG) //if (!IsValidEntity(weapon) && (damagetype & DMG_CRUSH) == DMG_CRUSH && damage == 1000.0)    //THIS IS A TELEFRAG
                {
                    if (!IsPlayerAlive(attacker)) // Is this even possible?
                    {
                        damage = 1.0;
                        return Plugin_Changed;
                    }

                    damage = 9001.0; //(HaleHealth > 9001 ? 15.0:float(GetEntProp(Hale, Prop_Send, "m_iHealth")) + 90.0);

                    new teleowner = FindTeleOwner(attacker);

                    if (IsValidClient(teleowner) && teleowner != attacker)
                    {
                        Damage[teleowner] += 5401; //RoundFloat(9001.0 * 3 / 5);
                        PriorityCenterText(teleowner, true, "TELEFRAG ASSIST! Nice job setting up!");
                    }

                    PriorityCenterText(attacker, true, "TELEFRAG! You are a pro.");
                    PriorityCenterText(client, true, "TELEFRAG! Be careful around quantum tunneling devices!");
                    return Plugin_Changed;
                }
                switch (wepindex)
                {
                    case 593:       //Third Degree
                    {
                        new healers[TF_MAX_PLAYERS];
                        new healercount = 0;
                        for (new i = 1; i <= MaxClients; i++)
                        {
                            if (IsClientInGame(i) && IsPlayerAlive(i) && (GetHealingTarget(i) == attacker))
                            {
                                healers[healercount] = i;
                                healercount++;
                            }
                        }
                        for (new i = 0; i < healercount; i++)
                        {
                            if (IsValidClient(healers[i]) && IsPlayerAlive(healers[i]))
                            {
                                new medigun = GetPlayerWeaponSlot(healers[i], TFWeaponSlot_Secondary);
                                if (IsValidEntity(medigun))
                                {
                                    new String:s[64];
                                    GetEntityClassname(medigun, s, sizeof(s));
                                    if (StrEqual(s, "tf_weapon_medigun", false))
                                    {
                                        new Float:uber = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel") + (0.1 / healercount);
                                        new Float:max = 1.0;
                                        if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease")) max = 1.5;
                                        if (uber > max) uber = max;
                                        SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", uber);
                                    }
                                }
                            }
                        }
                    }
                    case 14, 201, 664,
                         230, 402, 526, 1098, 752, // 752,            // Non-stock weapons
                         792, 801, 851, 881, 890, 899, 908, 957, 966, // Botkillers
                         15000, 15007, 15019, 15023, 15033, 15059:    // Gunmettle weapons
                    {
                        switch (wepindex) // Stock sniper rifle highlights Hale
                        {
                            case 14, 201, 664,
                                 792, 801, 851, 881, 890, 899, 908, 957, 966,
                                 15000, 15007, 15019, 15023, 15033, 15059:
                            {
                                if (VSHRoundState != VSHRState_End)
                                {
                                    new Float:chargelevel = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
                                    new Float:time = (GlowTimer > 10 ? 1.0 : 2.0);
                                    time += (GlowTimer > 10 ? (GlowTimer > 20 ? 1 : 2) : 4)*(chargelevel/100);
                                    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
                                    GlowTimer += RoundToCeil(time);
                                    if (GlowTimer > 30.0) GlowTimer = 30.0;
                                }
                            }
                        }
                        if (wepindex == 752 && VSHRoundState != VSHRState_End)
                        {
                            new Float:chargelevel = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
                            new Float:add = 10 + (chargelevel / 10);
                            if (TF2_IsPlayerInCondition(attacker, TFCond:46)) add /= 3;
                            new Float:rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
                            SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", (rage + add > 100) ? 100.0 : rage + add);
                        }
                        if (!(damagetype & DMG_CRIT))
                        {
                            new bool:ministatus = (TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed) || TF2_IsPlayerInCondition(attacker, TFCond_CritHype));

                            damage *= (ministatus) ? 2.222222 : 3.0;

                            if (wepindex == 230)
                            {
                                HaleRage -= RoundFloat(damage/2.0);
                                if (HaleRage < 0) HaleRage = 0;
                            }

                            return Plugin_Changed;
                        }
                        else if (wepindex == 230)
                        {
                            HaleRage -= RoundFloat(damage*3.0/2.0);
                            if (HaleRage < 0) HaleRage = 0;
                        }
                    }
                    case 355:
                    {
                        new Float:rage = 0.05*RageDMG;
                        HaleRage -= RoundToFloor(rage);
                        if (HaleRage < 0)
                            HaleRage = 0;
                    }
                    case 132, 266, 482, 1082: IncrementHeadCount(attacker);
                    case 416:   // Chdata's Market Gardener backstab
                    {
                        if (RemoveCond(attacker, TFCond_BlastJumping)) // New way to check explosive jumping status
                        {
                            // if (Special == VSHSpecial_HHH && !(GetEntityFlags(client) & FL_ONGROUND) && IsPlayerStuck(attacker) && TR_GetEntityIndex() == client) // TFCond_Dazed
                            // {
                            //     TF2_RemoveCondition(attacker, TFCond_BlastJumping);   // Prevent HHH from being market gardened more than once in midair during a teleport
                            // }

                            new Float:flHaleHealthMax = float(HaleHealthMax);
                            damage = (Pow(flHaleHealthMax*0.0015, 2.0) + 650.0 - (g_flMarketed/128.0*flHaleHealthMax))/3.0;    //divide by 3 because this is basedamage and lolcrits
                            damagetype |= DMG_CRIT;

                            if (RemoveCond(attacker, TFCond_Parachute))   // If you parachuted to do this, remove your parachute.
                            {
                                damage *= 0.67;                       //  And nerf your damage
                            }

                            if (g_flMarketed < 5.0)
                            {
                                g_flMarketed++;
                            }

                            PriorityCenterText(attacker, true, "You market gardened him!");
                            PriorityCenterText(client, true, "You were just market gardened!");

                            EmitSoundToAll("player/doubledonk.wav", attacker);

                            return Plugin_Changed;
                        }
                    }
                    case 317: SpawnSmallHealthPackAt(client, GetEntityTeamNum(attacker));
                    case 214: // Powerjack
                    {
                        AddPlayerHealth(attacker, 25, 50);
                        RemoveCond(attacker, TFCond_OnFire);
                        return Plugin_Changed;
                    }
                    case 594: // Phlog
                    {
                        if (!TF2_IsPlayerInCondition(attacker, TFCond_CritMmmph))
                        {
                            damage /= 2.0;
                            return Plugin_Changed;
                        }
                    }
                    case 357:
                    {
                        SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
                        if (GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy") < 1)
                            SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy", 1);

                        AddPlayerHealth(attacker, 35, 25);
                        RemoveCond(attacker, TFCond_OnFire);
                    }
                    case 61, 1006:  //Ambassador does 2.5x damage on headshot
                    {
                        if (damagecustom == TF_CUSTOM_HEADSHOT)
                        {
                            damage = 85.0;
                            return Plugin_Changed;
                        }
                    }
                    case 525, 595:
                    {
                        new iCrits = GetEntProp(attacker, Prop_Send, "m_iRevengeCrits");

                        if (iCrits > 0) //If a revenge crit was used, give a damage bonus
                        {
                            damage = 66.6667;
                            return Plugin_Changed;
                        }
                    }
                    /*case 528:
                    {
                        if (circuitStun > 0.0)
                        {
                            TF2_StunPlayer(client, circuitStun, 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
                            EmitSoundToAll("weapons/barret_arm_zap.wav", client);
                            EmitSoundToClient(client, "weapons/barret_arm_zap.wav");
                        }
                    }*/
                    case 656: // Mittens
                    {
                        CreateTimer(0.1, Timer_StopTickle, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
                        RemoveCond(attacker, TFCond_Dazed);
                    }
                }
                //VoiDeD's Caber-backstab code. To be added with a few special modifications in 1.40+
                //Except maybe not because it's semi op.
/*              if ( IsValidEdict( weapon ) && GetEdictClassname( weapon, wepclassname, sizeof( wepclassname ) ) && strcmp( wepclassname, "tf_weapon_stickbomb", false ) == 0 )
                {
                    // make caber do backstab damage on explosion

                    new bool:isDetonated = GetEntProp( weapon, Prop_Send, "m_iDetonated" ) == 1;

                    if ( !isDetonated )
                    {
                        new Float:changedamage = HaleHealthMax * 0.07;

                        Damage[attacker] += RoundFloat(changedamage);

                        damage = changedamage;

                        HaleHealth -= RoundFloat(changedamage);
                        HaleRage += RoundFloat(changedamage);

                        if (HaleRage > RageDMG)
                            HaleRage = RageDMG;
                    }
                }*/
                /*static bool:foundDmgCustom = false;  // This relic is probably no longer needed at all
                static bool:dmgCustomInOTD = false;
                if (!foundDmgCustom)
                {
                    dmgCustomInOTD = (GetFeatureStatus(FeatureType_Capability, "SDKHook_DmgCustomInOTD") == FeatureStatus_Available);
                    foundDmgCustom = true;
                }
                new bool:bIsBackstab = false;
                if (dmgCustomInOTD) // new way to check backstabs
                {
                    if (damagecustom == TF_CUSTOM_BACKSTAB)
                    {
                        bIsBackstab = true;
                    }
                }
                else if (weapon != 4095 && IsValidEdict(weapon) && weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee) && damage > 1000.0)  //lousy way of checking backstabs
                {
                    decl String:wepclassname[32];
                    if (GetEdictClassname(weapon, wepclassname, sizeof(wepclassname)) && strcmp(wepclassname, "tf_weapon_knife", false) == 0)   //more robust knife check
                    {
                        bIsBackstab = true;
                    }
                }*/
                if (damagecustom == TF_CUSTOM_BACKSTAB)
                {
                    /*
                     Rebalanced backstab formula.
                     By: Chdata

                     Stronger against low HP Hale.
                     Weaker against high HP Hale (but still good).

                    */
                    new Float:flHaleHealthMax = float(HaleHealthMax);
                    damage = ( (Pow(flHaleHealthMax*0.0014, 2.0) + 899.0) - (flHaleHealthMax*g_flStabbed/100.0) )/3.0; // You can level "damage dealt" with backstabs
          
                    damagetype |= DMG_CRIT|DMG_PREVENT_PHYSICS_FORCE;

                    EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 0.7, 100, _, vPos, NULL_VECTOR, false, 0.0);
                    EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 0.7, 100, _, vPos, NULL_VECTOR, false, 0.0);
                    EmitSoundToClient(client, "player/crit_received3.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 0.7, 100, _, _, NULL_VECTOR, false, 0.0);
                    EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 0.7, 100, _, _, NULL_VECTOR, false, 0.0);
                    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
                    SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime() + 2.0);
                    SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + 2.0);
                    new vm = GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
                    if (vm > MaxClients && IsValidEntity(vm) && TF2_GetPlayerClass(attacker) == TFClass_Spy)
                    {
                        new melee = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
                        new anim = 15;
                        switch (melee)
                        {
                            case 727: anim = 41;
                            case 4, 194, 665, 794, 803, 883, 892, 901, 910: anim = 10;
                            case 638: anim = 31;
                        }
                        SetEntProp(vm, Prop_Send, "m_nSequence", anim);
                    }
                    PriorityCenterText(attacker, true, "You backstabbed him!");
                    PriorityCenterText(client, true, "You were just backstabbed!");

                    new pistol = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary);

                    if (pistol == 525) //Diamondback gives 2 crits on backstab
                    {
                        new iCrits = GetEntProp(attacker, Prop_Send, "m_iRevengeCrits");
                        SetEntProp(attacker, Prop_Send, "m_iRevengeCrits", iCrits+2);
                    }

                    /*if (wepindex == 225 || wepindex == 574)
                    {
                        CreateTimer(0.3, Timer_DisguiseBackstab, GetClientUserId(attacker));
                    }*/

                    if (wepindex == 356) // Kunai
                    {
                        AddPlayerHealth(attacker, 180, 270, true);
                    }
                    if (wepindex == 461) // Big Earner gives full cloak on backstab and speed boost for 3 seconds
                    {
                        SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);
                        TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.0);
                    }
                    decl String:s[PLATFORM_MAX_PATH];
                    switch (Special)
                    {
                        case VSHSpecial_Hale:
                        {
                            Format(s, PLATFORM_MAX_PATH, "%s%i.wav", HaleStubbed132, GetRandomInt(1, 4));
                            EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        }
                        case VSHSpecial_Vagineer:
                        {
                            EmitSoundToAll("vo/engineer_positivevocalization01.mp3", _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, "vo/engineer_positivevocalization01.mp3", _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        }
                        case VSHSpecial_HHH:
                        {
                            Format(s, PLATFORM_MAX_PATH, "vo/halloween_boss/knight_pain0%d.mp3", GetRandomInt(1, 3));
                            EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        }
#if defined EASTER_BUNNY_ON
                        case VSHSpecial_Bunny:
                        {
                            strcopy(s, PLATFORM_MAX_PATH, BunnyPain[GetRandomInt(0, sizeof(BunnyPain)-1)]);
                            EmitSoundToAll(s, _, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                            EmitSoundToAllExcept(SOUNDEXCEPT_VOICE, s, _, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Hale, NULL_VECTOR, NULL_VECTOR, false, 0.0);
                        }
#endif
                    }
                    if (g_flStabbed < 4.0)
                        g_flStabbed++;
                    /*new healers[TF_MAX_PLAYERS]; // Medic assist unnecessary due to being handled in player_hurt now.
                    new healercount = 0;
                    for (new i = 1; i <= MaxClients; i++)
                    {
                        if (IsClientInGame(i) && IsPlayerAlive(i) && (GetHealingTarget(i) == attacker))
                        {
                            healers[healercount] = i;
                            healercount++;
                        }
                    }
                    for (new i = 0; i < healercount; i++)
                    {
                        if (IsValidClient(healers[i]) && IsPlayerAlive(healers[i]))
                        {
                            if (uberTarget[healers[i]] == attacker)
                                Damage[healers[i]] += iChangeDamage;
                            else
                                Damage[healers[i]] += RoundFloat(changedamage/(healercount+1));
                        }
                    }*/
                    return Plugin_Changed;
                }

                if (bChanged)
                {
                    return Plugin_Changed;
                }
            }
            if (TF2_GetPlayerClass(attacker) == TFClass_Scout)
            {
                if (wepindex == 45 || ((wepindex == 209 || wepindex == 294 || wepindex == 23 || wepindex == 160 || wepindex == 449) && (TF2_IsPlayerCritBuffed(client) || TF2_IsPlayerInCondition(client, TFCond_CritCola) || TF2_IsPlayerInCondition(client, TFCond_Buffed) || TF2_IsPlayerInCondition(client, TFCond_CritHype))))
                {
                    ScaleVector(damageForce, 0.38);
                    return Plugin_Changed;
                }
            }
        }
        else
        {
            decl String:s[64];
            if (GetEdictClassname(attacker, s, sizeof(s)) && strcmp(s, "trigger_hurt", false) == 0) // && damage >= 250)
            {
                if (bSpawnTeleOnTriggerHurt)
                {
                    // Teleport the boss back to one of the spawns.
                    // And during the first 30 seconds, he can only teleport to his own spawn.
                    //TeleportToSpawn(Hale, (bTenSecStart[1]) ? HaleTeam : 0);
                    TeleportToMultiMapSpawn(Hale, (!IsNextTime(e_flNextAllowOtherSpawnTele)) ? HaleTeam : 0);
                }
                else if (damage >= 250.0)
                {
                    if (Special == VSHSpecial_HHH)
                    {
                        //TeleportToSpawn(Hale, (!IsNextTime(e_flNextAllowOtherSpawnTele)) ? HaleTeam : 0);
                        TeleportToMultiMapSpawn(Hale, (!IsNextTime(e_flNextAllowOtherSpawnTele)) ? HaleTeam : 0);
                    }
                    else if (HaleCharge >= 0)
                    {
                        bEnableSuperDuperJump = true;
                    }
                }

                new Float:flMaxDmg = float(HaleHealthMax) * 0.05;
                if (flMaxDmg > 500.0)
                {
                    flMaxDmg = 500.0;
                }

                if (damage > flMaxDmg)
                {
                    damage = flMaxDmg;
                }
                HaleHealth -= RoundFloat(damage);
                HaleRage += RoundFloat(damage);
                if (HaleHealth <= 0) damage *= 5;
                if (HaleRage > RageDMG)
                    HaleRage = RageDMG;
                return Plugin_Changed;
            }
        }
    }
    else if (attacker == 0 && client != Hale && IsValidClient(client) && (damagetype & DMG_FALL) && (TF2_GetPlayerClass(client) == TFClass_Soldier || TF2_GetPlayerClass(client) == TFClass_DemoMan)) // IsValidClient(client, false)
    {
        new item = GetPlayerWeaponSlot(client, (TF2_GetPlayerClass(client) == TFClass_DemoMan ? TFWeaponSlot_Primary:TFWeaponSlot_Secondary));

        if (item <= 0 || !IsValidEntity(item))
        {
            damage /= 10.0;

            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

/*
 Teleports a client to a random spawn location
 By: Chdata

 iClient - Client to teleport
 iTeam - Team of spawn points to use. If not specified or invalid team number, teleport to ANY spawn point.

 TODO: Make it not HHH specific

*/
/*stock TeleportToSpawn(iClient, iTeam = 0)
{
    new iEnt = -1;
    decl Float:vPos[3];
    decl Float:vAng[3];
    new Handle:hArray = CreateArray();
    while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
    {
        if (iTeam <= 1) // Not RED (2) nor BLu (3)
        {
            PushArrayCell(hArray, iEnt);
        }
        else
        {
            new iSpawnTeam = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
            if (iSpawnTeam == iTeam)
            {
                PushArrayCell(hArray, iEnt);
            }
        }
    }

    iEnt = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray) - 1));
    CloseHandle(hArray);

    // Technically you'll never find a map without a spawn point. Not a good map at least.
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
    GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);
    TeleportEntity(iClient, vPos, vAng, NULL_VECTOR);

    if (Special == VSHSpecial_HHH)
    {
        AttachParticle(i, "ghost_appearation", 3.0);
        EmitSoundToAll("misc/halloween/spell_teleport.wav", _, _, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, vPos, NULL_VECTOR, false, 0.0);
    }
}*/


SpawnSmallHealthPackAt(client, ownerteam = 0)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return; // IsValidClient(client, false)
    new healthpack = CreateEntityByName("item_healthkit_small");
    decl Float:pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] += 20.0;
    if (IsValidEntity(healthpack))
    {
        DispatchKeyValue(healthpack, "OnPlayerTouch", "!self,Kill,,0,-1");  //for safety, though it normally doesn't respawn
        DispatchSpawn(healthpack);
        SetEntProp(healthpack, Prop_Send, "m_iTeamNum", ownerteam, 4);
        SetEntityMoveType(healthpack, MOVETYPE_VPHYSICS);
        new Float:vel[3];
        vel[0] = float(GetRandomInt(-10, 10)), vel[1] = float(GetRandomInt(-10, 10)), vel[2] = 50.0;
        TeleportEntity(healthpack, pos, NULL_VECTOR, vel);
//      CreateTimer(17.0, Timer_RemoveCandycaneHealthPack, EntIndexToEntRef(healthpack), TIMER_FLAG_NO_MAPCHANGE);
    }
}
/*public Action:Timer_RemoveCandycaneHealthPack(Handle:timer, any:ref)
{
    new entity = EntRefToEntIndex(ref);
    if (entity > MaxClients && IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }
}*/
public Action:Timer_StopTickle(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
    if (!GetEntProp(client, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hHighFivePartner"))) TF2_RemoveCondition(client, TFCond_Taunting);
}
public Action:Timer_CheckBuffRage(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsPlayerAlive(client))
    {
        SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
    }
}

/*public Action:Timer_DisguiseBackstab(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsPlayerAlive(client)) // IsValidClient(client, false)
    {
        RandomlyDisguise(client);
    }
}
stock RandomlyDisguise(client)  //original code was mecha's, but the original code is broken and this uses a better method now.
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
//      TF2_AddCondition(client, TFCond_Disguised, 99999.0);
        new disguisetarget = -1;
        new team = GetEntityTeamNum(client);
        new Handle:hArray = CreateArray();
        for (new clientcheck = 0; clientcheck <= MaxClients; clientcheck++)
        {
            if (IsValidClient(clientcheck) && GetEntityTeamNum(clientcheck) == team && clientcheck != client)
            {
//              new TFClassType:class = TF2_GetPlayerClass(clientcheck);
//              if (class == TFClass_Scout || class == TFClass_Medic || class == TFClass_Engineer || class == TFClass_Sniper || class == TFClass_Pyro)
                PushArrayCell(hArray, clientcheck);
            }
        }
        if (GetArraySize(hArray) <= 0) disguisetarget = client;
        else disguisetarget = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray)-1));
        if (!IsValidClient(disguisetarget)) disguisetarget = client;
//      new disguisehealth = GetRandomInt(75, 125);
        new class = GetRandomInt(0, 4);
        new TFClassType:classarray[] = { TFClass_Scout, TFClass_Pyro, TFClass_Medic, TFClass_Engineer, TFClass_Sniper };
//      new disguiseclass = classarray[class];
//      new disguiseclass = _:(disguisetarget != client ? (TF2_GetPlayerClass(disguisetarget)) : classarray[class]);
//      new weapon = GetEntPropEnt(disguisetarget, Prop_Send, "m_hActiveWeapon");
        CloseHandle(hArray);
        if (TF2_GetPlayerClass(client) == TFClass_Spy) TF2_DisguisePlayer(client, TFTeam:team, classarray[class], disguisetarget);
        else
        {
            TF2_AddCondition(client, TFCond_Disguised, -1.0);
            SetEntProp(client, Prop_Send, "m_nDisguiseTeam", team);
            SetEntProp(client, Prop_Send, "m_nDisguiseClass", classarray[class]);
            SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", disguisetarget);
            SetEntProp(client, Prop_Send, "m_iDisguiseHealth", 200);
        }
    }
}*/
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
    if (!IsValidClient(client) || !g_bEnabled) return Plugin_Continue; // IsValidClient(client, false)

    // HHH can climb walls
    if (IsValidEntity(weapon) && Special == VSHSpecial_HHH && client == Hale && HHHClimbCount <= 9 && VSHRoundState > VSHRState_Waiting)
    {
        new index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

        if (index == 266 && StrEqual(weaponname, "tf_weapon_sword", false))
        {
            SickleClimbWalls(client, weapon);
            WeighDownTimer = 0.0;
            HHHClimbCount++;
        }
    }

    if (client == Hale)
    {
        if (VSHRoundState != VSHRState_Active) return Plugin_Continue;
        if (TF2_IsPlayerCritBuffed(client)) return Plugin_Continue;
        if (!haleCrits)
        {
            result = false;
            return Plugin_Changed;
        }
    }
    else if (IsValidEntity(weapon))
    {
        if (TF2_GetPlayerClass(client) == TFClass_Sniper && IsWeaponSlotActive(client, TFWeaponSlot_Melee)) // index == 232 && StrEqual(weaponname, "tf_weapon_club", false)
        {
            SickleClimbWalls(client, weapon);
        }
    }
    return Plugin_Continue;
}

SickleClimbWalls(client, weapon)     //Credit to Mecha the Slag
{
    if (!IsValidClient(client) || (GetClientHealth(client)<=15) )return;

    decl String:classname[64];
    decl Float:vecClientEyePos[3];
    decl Float:vecClientEyeAng[3];
    GetClientEyePosition(client, vecClientEyePos);   // Get the position of the player's eyes
    GetClientEyeAngles(client, vecClientEyeAng);       // Get the angle the player is looking

    //Check for colliding entities
    TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);

    if (!TR_DidHit(INVALID_HANDLE)) return;

    new TRIndex = TR_GetEntityIndex(INVALID_HANDLE);
    GetEdictClassname(TRIndex, classname, sizeof(classname));

    if (!((StrStarts(classname, "prop_") && classname[5] != 'p') || StrEqual(classname, "worldspawn")))
    {
        return;
    }

    decl Float:fNormal[3];
    TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
    GetVectorAngles(fNormal, fNormal);

    if (fNormal[0] >= 30.0 && fNormal[0] <= 330.0) return;
    if (fNormal[0] <= -30.0) return;

    decl Float:pos[3];
    TR_GetEndPosition(pos);
    new Float:distance = GetVectorDistance(vecClientEyePos, pos);

    if (distance >= 100.0) return;

    new Float:fVelocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

    fVelocity[2] = 600.0;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);

    SDKHooks_TakeDamage(client, client, client, 15.0, DMG_CLUB, 0);

    if (client != Hale)
    {
        ClientCommand(client, "playgamesound \"%s\"", "player\\taunt_clip_spin.wav");
        RequestFrame(Timer_NoAttacking, EntIndexToEntRef(weapon));
    }
}

public Timer_NoAttacking(any:ref)
{
    new weapon = EntRefToEntIndex(ref);
    if (weapon != -1)
    {
        SetNextAttack(weapon, 1.56);
    }
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
    return (entity != data);
}

FindNextHale(bool:array[])
{
    new tBoss = -1;
    new tBossPoints = -1073741824;
    //new bool:spec = GetConVarBool(cvarForceSpecToHale);
    for (new i = 1; i <= MaxClients; i++)
    {
        //if (IsClientInGame(i) && (GetEntityTeamNum(i) > _:TFTeam_Spectator || (spec && GetEntityTeamNum(i) != _:TFTeam_Unassigned)))   // GetEntityTeamNum(i) != _:TFTeam_Unassigned)
        if (IsClientInGame(i) && IsClientParticipating(i))
        {
            new points = GetClientQueuePoints(i);
            if (points >= tBossPoints && !array[i])
            {
                tBoss = i;
                tBossPoints = points;
            }
        }
    }
    return tBoss;
}
FindNextHaleEx()
{
    new bool:added[TF_MAX_PLAYERS];
    if (Hale >= 0) added[Hale] = true;
    return FindNextHale(added);
}
ForceTeamWin(team)
{
    new ent = FindEntityByClassname2(-1, "team_control_point_master");
    if (ent == -1)
    {
        ent = CreateEntityByName("team_control_point_master");
        DispatchSpawn(ent);
        AcceptEntityInput(ent, "Enable");
    }
    SetVariantInt(team);
    AcceptEntityInput(ent, "SetWinner");
}

public HintPanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (!IsValidClient(param1)) return;
    if (action == MenuAction_Select || (action == MenuAction_Cancel && param2 == MenuCancel_Exit)) VSHFlags[param1] |= VSHFLAG_CLASSHELPED;
    return;
}

public Action:HintPanel(client)
{
    if (IsVoteInProgress())
        return Plugin_Continue;
    new Handle:panel = CreatePanel();
    decl String:s[512];
    SetGlobalTransTarget(client);
    switch (Special)
    {
        case VSHSpecial_Hale:
            Format(s, 512, "%t", "vsh_help_hale");
        case VSHSpecial_Vagineer:
            Format(s, 512, "%t", "vsh_help_vagineer");
        case VSHSpecial_HHH:
            Format(s, 512, "%t", "vsh_help_hhh");
        case VSHSpecial_CBS:
            Format(s, 512, "%t", "vsh_help_cbs");
        case VSHSpecial_Bunny:
            Format(s, 512, "%t", "vsh_help_bunny");
    }
    DrawPanelText(panel, s);
    Format(s, 512, "%t", "vsh_menu_exit");
    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, HintPanelH, 9001);
    CloseHandle(panel);
    return Plugin_Continue;
}
public QueuePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select && param2 == 10)
        TurnToZeroPanel(param1);
    return false;
}
public Action:QueuePanelCmd(client, Args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    QueuePanel(client);
    return Plugin_Handled;
}
public Action:QueuePanel(client)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Handled;
    new Handle:panel = CreatePanel();
    decl String:s[512];
    Format(s, 512, "%T", "vsh_thequeue", client);
    SetPanelTitle(panel, s);
    new bool:added[TF_MAX_PLAYERS];
    new tHale = Hale;
    if (Hale >= 0) added[Hale] = true;
    if (!g_bEnabled) DrawPanelItem(panel, "None");
    else if (IsValidClient(tHale))
    {
        Format(s, sizeof(s), "%N - %i", tHale, GetClientQueuePoints(tHale));
        DrawPanelItem(panel, s);
    }
    else DrawPanelItem(panel, "None");
    new i, pingas, bool:botadded;
    DrawPanelText(panel, "---");
    do
    {
        tHale = FindNextHale(added);
        if (IsValidClient(tHale))
        {
            if (client == tHale)
            {
                Format(s, 64, "%N - %i", tHale, GetClientQueuePoints(tHale));
                DrawPanelText(panel, s);
                i--;
            }
            else
            {
                if (IsFakeClient(tHale))
                {
                    if (botadded)
                    {
                        added[tHale] = true;
                        continue;
                    }
                    Format(s, 64, "BOT - %i", botqueuepoints);
                    botadded = true;
                }
                else Format(s, 64, "%N - %i", tHale, GetClientQueuePoints(tHale));
                DrawPanelItem(panel, s);
            }
            added[tHale]=true;
            i++;
        }
        pingas++;
    }
    while (i < 8 && pingas < 100);
    for (; i < 8; i++)
        DrawPanelItem(panel, "");
    Format(s, 64, "%T %i (%T)", "vsh_your_points", client, GetClientQueuePoints(client), "vsh_to0", client);
    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, QueuePanelH, 9001);
    CloseHandle(panel);
    return Plugin_Handled;
}
public TurnToZeroPanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select && param2 == 1)
    {
        SetClientQueuePoints(param1, 0);
        CPrintToChat(param1, "{olive}[VSH]{default} %t", "vsh_to0_done");
        new cl = FindNextHaleEx();
        if (IsValidClient(cl)) SkipHalePanelNotify(cl);
    }
}
public Action:ResetQueuePointsCmd(client, args)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Handled;
    if (!IsValidClient(client))
        return Plugin_Handled;
    if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
        TurnToZeroPanel(client);
    else
        TurnToZeroPanelH(INVALID_HANDLE, MenuAction_Select, client, 1);
    return Plugin_Handled;
}
public Action:TurnToZeroPanel(client)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;
    new Handle:panel = CreatePanel();
    decl String:s[512];
    SetGlobalTransTarget(client);
    Format(s, 512, "%t", "vsh_to0_title");
    SetPanelTitle(panel, s);
    Format(s, 512, "%t", "Yes");
    DrawPanelItem(panel, s);
    Format(s, 512, "%t", "No");
    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, TurnToZeroPanelH, 9001);
    CloseHandle(panel);
    return Plugin_Continue;
}
bool:GetClientClasshelpinfoCookie(client)
{
    if (!IsValidClient(client)) return false;
    if (IsFakeClient(client)) return false;
    if (!AreClientCookiesCached(client)) return true;
    decl String:strCookie[MAX_DIGITS];
    GetClientCookie(client, ClasshelpinfoCookie, strCookie, sizeof(strCookie));
    if (strCookie[0] == 0) return true;
    else return bool:StringToInt(strCookie);
}
GetClientQueuePoints(client)
{
    if (!IsValidClient(client)) return 0;
    if (IsFakeClient(client))
    {
        return botqueuepoints;
    }
    if (!AreClientCookiesCached(client)) return 0;
    decl String:strPoints[MAX_DIGITS];
    GetClientCookie(client, PointCookie, strPoints, sizeof(strPoints));
    return StringToInt(strPoints);
}
SetClientQueuePoints(client, points)
{
    if (!IsValidClient(client)) return;
    if (IsFakeClient(client)) return;
    if (!AreClientCookiesCached(client)) return;
    decl String:strPoints[MAX_DIGITS];
    IntToString(points, strPoints, sizeof(strPoints));
    SetClientCookie(client, PointCookie, strPoints);
}
SetAuthIdQueuePoints(String:authid[], points)
{
    decl String:strPoints[MAX_DIGITS];
    IntToString(points, strPoints, sizeof(strPoints));
    SetAuthIdCookie(authid, PointCookie, strPoints);
}
public HalePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 1:
                Command_GetHP(param1);
            case 2:
                HelpPanel(param1);
            case 3:
                HelpPanel2(param1);
            case 4:
                NewPanel(param1, maxversion);
            case 5:
                QueuePanel(param1);
            case 6:
                MusicTogglePanel(param1);
            case 7:
                VoiceTogglePanel(param1);
            case 8:
                ClasshelpinfoSetting(param1);
/*          case 9:
            {
                if (ACH_Enabled)
                    FakeClientCommandEx(param1, "haleach");
                else
                    return;
            }
            case 0:
            {
                if (ACH_Enabled)
                    FakeClientCommandEx(param1, "haleach_stats");
                else
                    return;
            }*/
            default: return;
        }
    }
}

public Action:HalePanel(client, args)
{
    if (!g_bAreEnoughPlayersPlaying || !client) // IsValidClient(client, false)
        return Plugin_Continue;
    new Handle:panel = CreatePanel();
    new size = 256;
    decl String:s[size];
    SetGlobalTransTarget(client);
    Format(s, size, "%t", "vsh_menu_1");
    SetPanelTitle(panel, s);
    Format(s, size, "%t", "vsh_menu_2");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_3");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_7");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_4");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_5");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_8");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_9");
    DrawPanelItem(panel, s);
    Format(s, size, "%t", "vsh_menu_9a");
    DrawPanelItem(panel, s);
/*  if (ACH_Enabled)
    {
        Format(s, size, "%t", "vsh_menu_10");
        DrawPanelItem(panel, s);
        Format(s, size, "%t", "vsh_menu_11");
        DrawPanelItem(panel, s);
    }*/
    Format(s, size, "%t", "vsh_menu_exit");
    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, HalePanelH, 9001);
    CloseHandle(panel);
    return Plugin_Handled;
}
public NewPanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 1:
            {
                if (curHelp[param1] <= 0)
                    NewPanel(param1, 0);
                else
                    NewPanel(param1, --curHelp[param1]);
            }
            case 2:
            {
                if (curHelp[param1] >= maxversion)
                    NewPanel(param1, maxversion);
                else
                    NewPanel(param1, ++curHelp[param1]);
            }
            default: return;
        }
    }
}
public Action:NewPanelCmd(client, args)
{
    if (!client) return Plugin_Handled;
    NewPanel(client, maxversion);
    return Plugin_Handled;
}
public Action:NewPanel(client, versionindex)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;
    curHelp[client] = versionindex;
    new Handle:panel = CreatePanel();
    decl String:s[90];
    SetGlobalTransTarget(client);
    Format(s, 90, "=%t%s:=", "vsh_whatsnew", haleversiontitles[versionindex]);
    SetPanelTitle(panel, s);
    FindVersionData(panel, versionindex);

    if (versionindex > 0)
    {
        if (strcmp(haleversiontitles[versionindex], haleversiontitles[versionindex-1], false) == 0)
        {
            Format(s, 90, "Next Page");
        }
        else
        {
            Format(s, 90, "Older v%s", haleversiontitles[versionindex-1]); 
        }
        DrawPanelItem(panel, s);
    }
    else
    {
        Format(s, 90, "%t", "vsh_noolder");
        DrawPanelItem(panel, s, ITEMDRAW_DISABLED);
    }

    if (versionindex < maxversion)
    {
        if (strcmp(haleversiontitles[versionindex], haleversiontitles[versionindex+1], false) == 0)
        {
            Format(s, 90, "Prev Page");
        }
        else
        {
            Format(s, 90, "Newer v%s", haleversiontitles[versionindex+1]);
        }
        DrawPanelItem(panel, s);
    }
    else
    {
        Format(s, 90, "%t", "vsh_nonewer");
        DrawPanelItem(panel, s, ITEMDRAW_DISABLED);
    }
    
    Format(s, 512, "%t", "vsh_menu_exit");
    DrawPanelItem(panel, s);

    SendPanelToClient(panel, client, NewPanelH, 9001);
    CloseHandle(panel);
    return Plugin_Continue;
}
FindVersionData(Handle:panel, versionindex)
{
    switch (versionindex) // DrawPanelText(panel, "1) .");
    {
        case 75: // 1.55
        {
            DrawPanelText(panel, "1) Updated Saxton Hale's model to an HD version made by thePFA");
            DrawPanelText(panel, "2) Vagineer can be properly headshotted now!");
            DrawPanelText(panel, "3) Scorch Shot's Mega Detonator gets Scorch Shot attributes instead of Detonation.");
        }
        case 74: // 1.54
        {
            DrawPanelText(panel, "1) Soldier shotgun: 40% reduced self blast damage.");
            DrawPanelText(panel, "2) Rocket jumper now becomes a reskinned default rocket launcher that deals damage like normal.");
            DrawPanelText(panel, "3) Removed quick-fix attribute from mediguns. .");
            DrawPanelText(panel, "4) Scorch shot now acts like Mega-Detonator.");
            DrawPanelText(panel, "5) Pain Train now acts like a stock weapon.");
            DrawPanelText(panel, "7) HHH Climb no longer slowers attack speed.");
        }
        case 73: // 1.54
        {
            DrawPanelText(panel, "8) Diamondback revenge crits on stab reduced from 3 -> 2.");
            DrawPanelText(panel, "9) Diamondback revenge hits deal 200 dmg instead of 255.");
            DrawPanelText(panel, "10) Market garden formula now scales the same as backstabs - but does less than backstabs.");
            DrawPanelText(panel, "11) Fixed negative HaleHealth glitch, and 20k+ backstab glitch.");
            DrawPanelText(panel, "12) Fixed boss melee weapons on CBS/Vagineer/HHH not showing attack animations in first person.");
        }
        case 72: // 1.54
        {
            DrawPanelText(panel, "13) Integrated goomba stomp and RTD for server owners to use.");
        }
        case 71: // 1.53
        { 
            DrawPanelText(panel, "1) Undid 1.7 syntax. (Chdata)");
            DrawPanelText(panel, "2) Shahanshah: 1.66x dmg if <50% hp, 0.5x dmg if >50% hp.");
            DrawPanelText(panel, "3) Big Earner provides 3 second speed boost on stab.");
            DrawPanelText(panel, "4) Shortstop provides passive effects even when not active.");
            DrawPanelText(panel, "5) Reverted gunmettle changes to deadringer and watch.");
            DrawPanelText(panel, "6) Watches do not give speed boosts on cloak.");
        }
        case 70: // 1.53
        {
            DrawPanelText(panel, "7) Deadringer reduces melee damage to 62, and normal watch to 85.");
            DrawPanelText(panel, "8) OVERRIDE_MEDIGUNS_ON is now on by default. Mediguns will simply have their stats replaced instead of a custom medigun replacement.");
            DrawPanelText(panel, "9) Gunmettle weapons act like their non-skinned counter-parts.");
            DrawPanelText(panel, "10) Natascha will no longer keep its bonus ammo when being replaced.");
            DrawPanelText(panel, "11) Unnerfed the Easter Bunny's rage.");
            DrawPanelText(panel, "12) Disabled dropped weapons during VSH rounds.");
        }
        case 69: //1.52
        {
            DrawPanelText(panel, "1) Added the new festive/other weapons!");
            DrawPanelText(panel, "2) Check out v1.51 because we skipped a version!");
            DrawPanelText(panel, "3) Maps without health/ammo now randomly spawn some in spawn");
        }
        case 68: //1.51
        {
            DrawPanelText(panel, "1) Boss became Hale HUD no longer overlaps final score HUD.");
            DrawPanelText(panel, "2) Must touch ground again after market gardening (Can no longer screw HHH over).");
            DrawPanelText(panel, "3) Parachuting reduces market garden dmg by 33% and disables your parachute.");
        }
        case 67: // 1.50
        {
            DrawPanelText(panel, "1) Removed gamedata dependency.");
            DrawPanelText(panel, "2) Optimized some code.");
            DrawPanelText(panel, "3) Reserve shooter no longer Thriller taunts.");
            DrawPanelText(panel, "4) Fixed mantreads not giving increased jump height.");
            // Should be in sync with github now
            // Fixed SM1.7 compiler warning
            // FlaminSarge's timer/requestframe changes
            // Removed require_plugin around tryincluding tf2attributes
            // Changed RemoveWeaponSlot2 to RemoveWeaponSlot
        }
        case 66: //1.49
        {
            DrawPanelText(panel, "1) Updated again for the latest version of sourcemod (1.6.1 or higher)");
            DrawPanelText(panel, "2) Hopefully botkillers are fixed now?");
            DrawPanelText(panel, "3) Fixed wrong number of players displaying when control point is enabled.");
            DrawPanelText(panel, "4) Fixed festive GRU's stats and festive/bread jarate not removing rage.");
            DrawPanelText(panel, "5) Fixed issues with HHH teleporting to spawn.");
            DrawPanelText(panel, "6) Added configs/saxton_spawn_teleport.cfg");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 65: //1.48
        {
            DrawPanelText(panel, "1) Can call medic to rage.");
            DrawPanelText(panel, "2) Harder to double tap taunt and fail rage.");
            DrawPanelText(panel, "3) Cannot spam super duper jump as much when falling into pits.");
            DrawPanelText(panel, "4) Hale only takes 5% of his max health as damage while in pits, at a max of 500.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 64: //1.48
        {
            DrawPanelText(panel, "5) Blocked boss from using voice commands unless he's CBS or Bunny");
            DrawPanelText(panel, "6) HHH always teleports to spawn after falling off the map.");
            DrawPanelText(panel, "7) HHH takes 50 seconds to get his first teleport instead of 25.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 63: //1.47
        {
            DrawPanelText(panel, "1) Updated for the latest version of sourcemod (1.6.1)");
            DrawPanelText(panel, "2) Fixed final player disconnect not giving the remaining players mini/crits.");
            DrawPanelText(panel, "3) Fixed cap not starting enabled when the round starts with low enough players to enable it.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 62: //1.47
        {
            DrawPanelText(panel, "5) !haleclass as Hale now shows boss info instead of class info.");
            DrawPanelText(panel, "6) Fixed Hale's anchor to work against sentries. Crouch walking negates all knockback.");
            DrawPanelText(panel, "7) Being cloaked next to a dispenser now drains your cloak to prevent camping.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 61: //1.46
        {
            DrawPanelText(panel, "1) Fixed botkillers (thanks rswallen).");
            DrawPanelText(panel, "2) Fixed Tide Turner & Razorback not being unequipped/removed properly.");
            DrawPanelText(panel, "3) Hale can no longer pick up health packs.");
            DrawPanelText(panel, "4) Fixed maps like military area where BLU can't pick up ammo packs in the first arena round.");
            DrawPanelText(panel, "5) Fixed unbalanced team joining in the first arena round.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 60: //1.46
        {
            DrawPanelText(panel, "6) Can now type !resetq to reset your queue points.");
            DrawPanelText(panel, "7) !infotoggle can disable the !haleclass info popups on round start.");
            DrawPanelText(panel, "8) Easter Bunny has 40pct knockback resist in light of the crit eggs.");
            DrawPanelText(panel, "9) Phlog damage reduced by half when not under the effects of CritMmmph.");
            DrawPanelText(panel, "10) Quiet decloak moved from Letranger to Your Eternal Reward / Wanga Prick.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 59: //1.46
        {
            DrawPanelText(panel, "11) YER no longer disguises you.");
            DrawPanelText(panel, "12) Changed /halenew pagination a little.");
            DrawPanelText(panel, "13) Nerfed demo shield crits to minicrits. He was overpowered compared to other classes.");
            DrawPanelText(panel, "14) Added Cvar 'hale_shield_crits' to re-enable shield crits for servers balanced around taunt crits/goomba.");
            DrawPanelText(panel, "15) Added cvar 'hale_hp_display' to toggle displaying Hale's Health at all times on the hud.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 58: //1.45
        {
            DrawPanelText(panel, "1) Fixed equippable wearables (thanks fiagram & Powerlord).");
            DrawPanelText(panel, "2) Fixed flickering HUD text.");
            DrawPanelText(panel, "3) Implemented anti-suicide as Hale measures.");
            DrawPanelText(panel, "4) Hale cannot suicide until around 30 seconds have passed.");
            DrawPanelText(panel, "5) Hale can no longer switch teams to suicide.");
            DrawPanelText(panel, "6) Repositioned 'player became x boss' message off of your crosshair.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community."); // Blatant advertising
        }
        case 57: //1.45
        {
            DrawPanelText(panel, "7) Removed annoying no yes no no you're Hale next message.");
            DrawPanelText(panel, "8) Market Gardens do damage similar to backstabs.");
            DrawPanelText(panel, "9) Deadringer now displays its status.");
            DrawPanelText(panel, "10) Phlog is invulnerable during taunt activation.");
            DrawPanelText(panel, "11) Phlog Crit Mmmph duration has 75% damage resistance.");
            DrawPanelText(panel, "12) Phlog disables flaregun crits.");
            DrawPanelText(panel, "13) Fixed Bread Bite and Festive Eyelander.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 56: //1.45
        {
            DrawPanelText(panel, "14) Can now see uber meter with melee or syringe equipped.");
            DrawPanelText(panel, "15) Soda Popper & BFB replaced with scattergun.");
            DrawPanelText(panel, "16) Bonk replaced with crit-a-cola.");
            DrawPanelText(panel, "17) All 3 might be rebalanced in the future.");
            DrawPanelText(panel, "18) Reserve shooter crits in place of minicrits. Still 3 clip.");
            DrawPanelText(panel, "19) Re-enabled Darwin's Danger Shield. Overhealed sniper can tank a hit!");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 55: //1.45
        {
            DrawPanelText(panel, "20) Batt's Backup has 75% knockback resist.");
            DrawPanelText(panel, "21) Air Strike relaxed to 200 dmg per clip.");
            DrawPanelText(panel, "22) Fixed backstab rarely doing 1/3 damage glitch.");
            DrawPanelText(panel, "23) Big Earner gives full cloak on backstab.");
            DrawPanelText(panel, "24) Fixed SteamTools not changing gamedesc.");
            DrawPanelText(panel, "25) Reverted 3/5ths backstab assist for medics and fixed no assist glitch.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 54: //1.45
        {
            DrawPanelText(panel, "26) HHH can wallclimb.");
            DrawPanelText(panel, "27) HHH's weighdown timer is reset on wallclimb.");
            DrawPanelText(panel, "28) HHH now alerts their teleport target that he teleported to them.");
            DrawPanelText(panel, "29) HHH can get stuck in soldiers and scouts, but not other classes on teleport.");
            DrawPanelText(panel, "30) Can now charge super jump while holding space.");
            DrawPanelText(panel, "31) Nerfed Easter Bunny's rage eggs by 40% damage.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 53: //1.44
        {
            DrawPanelText(panel, "1) Fixed first round glich (thanks nergal).");
            DrawPanelText(panel, "2) Kunai starts at 65 HP instead of 60. Max 270 HP.");
            DrawPanelText(panel, "3) Kunai gives 180 HP on backstab instead of 100.");
            DrawPanelText(panel, "4) Demo boots now reduce fall damage like soldier boots and do stomp damage.");
            DrawPanelText(panel, "5) Fixed bushwacka disabling crits.");
            DrawPanelText(panel, "6) Air Strike gains ammo based on every 500 damage dealt.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 52: //1.44
        {
            DrawPanelText(panel, "7) Sydney Sleeper generates half the usual rage for Hale.");
            DrawPanelText(panel, "8) Other sniper rifles just do 3x damage as usual.");
            DrawPanelText(panel, "9) Huntsman gets 2x ammo, fortified compound fixed.");
            DrawPanelText(panel, "10) Festive flare gun now acts like mega-detonator.");
            DrawPanelText(panel, "11) Medic crossbow now gives 15pct uber instead of 10.");
            DrawPanelText(panel, "12) Festive crossbow is fixed to be like normal crossbow.");
            DrawPanelText(panel, "13) Medics now get 3/5 the damage of a backstab for assisting.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 51: //1.43
        {
            DrawPanelText(panel, "1) Backstab formula rebalanced to do better damage to lower HP Hales.");
            DrawPanelText(panel, "2) Damage Dealt now work properly with backstabs.");
            DrawPanelText(panel, "3) Slightly reworked Hale health formula.");
            DrawPanelText(panel, "4) (Anchor) Bosses take no pushback from damage while ducking on the ground.");
            DrawPanelText(panel, "5) Short circuit blocked until further notice.");
            DrawPanelText(panel, "--) This version courtesy of the TF2Data community.");
        }
        case 50: //1.43
        {
            DrawPanelText(panel, "6) Bushwacka blocks healing while in use.");
            DrawPanelText(panel, "7) Cannot wallclimb if your HP is low enough that it'll kill you.");
            DrawPanelText(panel, "8) Bushwacka doesn't disable crits.");
            DrawPanelText(panel, "9) 2013 festives and bread now get crits.");
            DrawPanelText(panel, "10) Fixed telefrag and mantread stomp damage.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 49: //1.43
        {
            DrawPanelText(panel, "11) L'etranger's 40% cloak is replaced with quiet decloak and -25% cloak regen rate.");
            DrawPanelText(panel, "12) Ambassador does 2.5x damage on headshots.");
            DrawPanelText(panel, "13) Diamondback gets 3 crits on backstab.");
            DrawPanelText(panel, "14) Diamondback crit shots do bonus damage similar to the Ambassador.");
            DrawPanelText(panel, "15) Manmelter always crits, while revenge crits do bonus damage.");
            DrawPanelText(panel, "---) This version courtesy of the TF2Data community.");
        }
        case 48: //142
        {
            DrawPanelText(panel, "1) Festive fixes");
            DrawPanelText(panel, "2) Hopefully fixed targes disappearing");
#if defined EASTER_BUNNY_ON
            DrawPanelText(panel, "3) Easter and April Fool's Day so close together... hmmm...");
#endif
        }
        case 47: //141
        {
            DrawPanelText(panel, "1) Fixed bosses disguising");
            DrawPanelText(panel, "2) Updated action slot whitelist");
            DrawPanelText(panel, "3) Updated sniper rifle list, Fest. Huntsman");
            DrawPanelText(panel, "4) Medigun speed works like Quick-Fix");
            DrawPanelText(panel, "5) Medigun+gunslinger vm fix");
            DrawPanelText(panel, "6) CBS gets Fest. Huntsman");
            DrawPanelText(panel, "7) Spies take more dmg while cloaked (normal watch)");
            DrawPanelText(panel, "8) Experimental backstab block animation");
        }
        case 46: //140
        {
            DrawPanelText(panel, "1) Dead Ringers have no cloak defense buff. Normal cloaks do.");
            DrawPanelText(panel, "2) Fixed Sniper Rifle reskin behavior");
            DrawPanelText(panel, "3) Boss has small amount of stun resistance after rage");
            DrawPanelText(panel, "4) Fixed HHH/CBS models");
        }
        case 45: //139c
        {
            DrawPanelText(panel, "1) Backstab disguising smoother/less obvious");
            DrawPanelText(panel, "2) Rage 'dings' dispenser/tele, to help locate Hale");
            DrawPanelText(panel, "3) Improved skip panel");
            DrawPanelText(panel, "4) Removed crits from sniper rifles, now do 2.9x damage");
            DrawPanelText(panel, "-- Sleeper does 2.4x damage, 2.9x if Hale's rage is >90pct");
            DrawPanelText(panel, "-- Bushwacka nerfs still apply");
            DrawPanelText(panel, "-- Minicrit- less damage, more knockback");
            DrawPanelText(panel, "5) Scaled sniper rifle glow time a bit better");
            DrawPanelText(panel, "6) Fixed Dead Ringer spy death icon");
        }
        case 44: //139c
        {
            DrawPanelText(panel, "7) BabyFaceBlaster will fill boost normally, but will hit 100 and drain+minicrits");
            DrawPanelText(panel, "8) Can't Eureka+destroy dispenser to insta-tele");
            DrawPanelText(panel, "9) Phlogger invuln during the taunt");
            DrawPanelText(panel, "10) Added !hale_resetq");
            DrawPanelText(panel, "11) Heatmaker gains Focus on hit (varies by charge)");
            DrawPanelText(panel, "12) Bosses get short defense buff after rage");
            DrawPanelText(panel, "13) Cozy Camper comes with SMG - 1.5s bleed, no random crit, -15% dmg");
            DrawPanelText(panel, "14) Valve buffed Crossbow. Balancing.");
            DrawPanelText(panel, "15) New cvars-hale_force_team, hale_enable_eureka");
        }
        case 43: //139c
        {
            DrawPanelText(panel, "16) Powerlord's Better Backstab Detection");
            DrawPanelText(panel, "17) Backburner has charged airblast");
            DrawPanelText(panel, "18) Skip Hale notification mixes things up");
            DrawPanelText(panel, "19) Bosses may or may not obey Pyrovision voice rules. Or both.");
        }
        case 42: //139
        {
            DrawPanelText(panel, "1) !hale_resetqueuepoints");
            DrawPanelText(panel, "-- From chat, asks for confirmation");
            DrawPanelText(panel, "-- From console, no confirmation!");
            DrawPanelText(panel, "2) Help panel stops repeatedly popping up");
            DrawPanelText(panel, "3) Medic is credited 100% of damage done during uber");
            DrawPanelText(panel, "4) Bushwacka changes:");
            DrawPanelText(panel, "-- Hit a wall to climb it");
            DrawPanelText(panel, "-- Slower fire rate");
            DrawPanelText(panel, "-- Disables crits on rifles (not Huntsman)");
            DrawPanelText(panel, "-- Effect does not occur during HHH round");
            DrawPanelText(panel, "...contd.");
        }

        case 41: //139
        {
            DrawPanelText(panel, "5) Late December increases chances of CBS appearing");
            DrawPanelText(panel, "6) If map changes mid-round, queue points not lost");
            DrawPanelText(panel, "7) Fixed HHH tele (again).");
            DrawPanelText(panel, "8) HHH tele removes Sniper Rifle glow");
            DrawPanelText(panel, "9) Mantread stomp deals 5x damage to Hale");
            DrawPanelText(panel, "10) Rage stun range- Vagineer increased, CBS decreased");
            DrawPanelText(panel, "11) Balanced CBS arrows");
            DrawPanelText(panel, "12) Minicrits will not play loud sound to all players");
            DrawPanelText(panel, "13) Dead Ringer will not be able to activate for 2s after backstab");
            DrawPanelText(panel, "-- Other spy watches can");
            DrawPanelText(panel, "14) Fixed crit issues");
            DrawPanelText(panel, "15) Hale queue now accepts negative points");
            DrawPanelText(panel, "...contd.");
        }
        case 40: //139
        {
            DrawPanelText(panel, "16) For server owners:");
            DrawPanelText(panel, "-- Translations updated");
            DrawPanelText(panel, "-- Added hale_spec_force_boss cvar");
            DrawPanelText(panel, "-- Now attempts to integrate tf2items config");
            DrawPanelText(panel, "-- With steamtools, changes game desc");
            DrawPanelText(panel, "-- Plugin may warn if config is outdated");
            DrawPanelText(panel, "-- Jump/tele charge defines at top of code");
            DrawPanelText(panel, "17) For mapmakers:");
            DrawPanelText(panel, "-- Indicate that your map has music:");
            DrawPanelText(panel, "-- Add info_target with name 'hale_no_music'");
            DrawPanelText(panel, "18) Third Degree hit adds uber to healers");
            DrawPanelText(panel, "19) Knockback resistance on Hale/HHH");
        }
        case 39: //138
        {
            DrawPanelText(panel, "1) Bots will use rage.");
            DrawPanelText(panel, "2) Doors only forced open on specified maps");
            DrawPanelText(panel, "3) CBS spawns more during Winter holidays");
            DrawPanelText(panel, "4) Deathspam for teamswitch gone");
            DrawPanelText(panel, "5) More notice for next Hale");
            DrawPanelText(panel, "6) Wrap Assassin has 2 ammo");
            DrawPanelText(panel, "7) Holiday Punch slightly disorients Hale");
            DrawPanelText(panel, "-- If stunned Heavy punches Hale, removes stun");
            DrawPanelText(panel, "8) Mantreads increase rocketjump distance");
        }
        case 38: //138
        {
            DrawPanelText(panel, "9) Fixed CBS Huntsman rate of fire");
            DrawPanelText(panel, "10) Fixed permanent invuln Vagineer glitch");
            DrawPanelText(panel, "11) Jarate removes some Vagineer uber time and 1 CBS arrow");
            DrawPanelText(panel, "12) Low-end Medic assist damage now counted");
            DrawPanelText(panel, "13) Hitting Dead Ringers does more damage (as balancing)");
            DrawPanelText(panel, "14) Eureka Effect temporarily removed)");
            DrawPanelText(panel, "15) HHH won't get stuck in ceilings when teleporting");
            DrawPanelText(panel, "16) Further updates pending");
        }
        case 37:    //137
        {
            DrawPanelText(panel, "1) Fixed taunt/rage.");
            DrawPanelText(panel, "2) Fixed rage+high five.");
            DrawPanelText(panel, "3) hale_circuit_stun - Circuit Stun time (0 to disable)");
            DrawPanelText(panel, "4) Fixed coaching bug");
            DrawPanelText(panel, "5) Config file for map doors");
            DrawPanelText(panel, "6) Fixed floor-Hale");
            DrawPanelText(panel, "7) Fixed Circuit stun");
            DrawPanelText(panel, "8) Fixed negative health bug");
            DrawPanelText(panel, "9) hale_enabled isn't a dummy cvar anymore");
            DrawPanelText(panel, "10) hale_special cmd fixes");
        }
        case 36: //137
        {
            DrawPanelText(panel, "11) 1st-round cap enables after 1 min.");
            DrawPanelText(panel, "12) More invalid Hale checks.");
            DrawPanelText(panel, "13) Backstabs act like Razorbackstab (2s)");
            DrawPanelText(panel, "14) Fixed map check error");
            DrawPanelText(panel, "15) Wanga Prick -> Eternal Reward effect");
            DrawPanelText(panel, "16) Jarate removes 8% of Hale's rage meter");
            DrawPanelText(panel, "17) The Fan O' War removes 5% of the rage meter on hit");
            DrawPanelText(panel, "18) Removed Shortstop reload penalty");
            DrawPanelText(panel, "19) VSH_OnMusic forward");
        }
        case 35: //1369
        {
            DrawPanelText(panel, "1) Fixed spawn door blocking.");
            DrawPanelText(panel, "2) Cleaned up HUD text (health, etc).");
            DrawPanelText(panel, "3) VSH_OnDoJump now has a bool for superduper.");
            DrawPanelText(panel, "4) !halenoclass changed to !haleclassinfotoggle.");
            DrawPanelText(panel, "5) Fixed invalid clients becoming Hale");
            DrawPanelText(panel, "6) Removed teamscramble from first round.");
            DrawPanelText(panel, "7) Vagineer noises:");
            DrawPanelText(panel, "-- Nope for no");
            DrawPanelText(panel, "-- Gottam/mottag (same as jump but quieter) for Move Up");
            DrawPanelText(panel, "-- Hurr for everything else");
        }
        case 34: //1369
        {
            DrawPanelText(panel, "8) All map dispensers will be on the non-Hale team (fixes health bug)");
            DrawPanelText(panel, "9) Fixed command flags on overlay command");
            DrawPanelText(panel, "10) Fixed soldier shotgun not dealing midair minicrits.");
            DrawPanelText(panel, "11) Fixed invalid weapons on clients");
            DrawPanelText(panel, "12) Damage indicator (+spec damage indicator)");
            DrawPanelText(panel, "13) Hale speed remains during humiliation time");
            DrawPanelText(panel, "14) SuperDuperTele for HHH stuns for 4s instead of regular 2");
        }
        case 33: //1369
        {
            DrawPanelText(panel, "15) Battalion's Backup adds +10 max hp, but still only overheal to 300");
            DrawPanelText(panel, "-- Full rage meter when hit by Hale. Buff causes drastic defense boost.");
            DrawPanelText(panel, "16) Fixed a telefrag glitch");
            DrawPanelText(panel, "17) Powerjack is now +25hp on hit, heal up to +50 overheal");
            DrawPanelText(panel, "18) Backstab now shows the regular hit indicator (like other weapons do)");
            DrawPanelText(panel, "19) Kunai adds 100hp on backstab, up to 270");
            DrawPanelText(panel, "20) FaN/Scout crit knockback not nerfed to oblivion anymore");
            DrawPanelText(panel, "21) Removed Short Circuit stun (better effect being made)");
        }
        case 32: //1368
        {
            DrawPanelText(panel, "1) Now FaN and Scout crit knockback is REALLY lessened.");
            DrawPanelText(panel, "2) Medic says 'I'm charged' when he gets fully uber-charge with syringegun.");
            DrawPanelText(panel, "3) Team will scramble in 1st round, if 1st round is default arena.");
            DrawPanelText(panel, "4) Now client can disable info about changes of classes, displayed when round started.");
            DrawPanelText(panel, "5) Powerjack adds 50HPs per hit.");
            DrawPanelText(panel, "6) Short Circuit stuns Hale for 2.0 seconds.");
            DrawPanelText(panel, "7) Vagineer says \"hurr\"");
            //DrawPanelText(panel, "8) Added support of VSH achievements.");
        }
        case 31: //1367
        {
            DrawPanelText(panel, "1) Map-specific fixes:");
            DrawPanelText(panel, "-- Oilrig's pit no longer allows HHH to instatele");
            DrawPanelText(panel, "-- Arakawa's pit damage drastically lessened");
            DrawPanelText(panel, "2) General map fixes: disable spawn-blocking walls");
            DrawPanelText(panel, "3) Cap point now properly un/locks instead of fake-unlocking.");
            DrawPanelText(panel, "4) Tried fixing double-music playing.");
            DrawPanelText(panel, "5) Fixed Eternal Reward disguise glitch - edge case.");
            DrawPanelText(panel, "6) Help menus no longer glitch votes.");
        }
        case 30: //1366
        {
            DrawPanelText(panel, "1) Fixed superjump velocity code.");
            DrawPanelText(panel, "2) Fixed replaced Rocket Jumpers not minicritting Hale in midair.");
        }
        case 29: //1365
        {
            DrawPanelText(panel, "1) Half-Zatoichi is now allowed. Heal 35 health on hit, but must hit Hale to remove Honorbound.");
            DrawPanelText(panel, "-- Can add up to 25 overheal");
            DrawPanelText(panel, "-- Starts the round bloodied.");
            DrawPanelText(panel, "2) Fixed Hale not building rage when only Scouts remain.");
            DrawPanelText(panel, "3) Tried fixing Hale disconnect/nextround glitches (including music).");
            DrawPanelText(panel, "4) Candycane spawns healthpack on hit.");
        }
        case 28:    //1364
        {
            DrawPanelText(panel, "1) Added convar hale_first_round (default 0). If it's 0, first round will be default arena.");
            DrawPanelText(panel, "2) Added more translations.");
        }
        case 27:    //1363
        {
            DrawPanelText(panel, "1) Fixed a queue point exploit (VoiDeD is mean)");
            DrawPanelText(panel, "2) HHH has backstab/death sound now");
            DrawPanelText(panel, "3) First rounds are normal arena");
            DrawPanelText(panel, "-- Some weapon replacements still apply!");
            DrawPanelText(panel, "-- Teambalance is still off, too.");
            DrawPanelText(panel, "4) Fixed arena_ maps not switching teams occasionally");
            DrawPanelText(panel, "-- After 3 rounds with a team, has a chance to switch");
            DrawPanelText(panel, "-- Will add a cvar to keep Hale always blue/force team, soon");
            DrawPanelText(panel, "5) Fixed pit damage");
        }
        case 26:    //1361 and 2
        {
            DrawPanelText(panel, "1) CBS music");
            DrawPanelText(panel, "2) Soldiers minicrit Hale while he's in midair.");
            DrawPanelText(panel, "3) Direct Hit crits instead of minicrits");
            DrawPanelText(panel, "4) Reserve Shooter switches faster, +10% dmg");
            DrawPanelText(panel, "5) Added hale_stop_music cmd - admins stop music for all");
            DrawPanelText(panel, "6) FaN and Scout crit knockback is lessened");
            DrawPanelText(panel, "7) Your halemusic/halevoice settings are saved");
            DrawPanelText(panel, "1.362) Sounds aren't stupid .mdl files anymore");
            DrawPanelText(panel, "1.362) Fixed translations");
        }
        case 25:    //136
        {
            DrawPanelText(panel, "MEGA UPDATE by FlaminSarge! Check next few pages");
            DrawPanelText(panel, "SUGGEST MANNO-TECH WEAPON CHANGES");
            DrawPanelText(panel, "1) Updated CBS model");
            DrawPanelText(panel, "2) Fixed last man alive sound");
            DrawPanelText(panel, "3) Removed broken hale line, fixed one");
            DrawPanelText(panel, "4) New HHH rage sound");
            DrawPanelText(panel, "5) HHH music (/halemusic)");
            DrawPanelText(panel, "6) CBS jump noise");
            DrawPanelText(panel, "7) /halevoice and /halemusic to turn off voice/music");
            DrawPanelText(panel, "8) Updated natives/forwards (can change rage dist in fwd)");
        }
        case 24:    //136
        {
            DrawPanelText(panel, "9) hale_crits cvar to turn off hale random crits");
            DrawPanelText(panel, "10) Fixed sentries not repairing when raged");
            DrawPanelText(panel, "-- Set hale_ragesentrydamagemode 0 to force engineer to pick up sentry to repair");
            DrawPanelText(panel, "11) Now uses sourcemod autoconfig (tf/cfg/sourcemod/)");
            DrawPanelText(panel, "12) No longer requires saxton_hale_points.cfg file");
            DrawPanelText(panel, "-- Now using clientprefs for queue points");
            DrawPanelText(panel, "13) When on non-VSH map, team switch does not occur so often.");
            DrawPanelText(panel, "14) Should have full replay compatibility");
            DrawPanelText(panel, "15) Bots work with queue, are Hale less often");
        }
        case 23:    //136
        {
            DrawPanelText(panel, "16) Hale's health increased by 1 (in code)");
            DrawPanelText(panel, "17) Many many many many many fixes");
            DrawPanelText(panel, "18) Crossbow +150% damage +10 uber on hit");
            DrawPanelText(panel, "19) Syringegun has overdose speed boost");
            DrawPanelText(panel, "20) Sniper glow time scales with charge (2 to 8 seconds)");
            DrawPanelText(panel, "21) Eyelander/reskins add heads on hit");
            DrawPanelText(panel, "22) Axetinguisher/reskins use fire axe attributes");
            DrawPanelText(panel, "23) GRU/KGB is +50% speed but -7hp/s");
            DrawPanelText(panel, "24) Airblasting boss adds rage (no airblast reload though)");
            DrawPanelText(panel, "25) Airblasting uber vagineer adds time to uber and takes extra ammo");
        }
        case 22:    //136
        {
            DrawPanelText(panel, "26) Frontier Justice allowed, crits only when sentry sees Hale");
            DrawPanelText(panel, "27) Boss weighdown (look down + crouch) after 5 seconds in midair");
            DrawPanelText(panel, "28) FaN is back");
            DrawPanelText(panel, "29) Scout crits/minicrits do less knockback if not melee");
            DrawPanelText(panel, "30) Saxton has his own fists");
            DrawPanelText(panel, "31) Unlimited /halehp but after 3, longer cooldown");
            DrawPanelText(panel, "32) Fist kill icons");
            DrawPanelText(panel, "33) Fixed CBS arrow count (start at 9, but if less than 9 players, uses only that number of players)");
            DrawPanelText(panel, "34) Spy primary minicrits");
            DrawPanelText(panel, "35) Dead ringer fixed");
        }
        case 21:    //136
        {
            DrawPanelText(panel, "36) Flare gun replaced with detonator. Has large jump but more self-damage (like old detonator beta)");
            DrawPanelText(panel, "37) Eternal Reward backstab disguises as random faster classes");
            DrawPanelText(panel, "38) Kunai adds 60 health on backstab");
            DrawPanelText(panel, "39) Randomizer compatibility.");
            DrawPanelText(panel, "40) Medic uber works as normal with crits added (multiple targets, etc)");
            DrawPanelText(panel, "41) Crits stay when being healed, but adds minicrits too (for sentry, etc)");
            DrawPanelText(panel, "42) Fixed Sniper back weapon replacement");
        }
        case 20:    //136
        {
            DrawPanelText(panel, "43) Vagineer NOPE and Well Don't That Beat All!");
            DrawPanelText(panel, "44) Telefrags do 9001 damage");
            DrawPanelText(panel, "45) Speed boost when healing scouts (like Quick-Fix)");
            DrawPanelText(panel, "46) Rage builds (VERY slowly) if there are only Scouts left");
            DrawPanelText(panel, "47) Healing assist damage split between healers");
            DrawPanelText(panel, "48) Fixed backstab assist damage");
            DrawPanelText(panel, "49) Fixed HHH attacking during tele");
            DrawPanelText(panel, "50) Soldier boots - 1/10th fall damage");
            DrawPanelText(panel, "AND MORE! (I forget all of them)");
        }
        case 19:    //135_3
        {
            DrawPanelText(panel, "1)Added point system (/halenext).");
            DrawPanelText(panel, "2)Added [VSH] to VSH messages.");
            DrawPanelText(panel, "3)Removed native VSH_GetSaxtonHaleHealth() added native VSH_GetRoundState().");
            DrawPanelText(panel, "4)There is mini-crits for scout's pistols. Not full crits, like before.");
            DrawPanelText(panel, "5)Fixed issues associated with crits.");
            DrawPanelText(panel, "6)Added FORCE_GENERATION flag to stop errorlogs.");
            DrawPanelText(panel, "135_2 and 135_3)Bugfixes and updated translations.");
        }
        case 18:    //135
        {
            DrawPanelText(panel, "1)Special crits will not removed by Medic.");
            DrawPanelText(panel, "2)Sniper's glow is working again.");
            DrawPanelText(panel, "3)Less errors in console.");
            DrawPanelText(panel, "4)Less messages in chat.");
            DrawPanelText(panel, "5)Added more natives.");
            DrawPanelText(panel, "6)\"Over 9000\" sound returns! Thx you, FlaminSarge.");
            DrawPanelText(panel, "7)Hopefully no more errors in logs.");
        }
        case 17:    //134
        {
            DrawPanelText(panel, "1)Biohazard skin for CBS");
            DrawPanelText(panel, "2)TF2_IsPlayerInCondition() fixed");
            DrawPanelText(panel, "3)Now sniper rifle must be 100perc.charged to glow Hale.");
            DrawPanelText(panel, "4)Fixed Vagineer's model.");
            DrawPanelText(panel, "5)Added Natives.");
            DrawPanelText(panel, "6)Hunstman deals more damage.");
            DrawPanelText(panel, "7)Added reload time (5sec) for Pyro's airblast. ");
            DrawPanelText(panel, "1.34_1 1)Fixed airblast reload when VSH is disabled.");
            DrawPanelText(panel, "1.34_1 2)Fixed airblast reload after detonator's alt-fire.");
            DrawPanelText(panel, "1.34_1 3)Airblast reload time reduced to 3 seconds.");
            DrawPanelText(panel, "1.34_1 4)hale_special 3 is disabled.");
        }
        case 16:    //133
        {
            DrawPanelText(panel, "1)Fixed bugs, associated with Uber-update.");
            DrawPanelText(panel, "2)FaN replaced with Soda Popper.");
            DrawPanelText(panel, "3)Bazaar Bargain replaced with Sniper Rifle.");
            DrawPanelText(panel, "4)Sniper Rifle adding glow to Hale - anyone can see him for 5 seconds.");
            DrawPanelText(panel, "5)Crusader's Crossbow deals more damage.");
            DrawPanelText(panel, "6)Code optimizing.");
        }
        case 15:    //132
        {
            DrawPanelText(panel, "1)Added new Saxton's lines on...");
            DrawPanelText(panel, "  a)round start");
            DrawPanelText(panel, "  b)jump");
            DrawPanelText(panel, "  c)backstab");
            DrawPanelText(panel, "  d)destroy Sentry");
            DrawPanelText(panel, "  e)kill Scout, Pyro, Heavy, Engineer, Spy");
            DrawPanelText(panel, "  f)last man standing");
            DrawPanelText(panel, "  g)killing spree");
            DrawPanelText(panel, "2)Fixed bugged count of CBS' arrows.");
            DrawPanelText(panel, "3)Reduced Hale's damage versus DR by 20 HPs.");
            DrawPanelText(panel, "4)Now two specials can not be at a stretch.");
            DrawPanelText(panel, "v1.32_1 1)Fixed bug with replay.");
            DrawPanelText(panel, "v1.32_1 2)Fixed bug with help menu.");
        }
        case 14:    //131
            DrawPanelText(panel, "1)Now \"replay\" will not change team.");
        case 13:    //130
            DrawPanelText(panel, "1)Fixed bugs, associated with crushes, error logs, scores.");
        case 12:    //129
        {
            DrawPanelText(panel, "1)Fixed random crushes associated with CBS.");
            DrawPanelText(panel, "2)Now Hale's HP formula is ((760+x-1)*(x-1))^1.04");
            DrawPanelText(panel, "3)Added hale_special0. Use it to change next boss to Hale.");
            DrawPanelText(panel, "4)CBS has 9 arrows for bow-rage. Also he has stun rage, but on little distantion.");
            DrawPanelText(panel, "5)Teammates gets 2 scores per each 600 damage");
            DrawPanelText(panel, "6)Demoman with Targe has crits on his primary weapon.");
            DrawPanelText(panel, "7)Removed support of non-Arena maps, because nobody wasn't use it.");
            DrawPanelText(panel, "8)Pistol/Lugermorph has crits.");
        }
        case 11:    //128
        {
            DrawPanelText(panel, "VS Saxton Hale Mode is back!");
            DrawPanelText(panel, "1)Christian Brutal Sniper is a regular character.");
            DrawPanelText(panel, "2)CBS has 3 melee weapons ad bow-rage.");
            DrawPanelText(panel, "3)Added new lines for Vagineer.");
            DrawPanelText(panel, "4)Updated models of Vagineer and HHH jr.");
        }
        case 10:    //999
            DrawPanelText(panel, "Attachables are broken. Many \"thx\" to Valve.");
        case 9: //126
        {
            DrawPanelText(panel, "1)Added the second URL for auto-update.");
            DrawPanelText(panel, "2)Fixed problems, when auto-update was corrupt plugin.");
            DrawPanelText(panel, "3)Added a question for the next Hale, if he want to be him. (/haleme)");
            DrawPanelText(panel, "4)Eyelander and Half-Zatoichi was replaced with Claidheamh Mor.");
            DrawPanelText(panel, "5)Fan O'War replaced with Bat.");
            DrawPanelText(panel, "6)Dispenser and TP won't be destoyed after Engineer's death.");
            DrawPanelText(panel, "7)Mode uses the localization file.");
            DrawPanelText(panel, "8)Saxton Hale will be choosed randomly for the first 3 rounds (then by queue).");
        }
        case 8: //125
        {
            DrawPanelText(panel, "1)Fixed silent HHHjr's rage.");
            DrawPanelText(panel, "2)Now bots (sourcetv too) do not will be Hale");
            DrawPanelText(panel, "3)Fixed invalid uber on Vagineer's head.");
            DrawPanelText(panel, "4)Fixed other little bugs.");
        }
        case 7: //124
        {
            DrawPanelText(panel, "1)Fixed destroyed buildables associated with spy's fake death.");
            DrawPanelText(panel, "2)Syringe Gun replaced with Blutsauger.");
            DrawPanelText(panel, "3)Blutsauger, on hit: +5 to uber-charge.");
            DrawPanelText(panel, "4)Removed crits from Blutsauger.");
            DrawPanelText(panel, "5)CnD replaced with Invis Watch.");
            DrawPanelText(panel, "6)Fr.Justice replaced with shotgun");
            DrawPanelText(panel, "7)Fists of steel replaced with fists.");
            DrawPanelText(panel, "8)KGB replaced with GRU.");
            DrawPanelText(panel, "9)Added /haleclass.");
            DrawPanelText(panel, "10)Medic gets assist damage scores (1/2 from healing target's damage scores, 1/1 when uber-charged)");
        }
        case 6: //123
        {
            DrawPanelText(panel, "1)Added Super Duper Jump to rescue Hale from pit");
            DrawPanelText(panel, "2)Removed pyro's ammolimit");
            DrawPanelText(panel, "3)Fixed little bugs.");
        }
        case 5: //122
        {
            DrawPanelText(panel, "1.21)Point will be enabled when X or less players be alive.");
            DrawPanelText(panel, "1.22)Now it's working :) Also little optimize about player count.");
        }
        case 4: //120
        {
            DrawPanelText(panel, "1)Added new Hale's phrases.");
            DrawPanelText(panel, "2)More bugfixes.");
            DrawPanelText(panel, "3)Improved super-jump.");
        }
        case 3: //112
        {
            DrawPanelText(panel, "1)More bugfixes.");
            DrawPanelText(panel, "2)Now \"(Hale)<mapname>\" can be nominated for nextmap.");
            DrawPanelText(panel, "3)Medigun's uber gets uber and crits for Medic and his target.");
            DrawPanelText(panel, "4)Fixed infinite Specials.");
            DrawPanelText(panel, "5)And more bugfixes.");
        }
        case 2: //111
        {
            DrawPanelText(panel, "1)Fixed immortal spy");
            DrawPanelText(panel, "2)Fixed crashes associated with classlimits.");
        }
        case 1: //110
        {
            DrawPanelText(panel, "1)Not important changes on code.");
            DrawPanelText(panel, "2)Added hale_enabled convar.");
            DrawPanelText(panel, "3)Fixed bug, when all hats was removed...why?");
        }
        case 0: //100
        {
            DrawPanelText(panel, "Released!!!");
            DrawPanelText(panel, "On new version you will get info about changes.");
        }
        default:
        {
            DrawPanelText(panel, "-- Somehow you've managed to find a glitched version page!");
            DrawPanelText(panel, "-- Congratulations. Now go fight Hale.");
        }
    }
}
public HelpPanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        return;
    }
}
public Action:HelpPanelCmd(client, args)
{
    if (!client) return Plugin_Handled;
    HelpPanel(client);
    return Plugin_Handled;
}
public Action:HelpPanel(client)
{
    if (!g_bAreEnoughPlayersPlaying || IsVoteInProgress())
        return Plugin_Continue;
    new Handle:panel = CreatePanel();
    decl String:s[512];
    SetGlobalTransTarget(client);
    Format(s, 512, "%t", "vsh_help_mode");
    DrawPanelItem(panel, s);
    Format(s, 512, "%t", "vsh_menu_exit");
    DrawPanelItem(panel, s);
    SendPanelToClient(panel, client, HelpPanelH, 9001);
    CloseHandle(panel);
    return Plugin_Continue;
}
public Action:HelpPanel2Cmd(client, args)
{
    if (!client)
    {
        return Plugin_Handled;
    }

    if (client == Hale)
    {
        HintPanel(Hale);
    }
    else
    {
        HelpPanel2(client);
    }
    
    return Plugin_Handled;
}
public Action:HelpPanel2(client)
{
    if (!g_bAreEnoughPlayersPlaying || IsVoteInProgress())
        return Plugin_Continue;
    decl String:s[512];
    new TFClassType:class = TF2_GetPlayerClass(client);
    SetGlobalTransTarget(client);
    switch (class)
    {
        case TFClass_Scout:
            Format(s, 512, "%t", "vsh_help_scout");
        case TFClass_Soldier:
            Format(s, 512, "%t", "vsh_help_soldier");
        case TFClass_Pyro:
            Format(s, 512, "%t", "vsh_help_pyro");
        case TFClass_DemoMan:
            Format(s, 512, "%t", "vsh_help_demo");
        case TFClass_Heavy:
            Format(s, 512, "%t", "vsh_help_heavy");
        case TFClass_Engineer:
            Format(s, 512, "%t", "vsh_help_eggineer");
        case TFClass_Medic:
            Format(s, 512, "%t", "vsh_help_medic");
        case TFClass_Sniper:
            Format(s, 512, "%t", "vsh_help_sniper");
        case TFClass_Spy:
            Format(s, 512, "%t", "vsh_help_spie");
        default:
            Format(s, 512, "");
    }
    new Handle:panel = CreatePanel();
    if (class != TFClass_Sniper)
        Format(s, 512, "%t\n%s", "vsh_help_melee", s);
    SetPanelTitle(panel, s);
    DrawPanelItem(panel, "Exit");
    SendPanelToClient(panel, client, HintPanelH, 12);
    CloseHandle(panel);
    return Plugin_Continue;
}
public Action:ClasshelpinfoCmd(client, args)
{
    if (!client) return Plugin_Handled;
    ClasshelpinfoSetting(client);
    return Plugin_Handled;
}
public Action:ClasshelpinfoSetting(client)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Handled;
    new Handle:panel = CreatePanel();
    SetPanelTitle(panel, "Turn the VS Saxton Hale class info...");
    DrawPanelItem(panel, "On");
    DrawPanelItem(panel, "Off");
    SendPanelToClient(panel, client, ClasshelpinfoTogglePanelH, 9001);
    CloseHandle(panel);
    return Plugin_Handled;
}
public ClasshelpinfoTogglePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (IsValidClient(param1))
    {
        if (action == MenuAction_Select)
        {
            if (param2 == 2)
                SetClientCookie(param1, ClasshelpinfoCookie, "0");
            else
                SetClientCookie(param1, ClasshelpinfoCookie, "1");
            CPrintToChat(param1, "{olive}[VSH]{default} %t", "vsh_classinfo", param2 == 2 ? "off" : "on");
        }
    }
}
/*public HelpPanelH1(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if (param2 == 1)
            HelpPanel(param1);
        else if (param2 == 2)
            return;
    }
}
public Action:HelpPanel1(client, Args)
{
    if (!g_bAreEnoughPlayersPlaying)
        return Plugin_Continue;
    new Handle:panel = CreatePanel();
    SetPanelTitle(panel, "Hale is unusually strong.\nBut he doesn't use weapons, because\nhe believes that problems should be\nsolved with bare hands.");
    DrawPanelItem(panel, "Back");
    DrawPanelItem(panel, "Exit");
    SendPanelToClient(panel, client, HelpPanelH1, 9001);
    CloseHandle(panel);
    return Plugin_Continue;
}*/
public Action:MusicTogglePanelCmd(client, args)
{
    if (!client) return Plugin_Handled;
    MusicTogglePanel(client);
    return Plugin_Handled;
}
public Action:MusicTogglePanel(client)
{
    if (!g_bAreEnoughPlayersPlaying || !client)
        return Plugin_Handled;
    new Handle:panel = CreatePanel();
    SetPanelTitle(panel, "Turn the VS Saxton Hale music...");
    DrawPanelItem(panel, "On");
    DrawPanelItem(panel, "Off");
    SendPanelToClient(panel, client, MusicTogglePanelH, 9001);
    CloseHandle(panel);
    return Plugin_Handled;
}
public MusicTogglePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (IsValidClient(param1))
    {
        if (action == MenuAction_Select)
        {
            if (param2 == 2)
            {
                SetClientSoundOptions(param1, SOUNDEXCEPT_MUSIC, false);
                StopHaleMusic(param1);
            }
            else
                SetClientSoundOptions(param1, SOUNDEXCEPT_MUSIC, true);
            CPrintToChat(param1, "{olive}[VSH]{default} %t", "vsh_music", param2 == 2 ? "off" : "on");
        }
    }
}
public Action:VoiceTogglePanelCmd(client, args)
{
    if (!client) return Plugin_Handled;
    VoiceTogglePanel(client);
    return Plugin_Handled;
}
public Action:VoiceTogglePanel(client)
{
    if (!g_bAreEnoughPlayersPlaying || !client)
        return Plugin_Handled;
    new Handle:panel = CreatePanel();
    SetPanelTitle(panel, "Turn the VS Saxton Hale voices...");
    DrawPanelItem(panel, "On");
    DrawPanelItem(panel, "Off");
    SendPanelToClient(panel, client, VoiceTogglePanelH, 9001);
    CloseHandle(panel);
    return Plugin_Handled;
}

public VoiceTogglePanelH(Handle:menu, MenuAction:action, param1, param2)
{
    if (IsValidClient(param1))
    {
        if (action == MenuAction_Select)
        {
            if (param2 == 2)
                SetClientSoundOptions(param1, SOUNDEXCEPT_VOICE, false);
            else
                SetClientSoundOptions(param1, SOUNDEXCEPT_VOICE, true);
            CPrintToChat(param1, "{olive}[VSH]{default} %t", "vsh_voice", param2 == 2 ? "off" : "on");
            if (param2 == 2) CPrintToChat(param1, "%t", "vsh_voice2");
        }
    }
}

public Action:HookSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    if (!g_bEnabled || ((entity != Hale) && ((entity <= 0) || !IsValidClient(Hale) || (entity != GetPlayerWeaponSlot(Hale, 0)))))
        return Plugin_Continue;
    if (StrContains(sample, "saxton_hale", false) != -1)
        return Plugin_Continue;
    if (strcmp(sample, "vo/engineer_LaughLong01.mp3", false) == 0)
    {
        strcopy(sample, PLATFORM_MAX_PATH, VagineerKSpree);
        return Plugin_Changed;
    }
    if (entity == Hale && Special == VSHSpecial_HHH && strncmp(sample, "vo", 2, false) == 0 && StrContains(sample, "halloween_boss") == -1)
    {
        if (GetRandomInt(0, 100) <= 10)
        {
            Format(sample, PLATFORM_MAX_PATH, "%s0%i.mp3", HHHLaught, GetRandomInt(1, 4));
            return Plugin_Changed;
        }
    }
    if (Special != VSHSpecial_CBS && !strncmp(sample, "vo", 2, false) && StrContains(sample, "halloween_boss") == -1)
    {
        if (Special == VSHSpecial_Vagineer)
        {
            if (StrContains(sample, "engineer_moveup", false) != -1)
                Format(sample, PLATFORM_MAX_PATH, "%s%i.wav", VagineerJump, GetRandomInt(1, 2));
            else if (StrContains(sample, "engineer_no", false) != -1 || GetRandomInt(0, 9) > 6)
                strcopy(sample, PLATFORM_MAX_PATH, "vo/engineer_no01.mp3");
            else
                strcopy(sample, PLATFORM_MAX_PATH, "vo/engineer_jeers02.mp3");
            return Plugin_Changed;
        }
#if defined EASTER_BUNNY_ON
        if (Special == VSHSpecial_Bunny)
        {
            if (StrContains(sample, "gibberish", false) == -1 && StrContains(sample, "burp", false) == -1 && !GetRandomInt(0, 2))
            {
                //Do sound things
                strcopy(sample, PLATFORM_MAX_PATH, BunnyRandomVoice[GetRandomInt(0, sizeof(BunnyRandomVoice)-1)]);
                return Plugin_Changed;
            }
            return Plugin_Continue;
        }
#endif
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

#if defined EASTER_BUNNY_ON
public OnEntityCreated(entity, const String:classname[])
{
    if (g_bEnabled && VSHRoundState == VSHRState_Active && strcmp(classname, "tf_projectile_pipe", false) == 0)
        SDKHook(entity, SDKHook_SpawnPost, OnEggBombSpawned);
}
public OnEggBombSpawned(entity)
{
    new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if (IsValidClient(owner) && owner == Hale && Special == VSHSpecial_Bunny)
        RequestFrame(Timer_SetEggBomb, EntIndexToEntRef(entity));
}
public Timer_SetEggBomb(any:ref)
{
    new entity = EntRefToEntIndex(ref);
    if (FileExists(EggModel) && IsModelPrecached(EggModel) && IsValidEntity(entity))
    {
        new att = AttachProjectileModel(entity, EggModel);
        SetEntProp(att, Prop_Send, "m_nSkin", 0);
        SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
        SetEntityRenderColor(entity, 255, 255, 255, 0);
    }
}
#endif

//#define EF_BONEMERGE            (1 << 0)
//#define EF_BONEMERGE_FASTCULL   (1 << 7)
/*stock CreateVM(client, String:model[])
{
    new ent = CreateEntityByName("tf_wearable_vm");
    if (!IsValidEntity(ent)) return -1;
    SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
    SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
    SetEntProp(ent, Prop_Send, "m_iTeamNum", GetEntityTeamNum(client));
    SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
    SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
    DispatchSpawn(ent);
    SetVariantString("!activator");
    ActivateEntity(ent);
    TF2_EquipWearable(client, ent);
    return ent;
}*/
//Moved to tf2_stocks.inc
/*stock TF2_EquipWearable(client, entity)
{
    SDKCall(hEquipWearable, client, entity);
}*/

stock AttachProjectileModel(entity, String:strModel[], String:strAnim[] = "")
{
    if (!IsValidEntity(entity)) return -1;
    new model = CreateEntityByName("prop_dynamic");
    if (IsValidEdict(model))
    {
        decl Float:pos[3];
        decl Float:ang[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
        TeleportEntity(model, pos, ang, NULL_VECTOR);
        DispatchKeyValue(model, "model", strModel);
        DispatchSpawn(model);
        SetVariantString("!activator");
        AcceptEntityInput(model, "SetParent", entity, model, 0);
        if (strAnim[0] != '\0')
        {
            SetVariantString(strAnim);
            AcceptEntityInput(model, "SetDefaultAnimation");
            SetVariantString(strAnim);
            AcceptEntityInput(model, "SetAnimation");
        }
        SetEntPropEnt(model, Prop_Send, "m_hOwnerEntity", entity);
        return model;
    } else {
        LogError("(AttachProjectileModel): Could not create prop_dynamic");
    }
    return -1;
}

public Native_IsVSHMap(Handle:plugin, numParams)
{
    return IsSaxtonHaleMap();
/*  new result = IsSaxtonHaleMap();
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnIsVSHMap);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;*/
}
/*
public Native_IsEnabled(Handle:plugin, numParams)
{
    new result = g_bEnabled;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnIsEnabled);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}

public Native_GetHale(Handle:plugin, numParams)
{
    new result = -1;
    if (IsValidClient(Hale))
        result = GetClientUserId(Hale);
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetHale);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;

}

public Native_GetTeam(Handle:plugin, numParams)
{
    new result = HaleTeam;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetTeam);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}

public Native_GetSpecial(Handle:plugin, numParams)
{
    new result = Special;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetSpecial);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}

public Native_GetHealth(Handle:plugin, numParams)
{
    new result = HaleHealth;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetHealth);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;

    return result;
}

public Native_GetHealthMax(Handle:plugin, numParams)
{
    new result = HaleHealthMax;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetHealthMax);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}

public Native_GetRoundState(Handle:plugin, numParams)
{
    new result = VSHRoundState;
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetRoundState);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}
public Native_GetDamage(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new result = 0;
    if (IsValidClient(client))
        result = Damage[client];
    new result2 = result;

    new Action:act = Plugin_Continue;
    Call_StartForward(OnGetDamage);
    Call_PushCell(client);
    Call_PushCellRef(result2);
    Call_Finish(act);
    if (act == Plugin_Changed)
        result = result2;
    return result;
}*/

public Native_IsEnabled(Handle:plugin, numParams)
{
    return g_bEnabled;
}
public Native_GetHale(Handle:plugin, numParams)
{
    if (IsValidClient(Hale))
        return GetClientUserId(Hale);
    return -1;
}
public Native_GetTeam(Handle:plugin, numParams)
{
    return HaleTeam;
}
public Native_GetSpecial(Handle:plugin, numParams)
{
    return Special;
}
public Native_GetHealth(Handle:plugin, numParams)
{
    return HaleHealth;
}
public Native_GetHealthMax(Handle:plugin, numParams)
{
    return HaleHealthMax;
}
public Native_GetRoundState(Handle:plugin, numParams)
{
    return VSHRoundState;
}
public Native_GetDamage(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    return Damage[client];
}

// Chdata's plugin reload command
public Action:Debug_ReloadVSH(iClient, iArgc)
{
    g_bReloadVSHOnRoundEnd = true;
    switch (VSHRoundState)
    {
        case VSHRState_End, VSHRState_Disabled:
        {
            CReplyToCommand(iClient, "{olive}[VSH]{default} The plugin has been reloaded.");
            SetClientQueuePoints(Hale, 0);
            ServerCommand("sm plugins reload saxtonhale");
        }
        default:
        {
            CReplyToCommand(iClient, "{olive}[VSH]{default} The plugin is set to reload.");
            SetClientQueuePoints(Hale, 0);
        }
    }
    return Plugin_Handled;
}


/*
    chdata.inc

    AKA, stuff that could be useful in any plugin / are not specific to VSH
*/

// True if they weren't in the condition and were set to it.
stock bool:InsertCond(iClient, TFCond:iCond, Float:flDuration = TFCondDuration_Infinite)
{
    if (!TF2_IsPlayerInCondition(iClient, iCond))
    {
        TF2_AddCondition(iClient, iCond, flDuration);
        return true;
    }
    return false;
}

// True if the condition was removed.
stock bool:RemoveCond(iClient, TFCond:iCond)
{
    if (TF2_IsPlayerInCondition(iClient, iCond))
    {
        TF2_RemoveCondition(iClient, iCond);
        return true;
    }
    return false;
}

// true if removed, false if not found / etc
stock bool:RemoveDemoShield(iClient)
{
    new iEnt = MaxClients + 1;
    while ((iEnt = FindEntityByClassname2(iEnt, "tf_wearable_demoshield")) != -1)
    {
        if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEnt, Prop_Send, "m_bDisguiseWearable"))
        {
            TF2_RemoveWearable(iClient, iEnt);
            return true;
        }
    }
    return false;
}

// Returns true if at least one was removed
stock bool:RemovePlayerBack(client, indices[], len)
{
    if (len <= 0)
    {
        return false;
    }

    new bool:bReturn = false;

    new edict = MaxClients + 1;

    while ((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
    {
        decl String:netclass[32];

        if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
        {
            new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");

            if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
            {
                for (new i = 0; i < len; i++)
                {
                    if (idx == indices[i])
                    {
                        TF2_RemoveWearable(client, edict);
                        bReturn = true;
                    }
                }
            }
        }
    }

    edict = MaxClients + 1;

    while ((edict = FindEntityByClassname2(edict, "tf_powerup_bottle")) != -1)
    {
        decl String:netclass[32];

        if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFPowerupBottle"))
        {
            new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");

            if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
            {
                for (new i = 0; i < len; i++)
                {
                    if (idx == indices[i])
                    {
                        TF2_RemoveWearable(client, edict);
                        bReturn = true;
                        //AcceptEntityInput(edict, "Kill");
                    }
                }
            }
        }
    }

    return bReturn;
}

// Returns entity index as soon as any one is found, -1 if none found
stock FindPlayerBack(client, indices[], len)
{
    if (len <= 0)
    {
        return -1;
    }

    new edict = MaxClients + 1;

    while ((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
    {
        decl String:netclass[32];

        if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
        {
            new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");

            if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
            {
                for (new i = 0; i < len; i++)
                {
                    if (idx == indices[i])
                    {
                        return edict;
                    }
                }
            }
        }
    }

    edict = MaxClients + 1;

    while ((edict = FindEntityByClassname2(edict, "tf_powerup_bottle")) != -1)
    {
        decl String:netclass[32];

        if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFPowerupBottle"))
        {
            new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");

            if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
            {
                for (new i = 0; i < len; i++)
                {
                    if (idx == indices[i])
                    {
                        return edict;
                    }
                }
            }
        }
    }

    return -1;
}

stock Float:fmax(Float:a,Float:b) { return (a > b) ? a : b; }
stock Float:fmin(Float:a,Float:b) { return (a < b) ? a : b; }
stock Float:fclamp(Float:n,Float:mi,Float:ma)
{
    n = fmin(n,ma);
    return fmax(n,mi);
}

static Float:g_flNext[e_flNext];
static Float:g_flNext2[e_flNext][TF_MAX_PLAYERS];

stock bool:IsNextTime(iIndex, Float:flAdditional = 0.0)
{
    return (GetEngineTime() >= g_flNext[iIndex]+flAdditional);
}

stock SetNextTime(iIndex, Float:flSeconds, bool:bAbsolute = false)
{
    g_flNext[iIndex] = bAbsolute ? flSeconds : GetEngineTime() + flSeconds;
}

stock Float:GetNextTime(iIndex)
{
    return g_flNext[iIndex];
}

stock Float:GetTimeTilNextTime(iIndex, bool:bNonNegative = true)
{
    return bNonNegative ? fmax(g_flNext[iIndex] - GetEngineTime(), 0.0) : (g_flNext[iIndex] - GetEngineTime());
}

stock GetSecsTilNextTime(iIndex, bool:bNonNegative = true)
{
    return RoundToFloor(GetTimeTilNextTime(iIndex, bNonNegative));
}

/*
    If next time occurs, we also add time on for when it is next allowed.
*/
stock bool:IfDoNextTime(iIndex, Float:flThenAdd)
{
    if (IsNextTime(iIndex))
    {
        SetNextTime(iIndex, flThenAdd);
        return true;
    }
    return false;
}

// Start of plural NextTime versions

stock bool:IsNextTime2(iClient, iIndex, Float:flAdditional = 0.0)
{
    return (GetEngineTime() >= g_flNext2[iIndex][iClient]+flAdditional);
}

stock SetNextTime2(iClient, iIndex, Float:flSeconds, bool:bAbsolute = false)
{
    g_flNext2[iIndex][iClient] = bAbsolute ? flSeconds : GetEngineTime() + flSeconds;
}

stock Float:GetTimeTilNextTime2(iClient, iIndex, bool:bNonNegative = true)
{
    return bNonNegative ? fmax(g_flNext2[iIndex][iClient] - GetEngineTime(), 0.0) : (g_flNext2[iIndex][iClient] - GetEngineTime());
}

stock IncNextTime2(iClient, iIndex, Float:flSeconds)
{
    g_flNext2[iIndex][iClient] = g_flNext2[iIndex][iClient] + flSeconds;
}

stock GetSecsTilNextTime2(iClient, iIndex, bool:bNonNegative = true)
{
    return RoundToFloor(GetTimeTilNextTime2(iClient, iIndex, bNonNegative));
}

/*
    If next time occurs, we also add time on for when it is next allowed.
*/
stock bool:IfDoNextTime2(iClient, iIndex, Float:flThenAdd)
{
    if (IsNextTime2(iClient, iIndex))
    {
        SetNextTime2(iClient, iIndex, flThenAdd);
        return true;
    }
    return false;
}

/*
    PriorityCenterText (Version 0x05)

    Only one message can be shown in center text at a time.
    These stocks allow that space to be given different priority levels that prevent new messages from overwriting what's there.

    By: Chdata

*/
static s_iLastPriority[TF_MAX_PLAYERS] = {MIN_INT,...};
//static Handle:s_hPCTTimer[TF_MAX_PLAYERS] = {INVALID_HANDLE,...};

/*
    An example of how to use this:

    PriorityCenterText(iClient, GetClientImmunityLevel(iClient), "My message's priority depends on my immunity level.");

    IF old priority == new priority THEN old message is overwritten by new message.

*/
stock PriorityCenterText(iClient, iPriority = MIN_INT, const String:szFormat[], any:...)
{
    if (!IsValidClient(iClient))
    {
        ThrowError("Client index %i is invalid or not in game.", iClient);
    }

    if (s_iLastPriority[iClient] > iPriority)
    {
        if (IsNextTime2(iClient, e_flNextEndPriority))
        {
            s_iLastPriority[iClient] = MIN_INT;
        }
        else
        {
            return;
        }
    }

    if (iPriority > s_iLastPriority[iClient])
    {
        SetNextTime2(iClient, e_flNextEndPriority, 5.0);
        s_iLastPriority[iClient] = iPriority;
    }

    decl String:szBuffer[MAX_CENTER_TEXT];
    SetGlobalTransTarget(iClient);
    VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
    PrintCenterText(iClient, "%s", szBuffer);
}

/*
    Send priority center text to everyone.
    This will obey priority sent to via PriorityCenterText() and not overwrite if it's lower priority
*/
stock PriorityCenterTextAll(iPriority = MIN_INT, const String:szFormat[], any:...)
{
    decl String:szBuffer[MAX_CENTER_TEXT];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SetGlobalTransTarget(i);
            VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
            PriorityCenterText(i, iPriority, "%s", szBuffer);
        }
    }
}

/*
    Send priority center text to everyone.
    This version bypasses the priority in PriorityCenterText() with its own internal counter.

    This version will ALWAYS have higher priority than the functions above, so long as it has higher priority than 'itself'

    The priority of all players will be completely maxed out to achieve this.
*/
stock PriorityCenterTextAllEx(iPriority = -2147483647, const String:szFormat[], any:...) // -2147483647 == MIN_INT+1
{
    if (iPriority == MIN_INT)
    {
        iPriority++;
    }

    if (s_iLastPriority[0] > iPriority)
    {
        if (IsNextTime2(0, e_flNextEndPriority))
        {
            s_iLastPriority[0] = MIN_INT;

            for (new i = 1; i <= MaxClients; i++)
            {
                s_iLastPriority[i] = MIN_INT;
            }
        }
        else
        {
            return;
        }
    }

    if (iPriority > s_iLastPriority[0])
    {
        IncNextTime2(0, e_flNextEndPriority, 5.0);

        s_iLastPriority[0] = iPriority;

        for (new i = 1; i <= MaxClients; i++)
        {
            s_iLastPriority[i] = MAX_INT;
        }
    }

    decl String:szBuffer[MAX_CENTER_TEXT];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SetGlobalTransTarget(i);
            VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
            PrintCenterText(i, "%s", szBuffer);
        }
    }
}

/*
    Returns true if the current date is within bounds.

    Omit StartDay = Check if month matches

    If end values are ommited, it'll go from the start date to the end of the month.

    OnMapStart,
    IsDate(.bForceRecalc = true);
    to recalculate the date

    IsDate(Month_Mar, 25, Month_Apr, 20) == IsEasterHoliday()
    IsDate(Month_Oct, 15) == IsHalloweenHoliday()
    IsDate(Month_Dec, 15) == IsDecemberHoliday()

*/
stock bool:IsDate(StartMonth = Month_None, StartDay = 0, EndMonth = Month_None, EndDay = 0, bool:bForceRecalc = false)
{
    static iMonth;
    static iDate;
    static bool:bFound = false;

    if (bForceRecalc)
    {
        bFound = false;
        iMonth = 0;
        iDate = 0;
    }

    if (!bFound)
    {
        new iTimeStamp = GetTime();
        decl String:szMonth[MAX_DIGITS], String:szDate[MAX_DIGITS];

        FormatTime(szMonth, sizeof(szMonth), "%m", iTimeStamp);
        FormatTime(szDate, sizeof(szDate),   "%d", iTimeStamp);

        iMonth = StringToInt(szMonth);
        iDate = StringToInt(szDate);
        bFound = true;
    }

    return (StartMonth == iMonth && StartDay <= iDate) || (EndMonth && EndDay && (StartMonth < iMonth && iMonth <= EndMonth) && (iDate <= EndDay));
}

stock SetArenaCapEnableTime(Float:time)
{
    new ent = -1;
    decl String:strTime[32];
    FloatToString(time, strTime, sizeof(strTime));
    if ((ent = FindEntityByClassname2(-1, "tf_logic_arena")) != -1 && IsValidEdict(ent))
    {
        DispatchKeyValue(ent, "CapEnableDelay", strTime);
    }
}

stock bool:IsNearSpencer(client) 
{ 
    new bool:dispenserheal, medics = 0; 
    new healers = GetEntProp(client, Prop_Send, "m_nNumHealers"); 
    if (healers > 0) 
    { 
        for (new i = 1; i <= MaxClients; i++) 
        { 
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetHealingTarget(i) == client) 
                medics++; 
        } 
    } 
    dispenserheal = (healers > medics) ? true : false; 
    return dispenserheal; 
} 

stock FindSentry(client)
{
    new i=-1;
    while ((i = FindEntityByClassname2(i, "obj_sentrygun")) != -1)
    {
        if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") == client) return i;
    }
    return -1;
}

stock GetIndexOfWeaponSlot(client, slot)
{
    new weapon = GetPlayerWeaponSlot(client, slot);
    return (weapon > MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock GetClientCloakIndex(iClient)
{
    return GetWeaponIndex(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Watch));
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

/*stock GetClientCloakIndex(client)
{
    if (!IsValidClient(client, false)) return -1; // IsValidClient(client, false)
    new wep = GetPlayerWeaponSlot(client, 4);
    if (!IsValidEntity(wep)) return -1;
    new String:classname[64];
    GetEntityClassname(wep, classname, sizeof(classname));
    if (strncmp(classname, "tf_wea", 6, false) != 0) return -1;
    return GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
}*/

stock IncrementHeadCount(iClient)
{
    InsertCond(iClient, TFCond_DemoBuff);
    SetEntProp(iClient, Prop_Send, "m_iDecapitations", GetEntProp(iClient, Prop_Send, "m_iDecapitations") + 1);
    AddPlayerHealth(iClient, 15, 300, true);             //  The old version of this allowed infinite health gain... so ;v
    TF2_AddCondition(iClient, TFCond_SpeedBuffAlly, 0.01);  //  Recalculate their speed
}

stock SwitchToOtherWeapon(client)
{
    new ammo = GetAmmo(client, 0);
    new weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    new clip = (IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
    if (!(ammo == 0 && clip <= 0)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
    else SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary));
}

stock FindTeleOwner(client)
{
    if (!IsValidClient(client)) return -1;
    if (!IsPlayerAlive(client)) return -1;
    new tele = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
    decl String:classname[32];
    if (IsValidEntity(tele) && GetEdictClassname(tele, classname, sizeof(classname)) && strcmp(classname, "obj_teleporter", false) == 0)
    {
        new owner = GetEntPropEnt(tele, Prop_Send, "m_hBuilder");
        if (IsValidClient(owner)) return owner; // IsValidClient(owner, false)
    }
    return -1;
}

stock TF2_IsPlayerCritBuffed(client)
{
    return (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged)
            || TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy)
            || TF2_IsPlayerInCondition(client, TFCond:34)
            || TF2_IsPlayerInCondition(client, TFCond:35)
            || TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood)
            || TF2_IsPlayerInCondition(client, TFCond_CritOnWin)
            || TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture)
            || TF2_IsPlayerInCondition(client, TFCond_CritOnKill)
            || TF2_IsPlayerInCondition(client, TFCond_CritMmmph)
            );
}

stock SetNextAttack(weapon, Float:duration = 0.0)
{
    if (weapon <= MaxClients) return;
    if (!IsValidEntity(weapon)) return;
    new Float:next = GetGameTime() + duration;
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", next);
    SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", next);
}

stock SpawnWeapon(client, String:name[], index, level, qual, String:att[])
{
    new entity = CreateEntityByName(name);
    if (!IsValidEntity(entity))
        return -1;

    SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
    SetEntProp(entity, Prop_Send, "m_bInitialized", 1);

    DispatchSpawn(entity);

    SetEntProp(entity, Prop_Send, "m_iEntityLevel", level);
    SetEntProp(entity, Prop_Send, "m_iEntityQuality", qual);

    new String:atts[32][32];
    new count = ExplodeString(att, " ; ", atts, 32, 32);
    if (count > 1)
    {
#if defined _tf2attributes_included
        if (g_bTF2AttributesIsRunning)
        {
            for (new i = 0; i < count; i += 2)
            {
                TF2Attrib_SetByDefIndex(entity, StringToInt(atts[i]), StringToFloat(atts[i+1]));
            }
        }
#endif
    }

    EquipPlayerWeapon(client, entity);
    return entity;
}


stock SetAmmo(client, wepslot, newAmmo)
{
    new weapon = GetPlayerWeaponSlot(client, wepslot);
    if (!IsValidEntity(weapon)) return;
    new type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (type < 0 || type > 31) return;
    SetEntProp(client, Prop_Send, "m_iAmmo", newAmmo, _, type);
}

stock GetAmmo(client, wepslot)
{
    if (!IsValidClient(client)) return 0;
    new weapon = GetPlayerWeaponSlot(client, wepslot);
    if (!IsValidEntity(weapon)) return 0;
    new type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (type < 0 || type > 31) return 0;
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, type);
}

stock TF2_GetMetal(client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return 0;
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, 3);
}

stock TF2_SetMetal(client, metal)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return;
    SetEntProp(client, Prop_Send, "m_iAmmo", metal, _, 3);
}

stock GetHealingTarget(client)
{
    new String:s[64];
    new medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (medigun <= MaxClients || !IsValidEdict(medigun))
        return -1;
    GetEdictClassname(medigun, s, sizeof(s));
    if (strcmp(s, "tf_weapon_medigun", false) == 0)
    {
        if (GetEntProp(medigun, Prop_Send, "m_bHealing"))
            return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
    }
    return -1;
}

/*stock bool:IsValidClient(client, bool:replaycheck = true)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    // TF2C: no coaching property
    if (replaycheck)
    {
        if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
    }
    return true;
}*/

stock FindEntityByClassname2(startEnt, const String:classname[])
{
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
    return FindEntityByClassname(startEnt, classname);
}

/*
    @summary
        Changes a living player's team without killing/moving them
        I think it respawns them at spawn though.

    @params
        iClient should be validated before using this
        iTeam should be either 2 or 3

    @return
        false if not changed
        true if changed

        TODO: -1 not changed, 0 if changed with no respawn, 1 if changed with respawn

*/
stock ChangeTeam(iClient, iTeam) // iTeam should never be less than 2
{
    new iOldTeam = GetEntityTeamNum(iClient);

    if (iOldTeam != iTeam && iOldTeam >= TEAM_RED)
    {
        SetEntProp(iClient, Prop_Send, "m_lifeState", LifeState_Dead);
        ChangeClientTeam(iClient, iTeam);
        SetEntProp(iClient, Prop_Send, "m_lifeState", LifeState_Alive);
        TF2_RespawnPlayer(iClient);
    }
}

stock any:min(any:a,any:b) { return (a < b) ? a : b; }

/*
    Player health adder
    By: Chdata
*/
stock AddPlayerHealth(iClient, iAdd, iOverheal = 0, bStaticMax = false)
{
    new iHealth = GetClientHealth(iClient);
    new iNewHealth = iHealth + iAdd;
    new iMax = bStaticMax ? iOverheal : GetEntProp(iClient, Prop_Data, "m_iMaxHealth") + iOverheal;
    if (iHealth < iMax)
    {
        iNewHealth = min(iNewHealth, iMax);
        SetEntityHealth(iClient, iNewHealth);
    }
}

stock PrepareSound(const String:szSoundPath[])
{
    PrecacheSound(szSoundPath, true);
    decl String:s[PLATFORM_MAX_PATH];
    Format(s, sizeof(s), "sound/%s", szSoundPath);
    AddFileToDownloadsTable(s);
}

stock DownloadSoundList(const String:szFileList[][], iSize)
{
    for (new i = 0; i < iSize; i++)
    {
        PrepareSound(szFileList[i]);
    }
}

stock PrecacheSoundList(const String:szFileList[][], iSize)
{
    for (new i = 0; i < iSize; i++)
    {
        PrecacheSound(szFileList[i], true);
    }
}

// Adds both a .vmt and .vtf to downloads - must exclude extension
stock PrepareMaterial(const String:szMaterialPath[])
{
    decl String:s[PLATFORM_MAX_PATH];
    Format(s, sizeof(s), "%s%s", szMaterialPath, ".vtf");
    AddFileToDownloadsTable(s);
    Format(s, sizeof(s), "%s%s", szMaterialPath, ".vmt");
    AddFileToDownloadsTable(s);
}

stock DownloadMaterialList(const String:szFileList[][], iSize)
{
    decl String:s[PLATFORM_MAX_PATH];
    for (new i = 0; i < iSize; i++)
    {
        strcopy(s, sizeof(s), szFileList[i]);
        AddFileToDownloadsTable(s); // if (FileExists(s, true))
    }
}

stock PrepareModel(const String:szModelPath[], bool:bMdlOnly = false)
{
    decl String:szBase[PLATFORM_MAX_PATH];
    decl String:szPath[PLATFORM_MAX_PATH];
    strcopy(szBase, sizeof(szBase), szModelPath);
    SplitString(szBase, ".mdl", szBase, sizeof(szBase));
    
    if (!bMdlOnly)
    {
        Format(szPath, sizeof(szPath), "%s.phy", szBase);
        if (FileExists(szPath, true))
        {
            AddFileToDownloadsTable(szPath);
        }
        
        Format(szPath, sizeof(szPath), "%s.sw.vtx", szBase);
        if (FileExists(szPath, true))
        {
            AddFileToDownloadsTable(szPath);
        }
        
        Format(szPath, sizeof(szPath), "%s.vvd", szBase);
        if (FileExists(szPath, true))
        {
            AddFileToDownloadsTable(szPath);
        }
        
        Format(szPath, sizeof(szPath), "%s.dx80.vtx", szBase);
        if (FileExists(szPath, true))
        {
            AddFileToDownloadsTable(szPath);
        }
        
        Format(szPath, sizeof(szPath), "%s.dx90.vtx", szBase);
        if (FileExists(szPath, true))
        {
            AddFileToDownloadsTable(szPath);
        }
    }
    
    AddFileToDownloadsTable(szModelPath);
    
    return PrecacheModel(szModelPath, true);
}

/*
    Returns the the TeamNum of an entity.
    Works for both clients and things like healthpacks.
    Returns -1 if the entity doesn't have the m_iTeamNum prop.

    GetEntityTeamNum() doesn't always return properly when tf_arena_use_queue is set to 0
*/
stock GetEntityTeamNum(iEnt)
{
    // if (GetEntSendPropOffs(iEnt, "m_iTeamNum") <= 0)
    // {
    //     return -1;
    // }
    return GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
}

// TODO: Implement this stuff

/*
    Common check that says whether or not a client index is occupied.
*/
stock bool:IsValidClient(iClient)
{
    return (0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}

/*
    Common checks that says "this player can safely be selected from a queue of players"
*/
stock bool:IsClientParticipating(iClient)
{
    if (IsSpectator(iClient) || IsReplayClient(iClient))
    {
        return false;
    }
    
    if (false)  // TF2C: no coaching 
    {
        return false;
    }
    
    if (TF2_GetPlayerClass(iClient) == TFClass_Unknown)
    {
        return false;
    }
    
    return true;
}

stock bool:IsSpectator(iClient)
{
    return GetEntityTeamNum(iClient) <= TEAM_SPEC;
}

stock bool:IsReplayClient(iClient)
{
    return IsClientReplay(iClient) || IsClientSourceTV(iClient);
}

/*
    Returns the number of times any team has won a round.
*/
stock TF2_GetRoundWinCount()
{
    return GetTeamScore(TEAM_RED) + GetTeamScore(TEAM_BLU);
}

stock ClearTimer(&Handle:hTimer)
{
    if (hTimer != INVALID_HANDLE)
    {
        KillTimer(hTimer);
        hTimer = INVALID_HANDLE;
    }
}

/*
    TeleportToMultiMapSpawn()

    [X][2]
       [0] = RED spawnpoint entref
       [1] = BLU spawnpoint entref
*/
static Handle:s_hSpawnArray = INVALID_HANDLE;

stock OnPluginStart_TeleportToMultiMapSpawn()
{
    s_hSpawnArray = CreateArray(2);
}

stock teamplay_round_start_TeleportToMultiMapSpawn()
{
    ClearArray(s_hSpawnArray);

    new iInt = 0;
    new iSkip[TF_MAX_PLAYERS] = {0,...};

    new iEnt = MaxClients + 1;
    while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
    {
        // if (FindValueInArrayAnyEx(s_hSpawnArray, iEnt) != -1) // If already in the array, don't add it again
        // {
        //     //CPrintToChdata("not added spawn %i", iEnt);
        //     continue;
        // }

        new iTeam = GetEntityTeamNum(iEnt);
        new iClient = GetClosestPlayerTo(iEnt, iTeam);

        if (iClient)
        {
            new bool:bSkip = false;
            for (new i = 0; i < TF_MAX_PLAYERS; i++)
            {
                if (iSkip[i] == iClient)
                {
                    bSkip = true;
                    break;
                }
            }
            if (bSkip)
            {
                continue;
            }
            iSkip[iInt++] = iClient;
            new iIndex = PushArrayCell(s_hSpawnArray, iEnt);
            SetArrayCell(s_hSpawnArray, iIndex, iTeam, 1);       // Opposite team becomes an invalid ent
            //CPrintToChdata("spawn %i near %N added to team %i", iEnt, iClient, iTeam);
        }
    }
}

/*
    Teleports a client to spawn, but only if it's a spawn that someone spawned in at the start of the round.

    Useful for multi-stage maps like vsh_megaman
*/
stock TeleportToMultiMapSpawn(iClient, iTeam = 0)
{
    if (GetArraySize(s_hSpawnArray) <= 0)
        return -1;

    decl iSpawn, iTeleTeam, iIndex;
    if (iTeam <= 1)
    {
        iSpawn = GetRandBlockCellEx(s_hSpawnArray);
    }
    else
    {
        do
        {
            iTeleTeam = GetRandBlockCell(s_hSpawnArray, iIndex, 1);
        }
        while (iTeleTeam != iTeam);

        iSpawn = GetArrayCell(s_hSpawnArray, iIndex, 0);
    }
    TeleMeToYou(iClient, iSpawn);
    return iSpawn;
}

/*
    Returns 0 if no client was found.
*/
stock GetClosestPlayerTo(iEnt, iTeam = 0)
{
    new iBest;
    decl Float:flDist, Float:flTemp;
    decl Float:vLoc[3], Float:vPos[3];
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vLoc);
    for(new iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
        {
            if (iTeam && GetEntityTeamNum(iClient) != iTeam)
            {
                continue;
            }
            
            GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vPos);
            flTemp = GetVectorDistance(vLoc, vPos);
            if (!iBest || flTemp < flDist)
            {
                flDist = flTemp;
                iBest = iClient;
            }
        }
    }
    return iBest;
}

/*
    Teleports one entity to another.
    Doesn't necessarily have to be players.

    Returns true if a player teleported to a ducking player
*/
stock bool:TeleMeToYou(iMe, iYou, bool:bAngles = false)
{
    decl Float:vPos[3], Float:vAng[3];
    GetEntPropVector(iYou, Prop_Send, "m_vecOrigin", vPos);

    if (bAngles)
    {
        GetEntPropVector(iYou, Prop_Send, "m_angRotation", vAng);
    }

    new bool:bDucked = false;

    if (IsValidClient(iMe) && IsValidClient(iYou) && GetEntProp(iYou, Prop_Send, "m_bDucked"))
    {
        decl Float:vCollisionVec[3];
        vCollisionVec[0] = 24.0;
        vCollisionVec[1] = 24.0;
        vCollisionVec[2] = 62.0;
        SetEntPropVector(iMe, Prop_Send, "m_vecMaxs", vCollisionVec);
        SetEntProp(iMe, Prop_Send, "m_bDucked", 1);
        SetEntityFlags(iMe, GetEntityFlags(iMe) | FL_DUCKING);
        bDucked = true;
    }
    
    TeleportEntity(iMe, vPos, bAngles ? vAng : NULL_VECTOR, NULL_VECTOR);

    return bDucked;
}

stock GetRandBlockCell(Handle:hArray, &iSaveIndex, iBlock = 0, bool:bAsChar = false, iDefault = 0)
{
    new iSize = GetArraySize(hArray);
    if (iSize > 0)
    {
        iSaveIndex = GetRandomInt(0, iSize - 1);
        return GetArrayCell(hArray, iSaveIndex, iBlock, bAsChar);
    }
    iSaveIndex = -1;
    return iDefault;
}

// Get a random value while ignoring the save index.
stock GetRandBlockCellEx(Handle:hArray, iBlock = 0, bool:bAsChar = false, iDefault = 0)
{
    decl iIndex;
    return GetRandBlockCell(hArray, iIndex, iBlock, bAsChar, iDefault);
}

/*
    Chdata's reworked attachparticle
*/
stock AttachParticle(iEnt, const String:szParticleType[], Float:flTimeToDie = -1.0, Float:vOffsets[3] = {0.0,0.0,0.0}, bool:bAttach = false, Float:flTimeToStart = -1.0)
{
    new iParti = CreateEntityByName("info_particle_system");
    if (IsValidEntity(iParti))
    {
        decl Float:vPos[3];
        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
        AddVectors(vPos, vOffsets, vPos);
        TeleportEntity(iParti, vPos, NULL_VECTOR, NULL_VECTOR);

        DispatchKeyValue(iParti, "effect_name", szParticleType);
        DispatchSpawn(iParti);

        if (bAttach)
        {
            SetParent(iEnt, iParti);
            SetEntPropEnt(iParti, Prop_Send, "m_hOwnerEntity", iEnt);
        }

        ActivateEntity(iParti);

        if (flTimeToStart > 0.0)
        {
            decl String:szAddOutput[32];
            Format(szAddOutput, sizeof(szAddOutput), "OnUser1 !self,Start,,%0.2f,1", flTimeToStart);
            SetVariantString(szAddOutput);
            AcceptEntityInput(iParti, "AddOutput");
            AcceptEntityInput(iParti, "FireUser1");

            if (flTimeToDie > 0.0)
            {
                flTimeToDie += flTimeToStart;
            }
        }
        else
        {
            AcceptEntityInput(iParti, "Start");
        }

        if (flTimeToDie > 0.0) 
        {
            killEntityIn(iParti, flTimeToDie); // Interestingly, OnUser1 can be used multiple times, as the code above won't conflict with this.
        }

        return iParti;
    }
    return -1;
}

stock SetParent(iParent, iChild)
{
    SetVariantString("!activator");
    AcceptEntityInput(iChild, "SetParent", iParent, iChild);
}

stock killEntityIn(iEnt, Float:flSeconds)
{
    decl String:szAddOutput[32];
    Format(szAddOutput, sizeof(szAddOutput), "OnUser1 !self,Kill,,%0.2f,1", flSeconds);
    SetVariantString(szAddOutput);
    AcceptEntityInput(iEnt, "AddOutput");
    AcceptEntityInput(iEnt, "FireUser1");
}

/*
    Start of smlib functions
*/
#if !defined _smlib_included
/* SMLIB
 * Precaches the given particle system.
 * It's best to call this OnMapStart().
 * Code based on Rochellecrab's, thanks.
 *
 * @param particleSystem    Name of the particle system to precache.
 * @return                  Returns the particle system index, INVALID_STRING_INDEX on error.
 */
stock PrecacheParticleSystem(const String:particleSystem[])
{
    static particleEffectNames = INVALID_STRING_TABLE;

    if (particleEffectNames == INVALID_STRING_TABLE) {
        if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
            return INVALID_STRING_INDEX;
        }
    }

    new index = FindStringIndex2(particleEffectNames, particleSystem);
    if (index == INVALID_STRING_INDEX) {
        new numStrings = GetStringTableNumStrings(particleEffectNames);
        if (numStrings >= GetStringTableMaxStrings(particleEffectNames)) {
            return INVALID_STRING_INDEX;
        }

        AddToStringTable(particleEffectNames, particleSystem);
        index = numStrings;
    }

    return index;
}

/* SMLIB
 * Rewrite of FindStringIndex, because in my tests
 * FindStringIndex failed to work correctly.
 * Searches for the index of a given string in a string table.
 *
 * @param tableidx      A string table index.
 * @param str           String to find.
 * @return              String index if found, INVALID_STRING_INDEX otherwise.
 */
stock FindStringIndex2(tableidx, const String:str[])
{
    decl String:buf[1024];

    new numStrings = GetStringTableNumStrings(tableidx);
    for (new i=0; i < numStrings; i++) {
        ReadStringTable(tableidx, i, buf, sizeof(buf));

        if (StrEqual(buf, str)) {
            return i;
        }
    }

    return INVALID_STRING_INDEX;
}
#endif

/*
    Converts the many gunmettle indices to whatever the default is

    TODO: Throw botkillers into this category
*/
stock GunmettleToIndex(iGun, iClass = -1)
{
    switch (iGun)
    {
        case 15000, 15007, 15019, 15023, 15033, 15059: return TFWeapon_SniperRifle;
        case 15001, 15022, 15032, 15037, 15058: return TFWeapon_SMG;
        case 15002, 15015, 15021, 15029, 15036, 15053: return TFWeapon_Scattergun;
        case 15003, 15016, 15044, 15047:
        {
            switch (iClass)
            {
                case TFClass_Soldier: return TFWeapon_ShotgunSoldier;
                case TFClass_Pyro: return TFWeapon_ShotgunPyro;
                case TFClass_Heavy: return TFWeapon_ShotgunHeavy;
                case TFClass_Engineer: return TFWeapon_ShotgunEngie;

            }
            return TFWeapon_Shotgun;
        }
        case 15004, 15020, 15026, 15031, 15040, 15055: return TFWeapon_Minigun;
        case 15005, 15017, 15030, 15034, 15049, 15054: return TFWeapon_Flamethrower;
        case 15006, 15014, 15028, 15043, 15052, 15057: return TFWeapon_RocketLauncher;
        case 15008, 15010, 15025, 15039, 15050: return TFWeapon_Medigun;
        case 15009, 15012, 15024, 15038, 15045, 15048: return TFWeapon_StickyLauncher;
        case 15011, 15027, 15042, 15051: return TFWeapon_Revolver;
        case 15013, 15018, 15035, 15041, 15046, 15056:
        {
            switch (iClass)
            {
                case TFClass_Scout: return TFWeapon_PistolScout;
                case TFClass_Engineer: return TFWeapon_PistolEngie;
            }
            return TFWeapon_Pistol;
        }
    }
    return TFWeapon_Invalid;
}

stock bool:StrStarts(const String:szStr[], const String:szSubStr[], bool:bCaseSensitive = true)
{
    return !StrContains(szStr, szSubStr, bCaseSensitive);
}

stock bool:IsWeaponSlotActive(iClient, iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}