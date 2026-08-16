# Code standards for agents

Derived from 3,656 inline review comments by `vinylspiders` across 551 NovaSector PRs — the review
corpus that shaped this codebase's conventions. Rewritten as rules an agent can apply and check.

Quotes are his, kept where they carry the reasoning more compactly than a paraphrase.

**Repo context this assumes:** this fork no longer continuously merges /tg/station. TG changes arrive
as manual batch ports. `code/` is inherited TG code (806 files carry `NOVA EDIT` markers),
`modular_nova/` is the inherited Nova layer, `modular_aphelion/` is this fork's own layer.

---

## 1. Where code goes — decide this first

Run this decision before writing anything.

```
Is the behavior genuinely new, self-contained fork content?
  -> modular_aphelion/modules/<module_id>/{code,icons,sound}/   (flat, no mirrored tree)

Is it a change to how an existing core thing behaves?
  Can it be expressed as a var override, a new var, a proc override,
  or an addition at the very start/end of a proc?
    -> modular_aphelion/master_files/<exact core path>
  Does it require changing logic in the middle of a core proc?
    -> marked inline edit in the core file (section 3)

Does it belong to existing Nova content?
  -> edit modular_nova/ in place, using NOVA EDIT grammar, not APHELION
```

**The rule that overrides the instinct to modularize:** do not copy a core proc into a modular file
to change part of it.

> "The full proc overrides with only a couple lines changed pattern is far worse to maintain than
> nova edits in cases like this, where you can do a single line edit"

> "Looking at this, it's mostly a copy paste of the tg proc... this whole thing would just be better
> suited overall as a 3-line nova edit... This is done correctly the modular way and all, but
> **modular is not always better for us**."

A copied proc diverges silently — the next TG batch port fixes a bug in the original and ours keeps
it, with nothing to signal that. A marked inline edit makes the divergence visible at the exact line
where a porter will be looking.

The "comment it out and note it moved elsewhere" pattern is rejected outright:

> "It is a nightmare to maintain these commented out 'moved to x file' style modules... Let's make it
> easier to see what those modifications are."

**Never override a wholesale list to change one entry.** Mutate the inherited list or derive from
`parent_type::the_var`.

> "when you are just trying to remove one flag, do this instead of copy pasting a massive list and
> overriding them. If TG adds more flags the hardcoded flags will be missing from our override."

---

## 2. Don't stack overrides

Before adding a modular override, grep for existing overrides of that proc. If one exists, add to it.

> "This is the 4th override of this proc now, it'd be better if these were condensed into one
> master_files override"

> "each new override that we create adds proc overhead and more importantly just makes the code harder
> to trace and maintain"

Overriding your own fork's override is always wrong — relocate the line to where the first override
lives.

---

## 3. Edit markers, and byte parity in core files

Markers are how a human porting a TG batch can tell fork code from inherited code at a glance. An
unmarked difference is invisible and will be silently reverted or duplicated by the next port.

```dm
// APHELION EDIT ADDITION START - MODULE_ID
...
// APHELION EDIT ADDITION END

/* // APHELION EDIT REMOVAL START - MODULE_ID
...
*/ // APHELION EDIT REMOVAL END

// APHELION EDIT CHANGE - ORIGINAL: <the full original line>
```

Rules he enforces:

- `CHANGE` is one line and must carry the complete original. A multi-line change is a REMOVAL block
  plus an ADDITION block — never a multi-line `CHANGE`.
- Every marker states its type and module id. *"Edit tags are not correct, it's not saying what type
  it is or anything"*
- One-liners take the single-line `CHANGE`/`ADDITION` form, not a start/end pair.
- Never put edit markers in a modular file. *"This is a modular file, not sure how this got the
  'addition' tag added to it but you can just delete it"*
- Preserve upstream `#undef`s rather than deleting them when a modular file needs the define:
  `//#undef FOO // NOVA EDIT REMOVAL - Used in <path>`

**Whitespace in core files is part of the contract.** He flags single stray spaces and editor-added
trailing newlines as undocumented edits:

> "Be mindful of extra whitespace, that will create diffs and conflicts and confuse maintainers."
> "The double whitespace is there on TG which stupid as it is means we have to have it too, or else
> that is an undocced edit."

**Agent check:** after touching anything under `code/`, diff it and confirm every differing byte is
either intentional-and-marked or reverted. Do not let a formatter or trim-on-save touch core files.
Files declared 1:1 with upstream must stay 1:1 — fork additions go in the corresponding modular file.

---

## 4. Use the existing proc

The single largest category of correction. Before writing a helper, search for one.

> "There are existing procs for this" · "We have one for this" · "You don't need a custom proc here
> there's already one for this"

Concrete instances, all of which are the same mistake:

- `copy_traits_from()` — not manual trait reassignment when swapping organs
- `transfer_quirk_datums()` — not `get_contents()` walking, *"so `add_unique()` actually gets respected"*
- `adjust_blood_volume()` / `set_blood_volume()` — never assign the var
- `is_species_appropriate()` — not a hand-rolled species check
- knockdown/stun helper procs — not direct status effect application
- list-mutating procs — *"Editing the list directly when there is a proc to do that should be avoided"*

**Why:** the setter exists because it also does the four things you forgot — signal sends, clamping,
`add_unique` semantics, HUD updates.

If a helper *almost* fits, extend the helper rather than forking it:

> "Why not just use the existing `makeHologram()` proc which this is likely copy pasted from? You can
> extend it to accept a `color` as an optional arg"

---

## 5. OOP over type-checking

Wherever behavior is selected by an `istype()` ladder or an `if/else if` chain on type, the codebase
wants polymorphism.

> "looking at all the type checking and whatnot you are doing here, this would be better suited to use
> OOP. Just define a `/obj/machinery/proc/tarkonize()`... Then you can just implement each machinery's
> assignments in each machinery's implementation instead."

> "a cleaner way of doing this would be to create a proc `/obj/item/gun/energy/proc/get_charge_message()`
> ... then override it for the subtypes that should get a message. You can then just override this proc
> as needed instead of overriding `examine()` for all of them directly."

Mapping:

| Smell | Fix |
|---|---|
| Behavior varies by type | Virtual proc on the base type, overridden per subtype |
| Membership varies by type | A flag/trait/var on the type, or a typecache — never a hardcoded path list, never `istype()` at the call site |
| Near-identical subtypes repeated | One parametrized base type; set only what actually differs |
| Abstract base needs blocking | `abstract_type` / `INITIALIZE_HINT_QDEL` — the machinery exists |

**Hand-curated lists are a standing rejection**, because they must be edited whenever content is
added and they will not be:

> "I am not a big fan of these big manually curated lists from a maintenance POV, it would be much
> better if there was some commonly identifiable flag that ideally just gets auto-marked... Just so we
> don't have to worry about adding things to it in the future (because it will be forgotten, trust me)."

> "you could add a `TRAIT_INTEGRATED_MODSUIT` that gets added by both this quirk and `inherent_traits`
> in the species datum. Then instead of this code you can do `mob_trait = TRAIT_INTEGRATED_MODSUIT`
> and it will automatically exclude proteans"

Typecaches are preferred over path lists for the same reason plus speed: *"more importantly that would
also handle any subtypes that get added."*

Also: datums that are templates must stay stateless. *"species datums are supposed to be templates and
not really handlers for stateful things at all"* — state belongs on the instance (organ, bodypart,
component), which also already has `owner`.

---

## 6. Signals and components

He rules both directions, and the distinction is consistent.

**Use a proc override, not a signal, when you control both sides.**
> "There is no need to inject here, you can simply do `/obj/machinery/post_machine_initialize()` ...
> Being able to override procs like this is the basis for our modularization. It is preferable to do it
> like this where possible instead of using signals. The only thing it will add is some proc overhead
> which is negligible in this case."

> "This is a case of overengineering, a signal *just* for this? Let's just check for the trait instead"

**Use a signal, not a hack or a poll, when you don't.**
> "I wanna avoid hacky things like this whenever possible. We do have a 'clean' way of doing this —
> `RegisterSignal(quirk_holder, COMSIG_MOB_GRANTED_ACTION, ...)`"

> "The right thing to do would be to move the dissolving and making a sound bit out of `Destroy()` and
> into a registration of `COMSIG_CARBON_REMOVE_LIMB`"

**`GetComponent()` to read state is an antipattern — always.**
> "Calling `GetComponent()` to access vars like this is an antipattern and should be avoided at
> basically all costs"

Instead, have the component register to the parent's signal (e.g. `COMSIG_ATOM_UPDATE_OVERLAYS`) and
act there, or move the var up to the base type.

**A component that is only a bag of vars should not be a component.** Conversely, a pile of proc
overrides implementing one coherent behavior should be:
> "These should really be a component rather than limb proc overrides. It already uses signals heavily,
> and afaik for basically ALL of these behaviors there exist signals to do what you need."

**Mechanical signal rules:**
- `SIGNAL_HANDLER` on every registered proc, without exception.
- `SIGNAL_HANDLER` procs cannot sleep — no `do_after`. Restructure; don't work around it.
- Every `RegisterSignal` needs `UnregisterSignal` on **every** teardown path: `Destroy()`,
  `on_remove()`, `remove()`, `end_processing()`, and any early-exit helper that undoes the setup.
  *"Don't forget to `UnregisterSignal` as well, both in `remove()` and in `remove_hydrophobia_action()`"*
- Components need `UnregisterFromParent` too.
- The signal already gives you the source as arg 1 and often `src` as arg 2 — don't pass them again,
  and don't store what the handler will be handed.
- Declare the full handler signature even for args you don't use.
- Never `SEND_SIGNAL` in a loop; use a global signal.
- `PROC_REF` / `TYPE_PROC_REF` / `GLOBAL_PROC_REF` always.

---

## 7. References, deletion, hard deletes

The cluster with live-server consequences. Read `.github/guides/HARDDELETES.md` before touching
`Destroy()` or anything holding a ref.

- **Never call `Destroy()` directly** — always `qdel()`. `QDEL_LIST` for lists.
- **Never `qdel()` an `image`** — dereference it and let BYOND collect it.
- **Don't clear refs another `Destroy()` already clears**, and don't `Remove()` an action or organ you
  are about to `qdel()` — *"when you qdel an action, it automatically will `Remove()` itself"*.
- **Never assume a weakref resolves.** Guard every resolve, and null the weakref when it stops
  resolving.
- **Timers outlive their owner.** *"You -should- be checking these things, because it's a timer and you
  aren't guaranteed to have `owner` at the end of it."* Use `TIMER_STOPPABLE|TIMER_DELETE_ME`, store
  the id, guard the callback body.
- **Watch for acting on things after deletion.** *"since you are registered to the pen moving, you can
  potentially move things after qdeletion when the mob is moved to nullspace... it's a very common
  cause of hard deletes (something being in a non-null loc after deletion)."*
- **Hard refs to long-lived atoms cause hard deletes on live.** Prefer a weakref, or register to
  `COMSIG_QDELETING` and null the ref there.
- `QDELETED()` already covers null — don't write `if(!isnull(x) && !QDELETED(x))`.
- `Destroy()` clears references and has no side effects. Undo in `Destroy()` exactly what
  `Initialize()` did.

---

## 8. `sleep`, `spawn`, and races

Deferred execution is treated as a design failure to be explained, not a tool.

> "Both ways are very smelly though. what is the exact race condition? surely there is a better way to
> be resolving this... In most cases there is another call stack you can hook into if there's like a
> sleep or something somewhere."

> "You should be using a timer with `varset_callback` for stuff like this. On top of this since this
> proc also holds up `on_life()` with its `sleep()` (cringe)..."

**Procedure when you hit a race:** name the exact call chain first. His model answer —
*"`give_round()` called in `item_interaction()`, which `ForceMove()`s the ammo, which prompts
`check_empty()`, which `qdel()`s `other_box`"* — then fix the chain. Fixing it properly usually
deletes the surrounding hack: *"By fixing the race condition through yielding that qdel, you remove
the need to do this snowflakey modular edit."*

`spawn(0)` is permitted only when the reason is real and written down in a comment. Never sleep in a
proc whose contract is immediate (`handle_speech`, signal handlers, `Life()` paths).

---

## 9. Performance, where it's actually flagged

- **`view()`/`oview()` once, not per-check.** *"Instead of calling `view()` or `oview()` over and over
  again (expensive!) you should call it once and do your separate checks as you iterate."* Use `oview`
  when the center tile should be excluded.
- **Typecaches for type-set membership**, not `in` over a path list.
- **Don't create timers you don't need.** *"Creating a timer's not free and this is just kinda a
  pointless waste of resources"* — if the delay is arbitrary, fold it into the existing timer or call
  the proc directly.
- **Don't process while idle.** Start processing on the event that makes work exist; stop when it
  doesn't.
- **Cheapest checks first** in a condition chain.
- **Don't hold round-long globals for data consumed immediately** — local vars, let the GC take it.
  Same for subsystem vars used once during a single run.
- **Never parse strings in `Life()`.** *"The gas strings are meant to be used for mapping."*
- **Loop once, not twice.**
- `process()` must be frame-independent: per-second values multiplied by `seconds_per_tick`.
- In genuinely hot procs, a marked inline edit is preferred over an override specifically to avoid
  override chaining overhead.

---

## 10. Style rules, enforced

| Rule | Note |
|---|---|
| Descriptive names; never `M`/`C`/`H` | *"No single letter vars please!"* |
| snake_case; underscores between words | |
| Time via `SECONDS` macro, never deciseconds | *"I wanted this to specifically be in terms of seconds so the math is more self-evident, instead of a magic 0.1"* |
| Units in the var name when not deciseconds | |
| No magic numbers — `#define` them | |
| `#define` any string referenced in more than one place | |
| Single-file defines declared at top, `#undef`'d at bottom | |
| Macros SCREAMING_SNAKE_CASE, parenthesized, hygienic | |
| Early returns over nesting | *"Make this an early return for `if(spent)` and you can unindent the rest"* |
| No single-line `if` blocks in DM | |
| Long lists and long strings go multiline | |
| Trailing comma on the last list entry | So adding an entry is a one-line diff, not two |
| New positional args go at the end of the signature | |
| Named args where the meaning isn't obvious | Accept the linter complaint; it's a wanted signal |
| Tabs; never spaces; never mid-line alignment | |
| Absolute type paths beginning with `/` | |
| `::` over `initial()` for static values | |
| `initial()` does not work on lists | *"You need an actual instantiated prototype to get the list from it"* |
| `length()` over `.len` | |
| `for (var/type/name as anything in list)` for homogeneous lists | |
| `static`, not `global` | |
| Explicit `return value` over bare `.`; `. = ..()` is the exception | |
| Never `usr`, never `:`, never string type paths, never `walk*()` | Use `SSmove_manager` |
| `locate(ref)` only when scoped to a list | |
| `item_interaction()` over `attackby()` | `attackby()` takes precedence and is being phased out |
| `update_appearance()` / `update_icon_state()`, never manual icon assignment | |
| One `to_chat()` per multiline blurb | *"18! `to_chat()` calls and 7 blank ones that are guaranteed to do nothing except runtime"* |
| Always handle the cancelled-input case | |
| No hardcoded pronouns | |
| `\improper` only when capitalized, only on atoms | |
| Avoid alists — currently bugged | Use a normal keyed list |
| New traits go in both trait lists, alphabetically | `_traits.dm` and `admin_tooling.dm` |
| New TGUI files start with the fork marker comment | |
| Delete commented-out code in modular files | |
| Blank lines to separate logical steps | *"helps with readability to break up the logical steps"* |

**"Cargo cult"** is his term for defensive code that does nothing — returning a value nothing reads,
re-sanitizing something already sanitized, guards for impossible states. He removes both the instance
*and its source*, "so we don't get more people copy pasting it."

**Dead branches** get caught: if an outer condition already constrains the type, an inner `istype()`
runs 100% of the time and its `else` is unreachable. Check that your guards can actually fail.

---

## 11. Documentation

The most repeated short comment in the entire corpus is some form of *"/// Doc please"*.

- `///` (three slashes) on **every** class-level var and every proc — this is what produces the
  hover text in VS Code. `/** */` blocks on classes and public procs: one-line summary, then detail,
  then `Arguments: * arg - meaning`.
- **The quality bar:** *"as a rule of thumb if you still have to read code to understand what the var
  does after reading the comment it's a fail."* Vague is a failure — *"'sub type to do stuff' tells me
  nothing."*
- Prefer self-documenting names so the doc adds information rather than restating the identifier.

**But narration is not wanted.** Discretionary comments explaining what the code plainly does get
deleted: *"They can see the git history if they want to learn this, no need to leave comments like
this."* Keep discretionary commentary at zero.

The comments that *are* mandatory encode what the code cannot:

1. **Why a value diverges from the original, including the original value.**
   > "A comment seals the intent of the override for posterity even if TG makes changes." — otherwise
   > nobody can tell later whether the override meant *cheaper* or *more expensive*.
2. **Why a surprising line exists**, so it doesn't get "cleaned up."
   > "would be good to have that in a comment explaining why that is in case anyone sees it and thinks
   > to try and remove it in the future"
3. **Non-obvious intent in an algorithm** — especially weighting, ordering, and off-by-design loops.

Standard to aim for, in his words: *"Literal and precise so 1 year from now when I or whoever is
looking at that who has absolutely forgotten everything about this will immediately know exactly what
to do."*

---

## 12. Verification

Compile before reporting done. Do not reason about whether DM will accept a change:

```
"/c/Program Files (x86)/BYOND/bin/dm.exe" tgstation.dme
```

~65s. Expect `0 errors` plus a small number of pre-existing `#warn` warnings about building via
BUILD.cmd.

Beyond compiling:

> "please test after each major change to avoid issues like this. This is almost definitely what was
> causing the lockups."
> "this is not even compiling at the moment — make sure you check after making changes that it still works"

**State explicitly what was and was not tested.** If a change is only compile-verified, say so. If
behavior was not exercised in-game, say so. Never imply verification that didn't happen.

---

## 13. Scope discipline

- **Unfinished content does not ship.** Commented-out or half-working entries become dead code and
  asset bloat. Leave them out; the branch history preserves them.
- **Unrelated work is a separate change.** *"The silicon interactions are kinda just thrown onto here,
  it should be its own separate PR."*
- **No speculative scaffolding.** Placeholder overrides that merely restate inherited values *"become
  no longer accurate"* and are rejected as clutter.
- **No unused hooks.** *"This signal isn't consumed by anything atm, do we still need it?"*
- **When a refactor makes old code redundant, delete it.** A recurring follow-up is simply *"So now,
  you can get rid of all of this."* Finish the cleanup in the same change.
- Behavior and balance changes need a changelog entry.
- Leave changes in the working tree — do not commit or push unless asked.

---

## 14. Player-facing work

If the change touches what players see or do, these are reviewed as hard as the code:

- Give feedback for actions — balloon alerts, sound, `visible_message`. Silent state changes read as
  bugs.
- Anything spammable needs a cooldown.
- Anything player-visible needs logging.
- Respect preference flags when broadcasting; `visible_message()` takes `ignored_mobs` for this.
- Settings a player would re-pick every round should be a preference, not a round-start prompt.
- Long descriptions get truncated in UI — keep them brief and move detail elsewhere.
- Prefer the mildest mechanic that achieves the intent (brief disorient over hard stun).
- Don't remove a thing's defining trait without replacing it with something.
- TGUI: tooltips on disabled controls; don't make non-interactive information clickable.

---

## Pre-submit checklist

1. Right location? (§1 decision tree) Did I copy a proc to change part of it? Convert to a marked
   inline edit.
2. Does an override of this proc already exist? Consolidate into it rather than adding another.
3. Every touched `code/` file byte-identical except for correctly-typed, module-tagged markers —
   whitespace and final newlines included.
4. Did I search for an existing proc/helper/setter before writing one?
5. `istype()` ladders, curated path lists, near-duplicate subtypes → virtual proc, flag/trait,
   typecache, parametrized base type.
6. Every `RegisterSignal` unregistered on every teardown path; `SIGNAL_HANDLER` on every handler; no
   `GetComponent()` var reads; no direct `Destroy()`; weakrefs guarded and nulled; timers stoppable
   and guarded.
7. Any `sleep`/`spawn`? Name the race, fix the chain, or comment why deferral is correct.
8. `///` on every new var and proc, each passing the "no need to read the code" test. Original values
   recorded in a comment wherever we diverge. No narration comments.
9. SECONDS not deciseconds; defines not magic numbers; early returns; multiline lists; trailing
   commas; no single-letter names.
10. Compiles with 0 errors. Dead code, debug leftovers, and unrelated changes removed. Testing status
    stated honestly.
