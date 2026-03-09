import engine.{
  Clean, Dirty, East, Limit, North, Player1, Player2, Player3, Player4, South,
  West,
}
import gleam/option.{None, Some}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Running Score Tests ---

// Net payout is received minus total paid
pub fn net_payout_test() {
  // Bob paid 148 total, received 128 → net is -20
  let payout =
    engine.PlayerPayout(
      paying: [
        engine.PayoutEntry(to: Player1, amount: 100),
        engine.PayoutEntry(to: Player3, amount: 32),
        engine.PayoutEntry(to: Player4, amount: 16),
      ],
      receiving: [
        engine.PayoutEntry(to: Player1, amount: 64),
        engine.PayoutEntry(to: Player3, amount: 64),
      ],
      received: 128,
    )
  assert engine.net_payout(payout) == -20
}

// Winner net payout is just received (pays nothing)
pub fn winner_net_payout_test() {
  let payout =
    engine.PlayerPayout(
      paying: [],
      receiving: [
        engine.PayoutEntry(to: Player2, amount: 100),
        engine.PayoutEntry(to: Player3, amount: 100),
        engine.PayoutEntry(to: Player4, amount: 100),
      ],
      received: 300,
    )
  assert engine.net_payout(payout) == 300
}

// Running scores after one round
pub fn running_scores_one_round_test() {
  let starting = 3550
  // Alice wins, receives 300 net
  // Bob net -20, Carol net -116, Dave net -164
  let nets = #(300, -20, -116, -164)

  let running = engine.calculate_running_scores(starting, [nets])

  assert running == #(3850, 3530, 3434, 3386)
}

// Running scores accumulate over multiple rounds
pub fn running_scores_multiple_rounds_test() {
  let starting = 3550
  let round1_nets = #(300, -20, -116, -164)
  let round2_nets = #(-50, 200, -100, -50)

  let running =
    engine.calculate_running_scores(starting, [round1_nets, round2_nets])

  // Round 1: 3850, 3530, 3434, 3386
  // Round 2: 3800, 3730, 3334, 3336
  assert running == #(3800, 3730, 3334, 3336)
}

// --- East Wind Rotation Tests ---

// East stays if East won
pub fn east_stays_when_east_wins_test() {
  let current_east = Player2
  let winner = Player2
  // East won

  let next_east = engine.next_east_wind(current_east, winner)

  assert next_east == Player2
}

// East rotates if East didn't win
pub fn east_rotates_when_east_loses_test() {
  let current_east = Player2
  let winner = Player1
  // East lost

  let next_east = engine.next_east_wind(current_east, winner)

  assert next_east == Player3
}

// East rotates from Player4 to Player1
pub fn east_rotates_from_4_to_1_test() {
  let current_east = Player4
  let winner = Player1
  // East lost

  let next_east = engine.next_east_wind(current_east, winner)

  assert next_east == Player1
}

// --- Prevailing Wind Rotation Tests ---

// Prevailing stays if East doesn't rotate to Player1
pub fn prevailing_stays_test() {
  let current_prevailing = East
  let old_east = Player2
  let new_east = Player3
  // Rotated but not to Player1

  let next_prevailing =
    engine.next_prevailing_wind(current_prevailing, old_east, new_east)

  assert next_prevailing == East
}

// Prevailing advances when East rotates from Player4 to Player1
pub fn prevailing_advances_on_full_rotation_test() {
  let current_prevailing = East
  let old_east = Player4
  let new_east = Player1
  // Full rotation completed

  let next_prevailing =
    engine.next_prevailing_wind(current_prevailing, old_east, new_east)

  assert next_prevailing == South
}

// Prevailing cycles through all winds
pub fn prevailing_cycles_test() {
  // East → South
  assert engine.next_prevailing_wind(East, Player4, Player1) == South
  // South → West
  assert engine.next_prevailing_wind(South, Player4, Player1) == West
  // West → North
  assert engine.next_prevailing_wind(West, Player4, Player1) == North
  // North → East (wraps)
  assert engine.next_prevailing_wind(North, Player4, Player1) == East
}

// Prevailing doesn't advance if East stays (East won)
pub fn prevailing_stays_when_east_wins_test() {
  let current_prevailing = East
  let old_east = Player4
  let new_east = Player4
  // East won, didn't rotate

  let next_prevailing =
    engine.next_prevailing_wind(current_prevailing, old_east, new_east)

  assert next_prevailing == East
}

// --- Limit Invariant Tests ---

// Count limits: no limits
pub fn count_limits_none_test() {
  let statuses = #(Dirty, Clean, Clean, Dirty)
  assert engine.count_limits(statuses) == 0
}

// Count limits: one limit
pub fn count_limits_one_test() {
  let statuses = #(Dirty, Limit, Clean, Dirty)
  assert engine.count_limits(statuses) == 1
}

// Count limits: multiple limits
pub fn count_limits_multiple_test() {
  let statuses = #(Limit, Limit, Clean, Dirty)
  assert engine.count_limits(statuses) == 2
}

// Get limit player: returns the player with limit
pub fn get_limit_player_found_test() {
  let statuses = #(Dirty, Clean, Limit, Dirty)
  assert engine.get_limit_player(statuses) == Some(Player3)
}

// Get limit player: returns None if no limit
pub fn get_limit_player_none_test() {
  let statuses = #(Dirty, Clean, Clean, Dirty)
  assert engine.get_limit_player(statuses) == None
}

// Get limit player: returns first if multiple (edge case)
pub fn get_limit_player_first_test() {
  let statuses = #(Dirty, Limit, Limit, Dirty)
  assert engine.get_limit_player(statuses) == Some(Player2)
}

// Round is scoreable: valid with winner and no limit
pub fn round_scoreable_clean_winner_test() {
  let statuses = #(Clean, Dirty, Dirty, Dirty)
  assert engine.is_round_scoreable(Some(Player1), statuses) == True
}

// Round is scoreable: valid with limit matching winner
pub fn round_scoreable_limit_matches_winner_test() {
  let statuses = #(Dirty, Limit, Dirty, Dirty)
  assert engine.is_round_scoreable(Some(Player2), statuses) == True
}

// Round NOT scoreable: no winner
pub fn round_not_scoreable_no_winner_test() {
  let statuses = #(Clean, Dirty, Dirty, Dirty)
  assert engine.is_round_scoreable(None, statuses) == False
}

// Round NOT scoreable: limit doesn't match winner
pub fn round_not_scoreable_limit_mismatch_test() {
  let statuses = #(Dirty, Limit, Dirty, Dirty)
  // Player2 has limit but Player1 is winner
  assert engine.is_round_scoreable(Some(Player1), statuses) == False
}

// Round NOT scoreable: multiple limits
pub fn round_not_scoreable_multiple_limits_test() {
  let statuses = #(Limit, Limit, Dirty, Dirty)
  // Even if winner matches one limit, multiple limits is invalid
  assert engine.is_round_scoreable(Some(Player1), statuses) == False
}
