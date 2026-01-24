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
  // East is Player4 (Dave) - not the winner, so East doubling affects Dave's payments
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player4

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Winner (P1) receives: 100 from Bob + 100 from Carol + 200 from Dave (East pays 2x) = 400
  let p1_payout = get_payout(payouts, Player1)
  assert p1_payout.paying == []
  assert p1_payout.received == 400
}

// Non-winners pay winner the winner's score
pub fn non_winner_pays_winner_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East, so no non-winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (P2, not East) pays Alice her score (100)
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player1, 100)
}

// Non-winners pay each other the recipient's score
pub fn non_winners_pay_each_other_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East, so no non-winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (P2, not East) pays Carol her score (32) and Dave his score (16)
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player3, 32)
  assert has_payment(p2_payout.paying, Player4, 16)

  // Carol (P3, not East) pays Bob his score (64) and Dave his score (16)
  let p3_payout = get_payout(payouts, Player3)
  assert has_payment(p3_payout.paying, Player2, 64)
  assert has_payment(p3_payout.paying, Player4, 16)
}

// Non-winners receive their own score from other non-winners
pub fn non_winners_receive_from_each_other_test() {
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East, so no non-winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (P2, 64 pts) receives his score from Carol and Dave = 64 * 2 = 128
  let p2_payout = get_payout(payouts, Player2)
  assert p2_payout.received == 128

  // Carol (P3, 32 pts) receives her score from Bob and Dave = 32 * 2 = 64
  let p3_payout = get_payout(payouts, Player3)
  assert p3_payout.received == 64

  // Dave (P4, 16 pts) receives his score from Bob and Carol = 16 * 2 = 32
  let p4_payout = get_payout(payouts, Player4)
  assert p4_payout.received == 32
}

// --- Dirty Hand Tests ---

// Dirty hands still pay others their scores
pub fn dirty_hand_still_pays_test() {
  let scores = #(100, 0, 32, 16)
  let statuses = #(engine.Clean, engine.Dirty, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (P2, dirty) still pays others their scores
  let p2_payout = get_payout(payouts, Player2)
  assert has_payment(p2_payout.paying, Player1, 100)
  assert has_payment(p2_payout.paying, Player3, 32)
  assert has_payment(p2_payout.paying, Player4, 16)
}

// Dirty hands receive 0 (their score is 0)
pub fn dirty_hand_receives_zero_test() {
  let scores = #(100, 0, 32, 16)
  let statuses = #(engine.Clean, engine.Dirty, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (P2, dirty, 0 pts) receives his score (0) from Carol and Dave = 0
  let p2_payout = get_payout(payouts, Player2)
  assert p2_payout.received == 0
}

// --- Full Example Test ---

// Complete scenario: you pay others THEIR score, you receive YOUR score from others
// Winner is East, so no non-winner pays double
pub fn full_example_test() {
  // Alice (P1) wins with 100 pts, is East
  // Bob (P2): 64 pts clean
  // Carol (P3): 32 pts clean
  // Dave (P4): 16 pts clean
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player1
  // Winner is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Alice (winner): receives her score (100) from 3 non-winners = 300, pays nothing
  let p1 = get_payout(payouts, Player1)
  assert p1.paying == []
  assert p1.received == 300

  // Bob: pays Alice 100, Carol 32, Dave 16; receives 64 from Carol + 64 from Dave = 128
  let p2 = get_payout(payouts, Player2)
  assert has_payment(p2.paying, Player1, 100)
  assert has_payment(p2.paying, Player3, 32)
  assert has_payment(p2.paying, Player4, 16)
  assert p2.received == 128

  // Carol: pays Alice 100, Bob 64, Dave 16; receives 32 from Bob + 32 from Dave = 64
  let p3 = get_payout(payouts, Player3)
  assert has_payment(p3.paying, Player1, 100)
  assert has_payment(p3.paying, Player2, 64)
  assert has_payment(p3.paying, Player4, 16)
  assert p3.received == 64

  // Dave: pays Alice 100, Bob 64, Carol 32; receives 16 from Bob + 16 from Carol = 32
  let p4 = get_payout(payouts, Player4)
  assert has_payment(p4.paying, Player1, 100)
  assert has_payment(p4.paying, Player2, 64)
  assert has_payment(p4.paying, Player3, 32)
  assert p4.received == 32
}

// --- East Wind Tests ---

// East pays double to everyone
pub fn east_pays_double_test() {
  // Alice (P1) wins with 100 pts
  // Bob (P2, East): 64 pts clean - pays double
  // Carol (P3): 32 pts clean
  // Dave (P4): 16 pts clean
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player2
  // Bob is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Bob (East) pays double: Alice 200, Carol 64, Dave 32
  let p2 = get_payout(payouts, Player2)
  assert has_payment(p2.paying, Player1, 200)
  assert has_payment(p2.paying, Player3, 64)
  assert has_payment(p2.paying, Player4, 32)

  // Bob receives his score from Carol and Dave (not East, so 1x): 64 + 64 = 128
  assert p2.received == 128
}

// Others receive double from East
pub fn east_pays_double_to_winner_test() {
  // Alice (P1) wins with 100 pts
  // Bob (P2, East): 64 pts clean
  let scores = #(100, 64, 32, 16)
  let statuses = #(engine.Clean, engine.Clean, engine.Clean, engine.Clean)
  let winner = Player1
  let east = Player2
  // Bob is East

  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  // Alice receives: 200 from Bob (East, 2x) + 100 from Carol + 100 from Dave = 400
  let p1 = get_payout(payouts, Player1)
  assert p1.received == 400
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
