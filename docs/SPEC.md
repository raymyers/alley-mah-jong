# Alley Mah-Jong Scoring Spec

## Input

Who is east wind
Who is the prevailing wind

What's in every hand: hidden and revealed.

Scoring selector. We select a series of secong items for each player

### Scoring item descriptions


* Pung of 2-8
* Pung of Honors (1-9, W, D)
* Kong of 2-8
* Kong of Honors (1-9, W D)
* Bonus: Pair of Wind
* Bonus: Pair of Dragon
* Bonus: Flower
* Mah-jong

For Pungs and Kong, we need to track if they are hidden.

### Input display

UI represents hidden status positionally. There's a revealed row and a hidden row.

The UI should use descriptions, not the raw notation.

Selection doesn't need score number, but once selected we should see it.

### Scoring item notation

Used internally and for testing.

```
p
ph
k
kh
bpw
bpd
bf
mj
```

Hiddens

```
hp
hph
hk
hkh
```

## Output

Score - who pays who what?

## Tiles
Dragon (green, red, white)
Wind (north, sound, east, west)
Sticks (1-9)
Circles (1-9)
Characters (1-9)
Flowers (blue, red)

## Combinations of tiles that score points

* Pung - 3 of a kind
  * 2-8 (2 points) 
  * 1,9,Winds,Dragons (4 points) 
  * Hidden 2-8 (4 points) 
  * Hidden 1,9,Winds,Dragons (8 points) 
* Kong - 4 of a kind
  * 2-8 (8 points)
  * 1,9,Winds,Dragons (16 points)
  * Hidden 2-8 (16 points)
  * Hidden 1,9,Winds,Dragons (32 points)

## Glossary

* Pung - 3 of a kind
* Kong - 4 of a kind
* Honors
  * 1,9
  * Wind
  * Dragons
* Mah-jong - winning the round
* East Wind - the dealer
* Clean - Only have one suit in your hand and the end of round
  * Clean no winds or dragons
* Hand
  * Hidden - tiles in your hand not played
  * Revealed - tiles played in front of you
* Dirty - Not clean
* Flowers - tiles that give bonus points, not otherwise part of play
* Pickup
* Doubles - Bonus that doubles your entire score
* Paying

## Paying

At the end of a round, 1 person has Mah-jong'd, 3 have not.

Here is the order of scoring:

1. Mah-jong'd player
2. East wind (unless Mah-jong'd)
3. Other players, order doesn't matter

Each of the other 3 player will pay them what the Mah-jong'd player's hand is worth.

Mah-jong'd players are scored regardless of clean or dirty status.

Non-Mah-jong'd players are scored only if they are clean.

## Max score

Per round, 1,000 pts is the most that can be scored. You may still be paid that by multiple players.

So the order of processing is: double, max, paying. Equivelently, we could say max applies to round score, not game score.

## Bonus

Pair of Winds (2pt)
Pair of Dragons (2pt)
Flower (4pt)
Mah-jonging (20pt)

## Doubles

Doubles stack.

### 1 double conditions

* being clean
* Pung or Kong of dragon
* Your own wind
* Prevailing wind
* Both your own flowers
* You are east wind

### 3 double conditions (8x)

* all 4 red flowers
* all 4 blue flowers
* clean, no winds or dragons

### Paying double

When you are East Wind and you Mah-jong
Then you pay nothing.

When you are East Wind and you do not Mah-jong
You pay double to everyone.

## Limit Hands

There are specific dirty hands with combinations that are scored for Mah-john'd players.

TBD - list of limit hands

## Rotating rounds

TBD - how the wind changes from round to round
