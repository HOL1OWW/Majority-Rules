# 14 — Map building for absolute beginners

Every click spelled out. Written for someone who has never used Roblox Studio, GitHub, or this
project before. If a step says "you will see" and you see something different, stop and ask in the
chat — do not guess.

---

## Words you need (60 seconds)

- **Roblox Studio** — the program where the game is built. Blue icon, black square.
- **The place** — "The Vote", your game's world file. It lives on Roblox's servers, which is why
  two people can open the same world at once.
- **Explorer** — a panel in Studio listing everything in the game as a tree, like folders.
- **Workspace** — the tree item meaning "visible in the 3D view right now".
- **ServerStorage** — the tree item meaning "hidden storage". Things here are real but invisible.
- **Foundry** — the arena model. The entire map is this one item.
- **HandAuthored** — a switch on the Foundry model meaning "humans own this now; code must never
  rebuild it". Already ticked. Do not untick unless told to.
- **"publish"** — the word you type to Buffy (in the Freebuff chat) to copy all changes to GitHub.
- **GitHub** — the online backup and history of every file. You never touch it; Buffy handles it.

---

## PART 1 — One-time setup

### 1A. You (the person with the Freebuff chat)

1. Open **Roblox Studio**. A "recent places" screen appears. Double-click **The Vote**.
2. Two panels must be visible on the right:
   - No panel titled **Explorer**? → click the **View** tab at the top → click **Explorer**.
   - No panel titled **Properties**? → same **View** tab → click **Properties**.
3. Confirm the arena exists: in Explorer, find the line **ServerStorage**, click the small ▶ arrow
   to its left. Under it find **Arenas** and expand it. You should see **Foundry**. If you don't,
   stop and tell Buffy.
4. **Save the place now**: press **Ctrl+S** (or File → Save to Roblox). The arena that was built
   for you only exists in your open session until you do this.
5. **Make the GitHub copy** (you only):
   - In Explorer, **right-click** **Foundry** → click **Save to File…** — a Windows save window opens.
   - Navigate to `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote\assets\arenas`
   - File name: `Foundry.rbxmx`. In **Save as type**, pick the option ending in `.rbxmx`
     (Roblox Model XML). If only one "Roblox Model Files" entry exists, make sure the file name
     still ends in `.rbxmx`.
   - It asks to replace the old file → **yes, replace**.
6. Type **publish** in the Freebuff chat. Buffy commits and pushes, then confirms.

### 1B. Your brother (once)

1. You invite him: Studio → **Home** tab → **Game Settings** → **Permissions** → add his Roblox
   username with **Edit** access.
2. He opens Roblox Studio → **File → Open from Roblox** → picks **The Vote**. He is now inside the
   same world as you — you'll see his name and cursor in the editor while you're both open.

That is all he needs. No GitHub, no VS Code, nothing to install.

---

## PART 2 — Every time you want to edit the map (both of you)

1. **Open the place** (as in Part 1). Make sure you are in **Edit** mode: if the big **Play**
   button is active or a red **Stop** is showing, click **Stop**. In Edit mode you look down on the
   world like a diorama.
2. **Make the arena visible.** In Explorer find `ServerStorage → Arenas → Foundry`. Click and
   **hold** the Foundry row, drag it onto the word **Workspace**, release. The 3D view now shows
   the whole town hall. This drag is safe and repeatable — Workspace just means "visible".
   - The world will look like evening (dark blue sky). That is the arena's designed mood, not a
     fault. For daylight while building: click **Lighting** in Explorer, then in Properties find
     **ClockTime**, change it to **14**, press Enter.
3. **Build.** The basics:
   - **Move something**: click it in the 3D view → use the **Move**, **Scale**, **Rotate** tools in
     the **Model** or **Home** tab → drag the colored arrows that appear.
   - **New block**: Home tab → **Part** → it drops into the world → Scale/Move it into place → in
     Properties tick **Anchored** so it never falls.
   - **Recolor**: click the part → Properties → **Color** → pick.
   - **Undo**: **Ctrl+Z**, as many steps as you need.
   - **Never insert a Script** into Foundry, and don't paste toolbox models that contain scripts.
4. **Put the arena back.** Drag the Foundry row from Workspace onto `ServerStorage → Arenas`
   (drop it exactly on **Arenas**). The 3D view empties — correct; hidden is where it lives.
5. **Save**: **Ctrl+S**.
6. **You** repeat the export from 1A step 5 (right-click → Save to File → same folder, replace),
   then type **publish**. **Your brother does nothing more** — his edits are already in the shared
   place, and the publish picks them up automatically.

---

## PART 3 — What "publish" actually does

You type the word. Buffy compares everything in Studio with the project folder on disk, copies over
what changed (your map export, any script either of you edited), records a checkpoint in git, and
uploads it to GitHub. Then it reports back. You never name files or run anything.

---

## PART 4 — When something looks wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The 3D view is empty | Arena is hidden in ServerStorage (normal) | Drag Foundry into Workspace |
| Sky is dark | The arena's dusk design | Lighting → ClockTime → 14 |
| Two arenas after pressing Play | You played while Foundry sat in Workspace | Stop. Drag your Foundry back into Arenas. Delete the loose copy in Workspace — or ask Buffy to clean it |
| All my edits vanished after Play | HandAuthored got unticked, or the place wasn't saved first | Tell Buffy immediately. Always Ctrl+S *before* pressing Play |
| Brother's changes don't appear | Team Create lag, or he's mid-edit | Wait a few seconds; he should Ctrl+S too |
| Buffy's code fixes don't appear | A Play session was running when they were pushed | Stop Play, then press Play again |
| Ctrl+Z isn't enough | — | Tell Buffy what broke; git history can restore anything |

---

## PART 5 — Before calling a map done (the one paste)

1. Drag Foundry back into `Arenas` (Part 2, step 4).
2. **View** tab → click **Command Bar** — a long white bar opens at the bottom of Studio.
3. Paste exactly this and press Enter:

```lua
require(ServerStorage.Tools.ArenaValidator).report(game.ServerStorage.Arenas:FindFirstChild("Foundry"))
```

4. You want the word **PASS**. If it says FAIL, copy the output into the chat — it lists exactly
   what to fix.

---

## The loop in one line

**Drag out → build → drag back → Ctrl+S → (you: export) → type "publish".**
