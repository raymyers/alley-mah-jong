//// Game engine for Mah-jong scoring
//// Pure game logic, isolated from UI

import gleam/int
import gleam/list

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

pub fn calculate_hand_points(hand: PlayerHand, is_winner: Bool) -> Int {
  let base =
    list.fold(hand.items, 0, fn(total, item) { total + item_points(item) })
  case is_winner {
    True -> base + mahjong_bonus
    False -> base
  }
}
