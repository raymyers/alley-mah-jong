# Game Feature Design

## Overview

A Game is a series of rounds. Each player starts with a score (default 3550, editable). The Game screen is the home screen, showing round summaries with running scores. Users can navigate into any round to view or edit it.

## Data Model

### Game

- `starting_score`: Int (default 3550, set at game start)
- `names`: 4 player names (set once for the game)
- `rounds`: List of Round records
- `editing_round`: Option(Int) - index of round being edited, if any

### Round

- `east_wind`: Player
- `prevailing_wind`: Wind
- `winner`: Option(Player) - None if round not yet decided
- `hands`: 4 PlayerHands
- `doubles`: 4 DoublesContexts
- `hand_statuses`: 4 HandStatuses

Scores, payouts, and running totals are **derived** at render time - not stored. Edits to any round automatically cascade to subsequent running totals.

## UI / Navigation

### Pages

1. **Game Screen (Home)**
   - If no game: "New Game" button prompts for starting score and player names
   - If game exists:
     - Player names with current running scores at top
     - Detailed round summaries (scores, payouts, running totals)
     - Each round clickable to open Round screen
     - "New Round" button (disabled if last round has no winner)
     - "New Game" button (with confirmation)

2. **Round Screen**
   - Current scoring UI with "Back to Game" link
   - Shows round number in header
   - Past rounds show confirmation banner before editing

3. **Rules Page** - Unchanged

### Round Summary Display

```
Round 1 - Winner: Alice
┌─────────┬───────┬─────────────────────┬─────────┐
│ Player  │ Score │ Payout              │ Running │
├─────────┼───────┼─────────────────────┼─────────┤
│ Alice ★ │ 100   │ +300 received       │ 3850    │
│ Bob (E) │ 64    │ -148 / +128 = -20   │ 3530    │
│ Carol   │ 32    │ -180 / +64 = -116   │ 3434    │
│ Dave    │ 16    │ -196 / +32 = -164   │ 3386    │
└─────────┴───────┴─────────────────────┴─────────┘
```

- Winner marked with star
- East marked with (E)
- Payout: paid / received = net (winner shows +received only)
- Running total cumulative through that round

## East Wind Rotation

When creating a new round:

- Round 1: East defaults to Player 1, prevailing wind to East
- Round N+1:
  - If previous winner == previous East: East stays the same
  - Otherwise: East rotates to next player (1→2→3→4→1)
  - When East rotates from Player 4 to Player 1: prevailing wind advances (East→South→West→North)

All auto-set values can be manually overridden.

## Storage

- Full Game state saved to localStorage (replaces old round-only storage)
- Old localStorage data discarded on migration
- Game state saves after every action

## Implementation Tasks

1. Add Game and Round types to engine
2. Add running score calculation to engine (with tests)
3. Add East/prevailing wind rotation logic to engine (with tests)
4. Update storage module for Game state
5. Add Game screen UI
6. Update Round screen to work within Game context
7. Add navigation between screens
8. Add "New Game" flow with starting score input
9. Add edit confirmation for past rounds
