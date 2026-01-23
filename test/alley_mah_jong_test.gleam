import alley_mah_jong.{
  BonusFlower, BonusPairDragon, BonusPairWind, Kong, KongHidden, KongHonors,
  KongHonorsHidden, PlayerHand, Pung, PungHidden, PungHonors, PungHonorsHidden,
  calculate_hand_points, item_points,
}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Pung Point Tests ---

pub fn pung_revealed_points_test() {
  assert item_points(Pung) == 2
}

pub fn pung_honors_revealed_points_test() {
  assert item_points(PungHonors) == 4
}

pub fn pung_hidden_points_test() {
  assert item_points(PungHidden) == 4
}

pub fn pung_honors_hidden_points_test() {
  assert item_points(PungHonorsHidden) == 8
}

// --- Kong Point Tests ---

pub fn kong_revealed_points_test() {
  assert item_points(Kong) == 8
}

pub fn kong_honors_revealed_points_test() {
  assert item_points(KongHonors) == 16
}

pub fn kong_hidden_points_test() {
  assert item_points(KongHidden) == 16
}

pub fn kong_honors_hidden_points_test() {
  assert item_points(KongHonorsHidden) == 32
}

// --- Bonus Point Tests ---

pub fn bonus_flower_points_test() {
  assert item_points(BonusFlower) == 4
}

pub fn bonus_pair_wind_points_test() {
  // Pair of wind contributes to doubles, not base points
  assert item_points(BonusPairWind) == 0
}

pub fn bonus_pair_dragon_points_test() {
  // Pair of dragon contributes to doubles, not base points
  assert item_points(BonusPairDragon) == 0
}

// --- Hand Calculation Tests ---

pub fn empty_hand_no_winner_test() {
  let hand = PlayerHand(items: [])
  assert calculate_hand_points(hand, False) == 0
}

pub fn empty_hand_winner_gets_mahjong_bonus_test() {
  let hand = PlayerHand(items: [])
  assert calculate_hand_points(hand, True) == 20
}

pub fn single_pung_test() {
  let hand = PlayerHand(items: [Pung])
  assert calculate_hand_points(hand, False) == 2
}

pub fn multiple_items_test() {
  let hand = PlayerHand(items: [Pung, PungHonors, Kong])
  // 2 + 4 + 8 = 14
  assert calculate_hand_points(hand, False) == 14
}

pub fn multiple_items_with_winner_test() {
  let hand = PlayerHand(items: [Pung, PungHonors, Kong])
  // 2 + 4 + 8 + 20 = 34
  assert calculate_hand_points(hand, True) == 34
}

pub fn hidden_items_score_double_test() {
  let hand = PlayerHand(items: [PungHidden, KongHidden])
  // 4 + 16 = 20
  assert calculate_hand_points(hand, False) == 20
}

pub fn mixed_hand_test() {
  let hand =
    PlayerHand(items: [
      Pung,
      PungHonorsHidden,
      Kong,
      KongHonorsHidden,
      BonusFlower,
      BonusFlower,
    ])
  // 2 + 8 + 8 + 32 + 4 + 4 = 58
  assert calculate_hand_points(hand, False) == 58
}

pub fn mixed_hand_winner_test() {
  let hand =
    PlayerHand(items: [
      Pung,
      PungHonorsHidden,
      Kong,
      KongHonorsHidden,
      BonusFlower,
      BonusFlower,
    ])
  // 2 + 8 + 8 + 32 + 4 + 4 + 20 = 78
  assert calculate_hand_points(hand, True) == 78
}
