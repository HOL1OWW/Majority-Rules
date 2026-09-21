# Brand

**Read this before you make an icon, a thumbnail, a UI, a mascot model or a shop item.** Four
contributors produce brand-adjacent assets; this is the file that stops them diverging.

## Name and store page

**MAJORITY RULES 🗳️ Vote The Arena** — ~39 of the 50 allowed characters.

The name is uncontested on Roblox, which cuts both ways: nobody is confusing us with someone
else, and there is **no existing search demand behind the words**. So discovery has to be
carried by the honest descriptive tail and by the thumbnails, not by the brand.

Roblox search ranks on keyword match in title/description/genre *plus* engagement, and actively
deprioritises keyword stuffing, giveaway-leading metadata and near-duplicate names. So: no
"FREE", no reward words, no keyword dump.

**Description.** Only the first two lines show before the fold.

> 8 players load into an empty arena. Everyone votes on what happens to it — low gravity, fog,
> shotguns only — then it physically rebuilds itself in front of you.
> 6 rounds. Every round wilder than the last. Whatever wins, you fight in it. Free on all devices.

Then a body with honest keyword coverage (*vote, voting, arena, PvP, chaos, modifiers, low
gravity, fog, shotguns, party, funny, random, transform, free-for-all*), a short
how-it-works, an updates section, and social links. Off-platform links are restricted — use only
`AllowedExternalLinkReferences` from `PolicyService`, never a raw URL.

**Findability plumbing people forget:** set the genre, enable **all** supported devices
(console is free audience), confirm the experience guidelines/age labelling (required before ads
and some monetisation), and set max players to 8.

## The Clerk

A brass-and-glass ballot-box robot: tally-bar face, tiny arms, a rubber stamp.

The Clerk hosts the vote, clicks the tally per vote, slams APPROVED stamps as the arena flips,
taunts on kills, delivers the round verdict, and runs the lobby shop.

It is the highest-ROI asset in the project because **the transform moment is already the clip** —
the Clerk just has to be in frame when it happens. It also gives a small team one big personality
instead of eight half-finished ones. Build it early, build it once.

## Art direction: bureaucracy gone feral

Clean government-paperwork surfaces that have lost their mind. It is distinctive, cheap to
produce (flat shapes, no complex art), and it scales to unlimited modifiers because **every
modifier is just another checkbox on a form.**

* Paper cards, hard rules, official-looking labels.
* Rubber-stamp rotations, ink bleed, screen-shake on the commit frame.
* Ripped-paper wipes instead of generic fades.
* Motion language: *pending* (grey, dashed) → *stamped* (rotated, ink) → *verdict* (shake, whoosh).

## Palette

| Role | Hex | Use |
| --- | --- | --- |
| Ink | `#18191E` | Text on paper |
| Graphite | `#20232A` | Primary surfaces |
| Graphite soft | `#32363F` | Cards |
| Paper | `#F0ECE2` | Paper surfaces, primary text |
| Accent | `#D6FF3F` | **The vote moment.** Used sparingly, never as decoration |
| Verdict gold | `#FFC53D` | THE VERDICT, match winner, the Gamble card |
| Gravity | `#7C6BFF` | Category |
| Combat | `#FF4D4D` | Category, kills, danger |
| Environment | `#2FD08C` | Category |
| Chaos | `#FF2FB0` | Category |
| Spatial | `#4FB3FF` | Category |
| Loadout | `#FF9F45` | Category |
| Mobility | `#5FE1E1` | Category |
| Vision | `#9AA4B8` | Category |

These are mirrored in `StarterPlayer/StarterPlayerScripts/MajorityRulesClient/UI/Theme.lua` — that file is the implementation, this table is
the intent. Change both or neither.

## Type

Two families, both **built-in Roblox fonts**, so the game renders identically everywhere with
nothing to upload:

* `Enum.Font.GothamBlack` — display: card names, verdicts, countdowns, the word APPROVED.
* `Enum.Font.GothamBold` / `GothamMedium` — headings and body.
* `Enum.Font.Code` — numbers in the scoreboard.

## Sound identity

A single audio logo: a **stamp thud**. Then reuse it forever.

| Cue | Where |
| --- | --- |
| Stamp thud | The game's audio logo; the verdict landing |
| Tally click | One per vote cast |
| Ballot-box rumble | Rising through the transform |
| Gavel hit | End of countdown |
| Music bed | Per modifier family; the bed switches with the vote |

Real asset ids are not authored yet. This is why `AudioService` (server) has an empty bed/cue
table and never errors: **fill in the ids, and every modifier that asked for a bed gets one.**

## Store assets

**Icon** — square, ≥512×512, ship 1024. One subject, ≤3 words (or none: the title sits beside it
everywhere). The Clerk bursting out of a ballot box, arena silhouetted behind, stamp descending.
**Test it at 48px and squint.** If the subject is not readable, it is not done.

**Thumbnails** — 1920×1080, 16:9, upload 8+. Roblox personalisation rotates them per user
automatically, so the strategy is **diversity, not hand-run A/B tests**. All real in-engine
shots, avatar faces visible, ≤4 words of text.

1. The vote screen: live tallies, eight avatars, cards readable
2. Mid-transform: floor slabs rising, debris, lightning, players shielding their faces
3. The Clerk stamping `FOG WINS` over the arena
4. Low gravity: avatars floating mid-firefight
5. Shotguns only: point-blank blast
6. Fog arena: silhouettes, moody, sparse
7. Lava and collapse chaos
8. Round 6 `THE VERDICT` banner in gold

Never imply a reward, never reuse another game's art, never mismatch thumbnail to gameplay —
Roblox suppresses all three.

## What the discovery algorithm actually rewards

Roblox's own documentation, translated into design consequences:

| Signal | Consequence for us |
| --- | --- |
| Ranking is **per-user averages**, so small engaged games are not disadvantaged | A small returning audience beats a launch spike. Optimise for D8–28. |
| **Play-through rate** and **first-play bounce** (bucketed <60s, 61–180s) are the heaviest signals | The arena must transform within 60s of joining, even solo. That is why Skirmish exists. |
| **Play days per user**, D1 / D2–7 / D8–28 | The modifier mastery dex is a retention feature, not a nice-to-have. |
| **Playtime per user**, capped at 60 min/day | Target 20–30 minute sessions; 6-round matches with a strong "next match" hook. |
| **Intentional co-play days** | Party join, private servers, "your friend voted FOG, go overrule them" invite copy. |
| **Spend days / Robux per user** | Cheap entry cosmetics (25–75 R$) + the seasonal pass. Never power. |
| Users from ads, search, curation and friends **do not count** toward ranking | Ads buy consideration, not ranking. Spend to seed co-play, then let retention carry it. |
| **Updates are an input to impressions** | Ship something visible weekly. |

Also: Roblox hand-curates **Standout Games** for novel mechanics and distinctive styles. This
game qualifies on both counts — that application is a launch checklist item, not an afterthought.

## Launch checklist (brand side)

- [ ] Name claimed in the Creator Dashboard; near-duplicate search re-checked
- [ ] Description written with the fold in mind; keyword check against reality, not aspiration
- [ ] Genre set, all devices enabled, experience guidelines complete
- [ ] Icon shipped at 1024 and verified at 48px
- [ ] 8 thumbnails uploaded, all real screenshots
- [ ] The Clerk in the transform shot
- [ ] Sound identity authored and ids filled into `AudioService`
- [ ] Weekly visible update cadence scheduled
- [ ] Standout Games curation application drafted
