# Alley Mah-Jong Notation

Compact notation for representing game states in tests and data files.

## Scoring Items

Items in a player's hand. Listed as space-separated codes.

| Code | Description | Points |
|------|-------------|--------|
| `p` | Pung 2-8 (revealed) | 2 |
| `ph` | Pung Honors (revealed) | 4 |
| `hp` | Pung 2-8 (hidden) | 4 |
| `hph` | Pung Honors (hidden) | 8 |
| `k` | Kong 2-8 (revealed) | 8 |
| `kh` | Kong Honors (revealed) | 16 |
| `hk` | Kong 2-8 (hidden) | 16 |
| `hkh` | Kong Honors (hidden) | 32 |
| `bpw` | Bonus: Pair of Winds | 2 |
| `bpd` | Bonus: Pair of Dragons | 2 |
| `bf` | Bonus: Flower | 4 |

### Examples

```
p p ph        # Two simple pungs and one honors pung = 2+2+4 = 8 pts
hkh bf bf     # Hidden honors kong and two flowers = 32+4+4 = 40 pts
```

## Hand Status

| Code | Description |
|------|-------------|
| `dirty` | Not clean - scores 0 (unless winner with limit hand) |
| `clean` | Clean hand - one suit only, scores normally |
| `limit` | Limit hand - scores 500 (or 1000 for East) |

## Doubles

Doubles are flags that multiply the final score. Represented as a list of codes.

### Single Double Conditions (1 double = 2x)

| Code | Description |
|------|-------------|
| `dragon` | Has Pung or Kong of Dragon |
| `own_wind` | Has Pung or Kong of own wind |
| `prevail_wind` | Has Pung or Kong of prevailing wind |
| `own_flowers` | Has both own flowers |

Note: `clean` and `east` are derived from context, not specified in doubles.

### Triple Double Conditions (3 doubles = 8x)

| Code | Description |
|------|-------------|
| `red_flowers` | Has all 4 red flowers |
| `blue_flowers` | Has all 4 blue flowers |
| `pure` | Clean with no winds or dragons |

## Player Position

| Code | Description |
|------|-------------|
| `east` | Player is East Wind (dealer) |
| `south` | Player is South Wind |
| `west` | Player is West Wind |
| `north` | Player is North Wind |

## Winner Status

| Code | Description |
|------|-------------|
| `winner` | Player has Mah-jong'd (+20 pts bonus) |
| `-` | Player did not win |

## Test Case Format (CSV)

Test cases are stored in `test/cases/scoring.csv` with these columns:

| Column | Description |
|--------|-------------|
| `id` | Unique test identifier |
| `description` | Human readable explanation of the test and calculation |
| `items` | Space-separated scoring item codes |
| `status` | Hand status: dirty, clean, or limit |
| `doubles` | Space-separated double codes (optional) |
| `is_winner` | true or false |
| `is_east` | true or false |
| `points` | Expected final score after multiplier and cap |
| `multiplier` | Expected multiplier (2^doubles) |
| `doubles_count` | Expected total doubles count |

Example row:
```csv
double_dragon,Dragon pung/kong gives +1 double. 2 pts * 4x = 8,p,clean,dragon,false,false,8,4,2
```

## Calculation Order

1. Sum item points
2. Add 20 if winner (mahjong bonus)
3. Count doubles (clean adds 1, east adds 1 automatically)
4. Multiply by 2^doubles
5. Cap at 1000

## Special Cases

### Dirty Hands
- Always score 0 points
- Doubles don't apply
- Winner bonus doesn't apply

### Limit Hands
- Always score exactly 500 (or 1000 for East)
- Item points ignored
- Doubles don't apply
- Overrides normal calculation

### East Wind
- Automatically gets +1 double when clean
- Limit hands score 1000 instead of 500
- Pays/receives double when not winner

## Coverage Requirements

To fully exercise the engine, tests should cover:

1. **Each scoring item type** (11 items)
2. **Each hand status** (dirty, clean, limit)
3. **Each double condition** (6 single, 3 triple)
4. **Combinations**: winner/not, east/not east
5. **Edge cases**:
   - Empty hand
   - Max score cap (1000)
   - Multiple doubles stacking
   - Limit hand as East
