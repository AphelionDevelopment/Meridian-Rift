// Station self-destruct sequence. Every number here is measured against the announcement track,
// so if that track is re-cut these have to move with it.

/// Total run time of the announcement, and therefore of the whole sequence. 11:45.
#define SELF_DESTRUCT_DURATION (11 MINUTES + 45 SECONDS)

/// [SELF_DESTRUCT_DURATION] in seconds, the unit the terminal's own timer uses.
#define SELF_DESTRUCT_DURATION_SECONDS (SELF_DESTRUCT_DURATION / (1 SECONDS))

/// Where the announcement says the option to cancel has expired. 5:58.
#define SELF_DESTRUCT_POINT_OF_NO_RETURN (5 MINUTES + 58 SECONDS)

/// The cinematic's 3-2-1, which runs before the station goes up. We fire the terminal this early so
/// the countdown lands on the end of the track instead of after it.
/// This is the real length of intro_nuke - three one second frames - not the 3.5 the stock
/// /datum/cinematic/nuke/play_cinematic() waits. See the persistent cinematic, which drops the extra.
#define SELF_DESTRUCT_CINEMATIC_INTRO (3 SECONDS)

/// Delay between secondary detonations at the start of the terminal phase.
#define SELF_DESTRUCT_BLAST_INTERVAL_START (8 SECONDS)

/// Delay between secondary detonations by the time the terminal goes off.
#define SELF_DESTRUCT_BLAST_INTERVAL_END (0.5 SECONDS)

/// How far a secondary detonation carries as a bang, past which it is a distant rumble.
#define SELF_DESTRUCT_BLAST_AUDIBLE_RANGE 60

/// Chance a secondary detonation is heard across the whole station rather than only nearby.
/// Every blast reaching every player is one guaranteed sound each, and by the tail end that is a
/// constant stream fighting the announcement for the client's voices.
#define SELF_DESTRUCT_BLAST_ECHO_PROB 35

/// Priority on the secondary detonation sounds, deliberately near the floor. If a client has to drop
/// something when the blasts get dense, it should be a blast and never the announcement.
#define SELF_DESTRUCT_BLAST_SOUND_PRIORITY 1

/// Chance a secondary detonation lands near somebody rather than anywhere on the station.
#define SELF_DESTRUCT_BLAST_NEAR_CREW_PROB 50

/// How far from that person it lands. Outside the blast rings, so it is scenery rather than a kill.
#define SELF_DESTRUCT_BLAST_CREW_RANGE_MIN 7
#define SELF_DESTRUCT_BLAST_CREW_RANGE_MAX 13
