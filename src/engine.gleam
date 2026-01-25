//// Game engine for Mah-jong scoring
//// Pure game logic, isolated from UI

import gleam/int
import gleam/list
import gleam/option

// --- Scoring Items ---

pub type ScoringItem {
  // Pungs (3 of a kind)
  Pung
  // 2-8 revealed: 2 pts
  PungHonors
  // 1,9,W,D revealed: 4 pts
  PungHidden
  // 2-8 hidden: 4 pts
  PungHonorsHidden
  // 1,9,W,D hidden: 8 pts
  // Kongs (4 of a kind)
  Kong
  // 2-8 revealed: 8 pts
  KongHonors
  // 1,9,W,D revealed: 16 pts
  KongHidden
  // 2-8 hidden: 16 pts
  KongHonorsHidden
  // 1,9,W,D hidden: 32 pts
  // Bonuses
  BonusPairWind
  // Pair of winds: 2 pts
  BonusPairDragon
  // Pair of dragons: 2 pts
  BonusFlower
  // Flower: 4 pts
}

pub fn item_points(item: ScoringItem) -> Int {
  case item {
    Pung -> 2
    PungHonors -> 4
    PungHidden -> 4
    PungHonorsHidden -> 8
    Kong -> 8
    KongHonors -> 16
    KongHidden -> 16
    KongHonorsHidden -> 32
    BonusPairWind -> 2
    BonusPairDragon -> 2
    BonusFlower -> 4
  }
}

pub fn item_label(item: ScoringItem) -> String {
  case item {
    Pung | PungHidden -> "Pung 2-8"
    PungHonors | PungHonorsHidden -> "Pung Honors"
    Kong | KongHidden -> "Kong 2-8"
    KongHonors | KongHonorsHidden -> "Kong Honors"
    BonusPairWind -> "Wind Pair"
    BonusPairDragon -> "Dragon Pair"
    BonusFlower -> "Flower"
  }
}

pub fn item_display(item: ScoringItem) -> String {
  let pts = item_points(item)
  let label = item_label(item)
  case pts {
    0 -> label
    n -> label <> " (" <> int.to_string(n) <> ")"
  }
}

// --- Wind ---

pub type Wind {
  North
  South
  East
  West
}

// --- Player ---

pub type Player {
  Player1
  Player2
  Player3
  Player4
}

pub fn player_to_string(player: Player) -> String {
  case player {
    Player1 -> "Player 1"
    Player2 -> "Player 2"
    Player3 -> "Player 3"
    Player4 -> "Player 4"
  }
}

// --- Player Hand ---

pub type PlayerHand {
  PlayerHand(items: List(ScoringItem))
}

pub fn empty_hand() -> PlayerHand {
  PlayerHand(items: [])
}

pub fn add_to_hand(hand: PlayerHand, item: ScoringItem) -> PlayerHand {
  PlayerHand(items: list.append(hand.items, [item]))
}

pub fn remove_from_hand(hand: PlayerHand, index: Int) -> PlayerHand {
  PlayerHand(items: remove_at(hand.items, index))
}

fn remove_at(items: List(a), index: Int) -> List(a) {
  list.index_fold(items, [], fn(acc, item, i) {
    case i == index {
      True -> acc
      False -> list.append(acc, [item])
    }
  })
}

// --- Scoring ---

pub const mahjong_bonus = 20

pub const max_round_score = 1000

pub fn calculate_hand_points(hand: PlayerHand, is_winner: Bool) -> Int {
  let base =
    list.fold(hand.items, 0, fn(total, item) { total + item_points(item) })
  case is_winner {
    True -> base + mahjong_bonus
    False -> base
  }
}

/// Calculate final round score: base points * multiplier, capped at max_round_score
pub fn calculate_round_score(base_points: Int, multiplier: Int) -> Int {
  let score = base_points * multiplier
  case score > max_round_score {
    True -> max_round_score
    False -> score
  }
}

// --- Hand Status ---

pub type HandStatus {
  Dirty
  Clean
  Limit
}

pub const limit_score = 500

pub const limit_score_east = 1000

// --- Limit Invariants ---
// 1. If there is a limit, that player must be the Mah-jong winner
// 2. There cannot be multiple limits in a round
// 3. Round is not scoreable if these invariants are violated

/// Count how many players have Limit status
pub fn count_limits(
  statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
) -> Int {
  let count_one = fn(s: HandStatus) -> Int {
    case s {
      Limit -> 1
      _ -> 0
    }
  }
  count_one(statuses.0)
  + count_one(statuses.1)
  + count_one(statuses.2)
  + count_one(statuses.3)
}

/// Get the player who has Limit status, if any
pub fn get_limit_player(
  statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
) -> option.Option(Player) {
  case statuses.0 {
    Limit -> option.Some(Player1)
    _ ->
      case statuses.1 {
        Limit -> option.Some(Player2)
        _ ->
          case statuses.2 {
            Limit -> option.Some(Player3)
            _ ->
              case statuses.3 {
                Limit -> option.Some(Player4)
                _ -> option.None
              }
          }
      }
  }
}

/// Check if a round is valid for scoring
/// Returns False if: no winner, multiple limits, or limit player doesn't match winner
pub fn is_round_scoreable(
  winner: option.Option(Player),
  statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
) -> Bool {
  case winner {
    option.None -> False
    option.Some(w) -> {
      let limit_count = count_limits(statuses)
      case limit_count {
        0 -> True
        1 -> {
          case get_limit_player(statuses) {
            option.Some(limit_player) -> limit_player == w
            option.None -> True
          }
        }
        _ -> False
      }
    }
  }
}

/// Calculate score based on hand status, hand contents, doubles, and position
/// Returns (total_points, multiplier, doubles_count, reasons)
pub fn calculate_final_score(
  hand: PlayerHand,
  hand_status: HandStatus,
  doubles_ctx: DoublesContext,
  is_winner: Bool,
  is_east: Bool,
) -> #(Int, Int, Int, List(String)) {
  case hand_status {
    Dirty -> #(0, 1, 0, [])
    Limit -> {
      let score = case is_east {
        True -> limit_score_east
        False -> limit_score
      }
      #(score, 1, 0, ["Limit Hand"])
    }
    Clean -> {
      let effective_doubles =
        DoublesContext(..doubles_ctx, is_east_wind: is_east, is_clean: True)
      let base_points = calculate_hand_points(hand, is_winner)
      let multiplier = calculate_multiplier(effective_doubles)
      let points = calculate_round_score(base_points, multiplier)
      let doubles_count = calculate_doubles(effective_doubles)
      let reasons = calculate_doubles_with_reasons(effective_doubles)
      #(points, multiplier, doubles_count, reasons)
    }
  }
}

// --- Doubles ---

pub type DoublesContext {
  DoublesContext(
    // 1 double conditions
    is_clean: Bool,
    has_dragon_pung_or_kong: Bool,
    has_own_wind_pung_or_kong: Bool,
    has_prevailing_wind_pung_or_kong: Bool,
    has_both_own_flowers: Bool,
    is_east_wind: Bool,
    // 3 double conditions
    has_all_red_flowers: Bool,
    has_all_blue_flowers: Bool,
    is_clean_no_winds_or_dragons: Bool,
  )
}

pub fn no_doubles() -> DoublesContext {
  DoublesContext(
    is_clean: False,
    has_dragon_pung_or_kong: False,
    has_own_wind_pung_or_kong: False,
    has_prevailing_wind_pung_or_kong: False,
    has_both_own_flowers: False,
    is_east_wind: False,
    has_all_red_flowers: False,
    has_all_blue_flowers: False,
    is_clean_no_winds_or_dragons: False,
  )
}

pub fn calculate_doubles(ctx: DoublesContext) -> Int {
  let singles =
    count_true([
      ctx.is_clean,
      ctx.has_dragon_pung_or_kong,
      ctx.has_own_wind_pung_or_kong,
      ctx.has_prevailing_wind_pung_or_kong,
      ctx.has_both_own_flowers,
      ctx.is_east_wind,
    ])
  let triples =
    count_true([
      ctx.has_all_red_flowers,
      ctx.has_all_blue_flowers,
      ctx.is_clean_no_winds_or_dragons,
    ])
  singles + triples * 3
}

/// Calculate doubles and return the list of reasons that contributed
pub fn calculate_doubles_with_reasons(ctx: DoublesContext) -> List(String) {
  let single_conditions = [
    #(ctx.is_clean, "Clean (1x)"),
    #(ctx.has_dragon_pung_or_kong, "Dragon Pung/Kong (1x)"),
    #(ctx.has_own_wind_pung_or_kong, "Own Wind Pung/Kong (1x)"),
    #(ctx.has_prevailing_wind_pung_or_kong, "Prevailing Wind Pung/Kong (1x)"),
    #(ctx.has_both_own_flowers, "Both Own Flowers (1x)"),
    #(ctx.is_east_wind, "East Wind (1x)"),
  ]
  let triple_conditions = [
    #(ctx.has_all_red_flowers, "All Red Flowers (3x)"),
    #(ctx.has_all_blue_flowers, "All Blue Flowers (3x)"),
    #(ctx.is_clean_no_winds_or_dragons, "Clean No Winds/Dragons (3x)"),
  ]
  let all_conditions = list.append(single_conditions, triple_conditions)
  list.filter_map(all_conditions, fn(pair) {
    case pair.0 {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
}

fn count_true(bools: List(Bool)) -> Int {
  list.fold(bools, 0, fn(acc, b) {
    case b {
      True -> acc + 1
      False -> acc
    }
  })
}

pub fn calculate_multiplier(ctx: DoublesContext) -> Int {
  let doubles = calculate_doubles(ctx)
  power_of_two(doubles)
}

fn power_of_two(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> 2 * power_of_two(n - 1)
  }
}

// --- Payout Types ---

pub type PayoutEntry {
  PayoutEntry(to: Player, amount: Int)
}

pub type PlayerPayout {
  PlayerPayout(paying: List(PayoutEntry), received: Int)
}

// --- Payout Calculation ---

/// Calculate payouts for all players based on scores and winner
/// Each player pays the recipient's score, East pays double
/// Winner only receives, never pays
pub fn calculate_payouts(
  scores: #(Int, Int, Int, Int),
  _statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
  winner: Player,
  east: Player,
) -> #(PlayerPayout, PlayerPayout, PlayerPayout, PlayerPayout) {
  let players = [Player1, Player2, Player3, Player4]

  let p1_payout =
    calculate_player_payout(Player1, scores, winner, east, players)
  let p2_payout =
    calculate_player_payout(Player2, scores, winner, east, players)
  let p3_payout =
    calculate_player_payout(Player3, scores, winner, east, players)
  let p4_payout =
    calculate_player_payout(Player4, scores, winner, east, players)

  #(p1_payout, p2_payout, p3_payout, p4_payout)
}

fn calculate_player_payout(
  player: Player,
  scores: #(Int, Int, Int, Int),
  winner: Player,
  east: Player,
  all_players: List(Player),
) -> PlayerPayout {
  let my_score = get_score(scores, player)
  let is_winner = player == winner
  let is_east = player == east

  // Winner pays nothing
  let paying = case is_winner {
    True -> []
    False -> {
      // Pay each other player THEIR score (East pays double)
      list.filter_map(all_players, fn(other) {
        case other == player {
          True -> Error(Nil)
          False -> {
            let other_score = get_score(scores, other)
            let amount = case is_east {
              True -> other_score * 2
              False -> other_score
            }
            Ok(PayoutEntry(to: other, amount: amount))
          }
        }
      })
    }
  }

  // Calculate received: others pay me MY score (East payers pay double)
  let received = case is_winner {
    True -> {
      // Winner receives their score from all non-winners
      list.fold(all_players, 0, fn(acc, other) {
        case other == player {
          True -> acc
          False -> {
            let other_is_east = other == east
            let amount = case other_is_east {
              True -> my_score * 2
              False -> my_score
            }
            acc + amount
          }
        }
      })
    }
    False -> {
      // Non-winner receives their score from other non-winners
      list.fold(all_players, 0, fn(acc, other) {
        case other == player || other == winner {
          True -> acc
          False -> {
            let other_is_east = other == east
            let amount = case other_is_east {
              True -> my_score * 2
              False -> my_score
            }
            acc + amount
          }
        }
      })
    }
  }

  PlayerPayout(paying: paying, received: received)
}

fn get_score(scores: #(Int, Int, Int, Int), player: Player) -> Int {
  case player {
    Player1 -> scores.0
    Player2 -> scores.1
    Player3 -> scores.2
    Player4 -> scores.3
  }
}

// --- Game Logic ---

/// Calculate net payout (received - total paid)
pub fn net_payout(payout: PlayerPayout) -> Int {
  let total_paid =
    list.fold(payout.paying, 0, fn(acc, entry) { acc + entry.amount })
  payout.received - total_paid
}

/// Calculate running scores after a series of rounds
/// Takes starting score and list of net payouts per round
pub fn calculate_running_scores(
  starting: Int,
  round_nets: List(#(Int, Int, Int, Int)),
) -> #(Int, Int, Int, Int) {
  list.fold(
    round_nets,
    #(starting, starting, starting, starting),
    fn(running, nets) {
      #(
        running.0 + nets.0,
        running.1 + nets.1,
        running.2 + nets.2,
        running.3 + nets.3,
      )
    },
  )
}

/// Determine next East wind based on whether current East won
pub fn next_east_wind(current_east: Player, winner: Player) -> Player {
  case current_east == winner {
    True -> current_east
    False -> rotate_player(current_east)
  }
}

fn rotate_player(player: Player) -> Player {
  case player {
    Player1 -> Player2
    Player2 -> Player3
    Player3 -> Player4
    Player4 -> Player1
  }
}

/// Determine next prevailing wind
/// Advances when East rotates from Player4 to Player1
pub fn next_prevailing_wind(
  current: Wind,
  old_east: Player,
  new_east: Player,
) -> Wind {
  case old_east == Player4 && new_east == Player1 {
    True -> rotate_wind(current)
    False -> current
  }
}

fn rotate_wind(wind: Wind) -> Wind {
  case wind {
    East -> South
    South -> West
    West -> North
    North -> East
  }
}
