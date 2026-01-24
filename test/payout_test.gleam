import engine.{Player1, Player2, Player3, Player4}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Payout Types ---
// PayoutEntry: who you're paying and how much
// PlayerPayout: paying (list of entries) and received (lump sum)

// --- Basic Payout Tests ---

// Winner receives from all non-winners, pays nothing
pub fn winner_only_receives_test() {
  // Alice (P1) wins with 100 pts
  // Bob (P2): 64 pts clean
  // Carol (P3): 32 pts clean
  // Dave (P4): 16 pts clean
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player2)

  // Winner (P1) receives 64 + 32 + 16 = 112, pays nothing
  let p1_payout = get_payout(payouts, Player1)
  assert p1_payout.paying == []
  assert p1_payout.received == 112
}

// Non-winners pay winner their score
pub fn non_winner_pays_winner_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player2)

  // Bob (P2) pays Alice 64
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player1, 64)
}

// Non-winners pay each other their own scores
pub fn non_winners_pay_each_other_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player2)

  // Bob (P2, 64 pts) pays Carol 64 and Dave 64
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player3, 64)
  assert has_payment(p2_payout.paying, Player4, 64)

  // Carol (P3, 32 pts) pays Bob 32 and Dave 32
  let p3_payout = get_payout(payouts, Player3)
  assert has_payment(p3_payout.paying, Player2, 32)
  assert has_payment(p3_payout.paying, Player4, 32)
}

// Non-winners receive from other non-winners
pub fn non_winners_receive_from_each_other_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player2)

  // Bob (P2) receives 32 (from Carol) + 16 (from Dave) = 48
  let p2_payout = get_payout(payouts, Player2)
  assert p2_payout.received == 48

  // Carol (P3) receives 64 (from Bob) + 16 (from Dave) = 80
  let p3_payout = get_payout(payouts, Player3)
  assert p3_payout.received == 80

  // Dave (P4) receives 64 (from Bob) + 32 (from Carol) = 96
  let p4_payout = get_payout(payouts, Player4)
  assert p4_payout.received == 96
}

// --- Dirty Hand Tests ---

// Dirty hands pay 0 to everyone
pub fn dirty_hand_pays_zero_test() {
  let scores = #(100, 0, 32, 16)
  let statuses = #(engine.Clean, engine.Dirty, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player3)

  // Bob (P2, dirty) pays 0 to everyone
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player1, 0)
  assert has_payment(p2_payout.paying, Player3, 0)
  assert has_payment(p2_payout.paying, Player4, 0)
}

// Dirty hands still receive from others
pub fn dirty_hand_still_receives_test() {
  let scores = #(100, 0, 32, 16)
  let statuses = #(engine.Clean, engine.Dirty, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player3)

  // Bob (P2, dirty) receives 32 (from Carol) + 16 (from Dave) = 48
  let p2_payout = get_payout(payouts, Player2)
  assert p2_payout.received == 48
}

// --- Full Example Test ---

// Complete scenario matching the example from brainstorming
pub fn full_example_test() {
  // Alice (P1) wins with 100 pts
  // Bob (P2): 64 pts clean
  // Carol (P3): 32 pts clean
  // Dave (P4): 16 pts clean
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1

  let payouts = engine.calculate_payouts(scores, statuses, winner, Player2)

  // Alice (winner): receives 64+32+16=112, pays nothing
  let p1 = get_payout(payouts, Player1)
  assert p1.paying == []
  assert p1.received == 112

  // Bob: pays Alice 64, Carol 64, Dave 64; receives 32+16=48
  let p2 = get_payout(payouts, Player2)
  assert has_payment(p2.paying, Player1, 64)
  assert has_payment(p2.paying, Player3, 64)
  assert has_payment(p2.paying, Player4, 64)
  assert p2.received == 48

  // Carol: pays Alice 32, Bob 32, Dave 32; receives 64+16=80
  let p3 = get_payout(payouts, Player3)
  assert has_payment(p3.paying, Player1, 32)
  assert has_payment(p3.paying, Player2, 32)
  assert has_payment(p3.paying, Player4, 32)
  assert p3.received == 80

  // Dave: pays Alice 16, Bob 16, Carol 16; receives 64+32=96
  let p4 = get_payout(payouts, Player4)
  assert has_payment(p4.paying, Player1, 16)
  assert has_payment(p4.paying, Player2, 16)
  assert has_payment(p4.paying, Player3, 16)
  assert p4.received == 96
}

// --- Helper Functions ---

fn get_payout(
  payouts: #(
    engine.PlayerPayout,
    engine.PlayerPayout,
    engine.PlayerPayout,
    engine.PlayerPayout,
  ),
  player: engine.Player,
) -> engine.PlayerPayout {
  case player {
    Player1 -> payouts.0
    Player2 -> payouts.1
    Player3 -> payouts.2
    Player4 -> payouts.3
  }
}

fn has_payment(
  payments: List(engine.PayoutEntry),
  to_player: engine.Player,
  amount: Int,
) -> Bool {
  case payments {
    [] -> False
    [first, ..rest] ->
      case first.to == to_player && first.amount == amount {
        True -> True
        False -> has_payment(rest, to_player, amount)
      }
  }
}
