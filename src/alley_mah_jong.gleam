import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h3, option, select, span}
import lustre/event

// --- Scoring Items ---

pub type ScoringItem {
  // Pungs (3 of a kind)
  Pung              // 2-8 revealed: 2 pts
  PungHonors        // 1,9,W,D revealed: 4 pts
  PungHidden        // 2-8 hidden: 4 pts
  PungHonorsHidden  // 1,9,W,D hidden: 8 pts
  // Kongs (4 of a kind)
  Kong              // 2-8 revealed: 8 pts
  KongHonors        // 1,9,W,D revealed: 16 pts
  KongHidden        // 2-8 hidden: 16 pts
  KongHonorsHidden  // 1,9,W,D hidden: 32 pts
  // Bonuses
  BonusPairWind     // Pair of own/prevailing wind
  BonusPairDragon   // Pair of dragon
  BonusFlower       // Flower: 4 pts
}

fn item_points(item: ScoringItem) -> Int {
  case item {
    Pung -> 2
    PungHonors -> 4
    PungHidden -> 4
    PungHonorsHidden -> 8
    Kong -> 8
    KongHonors -> 16
    KongHidden -> 16
    KongHonorsHidden -> 32
    BonusPairWind -> 0
    BonusPairDragon -> 0
    BonusFlower -> 4
  }
}

fn item_code(item: ScoringItem) -> String {
  case item {
    Pung -> "p"
    PungHonors -> "ph"
    PungHidden -> "hp"
    PungHonorsHidden -> "hph"
    Kong -> "k"
    KongHonors -> "kh"
    KongHidden -> "hk"
    KongHonorsHidden -> "hkh"
    BonusPairWind -> "bpw"
    BonusPairDragon -> "bpd"
    BonusFlower -> "bf"
  }
}

// --- Model ---

pub type Wind {
  North
  South
  East
  West
}

pub type Player {
  Player1
  Player2
  Player3
  Player4
}

pub type PlayerHand {
  PlayerHand(items: List(ScoringItem))
}

pub type Model {
  Model(
    east_wind: Player,
    prevailing_wind: Wind,
    winner: Option(Player),
    hands: #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
  )
}

fn empty_hand() -> PlayerHand {
  PlayerHand(items: [])
}

fn init(_flags) -> Model {
  Model(
    east_wind: Player1,
    prevailing_wind: East,
    winner: None,
    hands: #(empty_hand(), empty_hand(), empty_hand(), empty_hand()),
  )
}

// --- Messages ---

pub type Msg {
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  AddItem(Player, ScoringItem)
  RemoveItem(Player, Int)
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SetEastWind(player) -> Model(..model, east_wind: player)
    SetPrevailingWind(wind) -> Model(..model, prevailing_wind: wind)
    SetWinner(winner) -> Model(..model, winner: winner)
    AddItem(player, item) -> add_item_to_hand(model, player, item)
    RemoveItem(player, index) -> remove_item_from_hand(model, player, index)
  }
}

fn add_item_to_hand(model: Model, player: Player, item: ScoringItem) -> Model {
  let hands = case player {
    Player1 -> #(
      add_to_hand(model.hands.0, item),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      add_to_hand(model.hands.1, item),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      add_to_hand(model.hands.2, item),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      add_to_hand(model.hands.3, item),
    )
  }
  Model(..model, hands: hands)
}

fn add_to_hand(hand: PlayerHand, item: ScoringItem) -> PlayerHand {
  PlayerHand(items: list.append(hand.items, [item]))
}

fn remove_item_from_hand(model: Model, player: Player, index: Int) -> Model {
  let hands = case player {
    Player1 -> #(
      remove_from_hand(model.hands.0, index),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      remove_from_hand(model.hands.1, index),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      remove_from_hand(model.hands.2, index),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      remove_from_hand(model.hands.3, index),
    )
  }
  Model(..model, hands: hands)
}

fn remove_from_hand(hand: PlayerHand, index: Int) -> PlayerHand {
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

fn calculate_hand_points(hand: PlayerHand, is_winner: Bool) -> Int {
  let base = list.fold(hand.items, 0, fn(total, item) { total + item_points(item) })
  case is_winner {
    True -> base + 20
    False -> base
  }
}

// --- View ---

fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    html.style([], styles()),
    h1([], [text("Alley Mah-jong")]),
    view_round_settings(model),
    view_all_hands(model),
  ])
}

fn view_round_settings(model: Model) -> Element(Msg) {
  div([class("round-settings")], [
    div([class("setting")], [
      html.label([], [text("East Wind: ")]),
      select([event.on_input(fn(val) { SetEastWind(parse_player(val)) })], [
        player_option(Player1, model.east_wind),
        player_option(Player2, model.east_wind),
        player_option(Player3, model.east_wind),
        player_option(Player4, model.east_wind),
      ]),
    ]),
    div([class("setting")], [
      html.label([], [text("Prevailing Wind: ")]),
      select([event.on_input(fn(val) { SetPrevailingWind(parse_wind(val)) })], [
        wind_option(East, model.prevailing_wind),
        wind_option(South, model.prevailing_wind),
        wind_option(West, model.prevailing_wind),
        wind_option(North, model.prevailing_wind),
      ]),
    ]),
    div([class("setting")], [
      html.label([], [text("Mah-jong'd: ")]),
      select([event.on_input(fn(val) { SetWinner(parse_winner(val)) })], [
        winner_option(None, model.winner),
        winner_option(Some(Player1), model.winner),
        winner_option(Some(Player2), model.winner),
        winner_option(Some(Player3), model.winner),
        winner_option(Some(Player4), model.winner),
      ]),
    ]),
  ])
}

fn player_option(player: Player, selected: Player) -> Element(Msg) {
  option(
    [
      attribute.value(player_to_string(player)),
      attribute.selected(player == selected),
    ],
    player_to_string(player),
  )
}

fn wind_option(wind: Wind, selected: Wind) -> Element(Msg) {
  option(
    [
      attribute.value(wind_to_string(wind)),
      attribute.selected(wind == selected),
    ],
    wind_to_string(wind),
  )
}

fn winner_option(winner: Option(Player), selected: Option(Player)) -> Element(Msg) {
  let label = case winner {
    None -> "None"
    Some(p) -> player_to_string(p)
  }
  option(
    [
      attribute.value(label),
      attribute.selected(winner == selected),
    ],
    label,
  )
}

fn view_all_hands(model: Model) -> Element(Msg) {
  div([class("all-hands")], [
    view_player_hand(Player1, model.hands.0, model.east_wind, model.winner),
    view_player_hand(Player2, model.hands.1, model.east_wind, model.winner),
    view_player_hand(Player3, model.hands.2, model.east_wind, model.winner),
    view_player_hand(Player4, model.hands.3, model.east_wind, model.winner),
  ])
}

fn view_player_hand(
  player: Player,
  hand: PlayerHand,
  east: Player,
  winner: Option(Player),
) -> Element(Msg) {
  let is_winner = winner == Some(player)
  let east_marker = case player == east {
    True -> " (East)"
    False -> ""
  }
  let winner_marker = case is_winner {
    True -> " - Mah-jong!"
    False -> ""
  }
  let hand_class = case is_winner {
    True -> "player-hand winner"
    False -> "player-hand"
  }
  let points = calculate_hand_points(hand, is_winner)
  div([class(hand_class)], [
    div([class("hand-header")], [
      h3([], [text(player_to_string(player) <> east_marker <> winner_marker)]),
      span([class("points")], [text(int.to_string(points) <> " pts")]),
    ]),
    div([class("hand-items")],
      list.index_map(hand.items, fn(item, i) {
        removable_item(player, item, i)
      }),
    ),
    div([class("add-items")], [
      item_button(player, Pung),
      item_button(player, PungHonors),
      item_button(player, PungHidden),
      item_button(player, PungHonorsHidden),
      item_button(player, Kong),
      item_button(player, KongHonors),
      item_button(player, KongHidden),
      item_button(player, KongHonorsHidden),
      item_button(player, BonusPairWind),
      item_button(player, BonusPairDragon),
      item_button(player, BonusFlower),
    ]),
  ])
}

fn item_button(player: Player, item: ScoringItem) -> Element(Msg) {
  let pts = item_points(item)
  let pts_text = case pts {
    0 -> ""
    n -> " (" <> int.to_string(n) <> ")"
  }
  button([class("scoring-item add"), event.on_click(AddItem(player, item))], [
    text(item_code(item) <> pts_text),
  ])
}

fn removable_item(player: Player, item: ScoringItem, index: Int) -> Element(Msg) {
  button(
    [class("scoring-item in-hand"), event.on_click(RemoveItem(player, index))],
    [text(item_code(item))],
  )
}

// --- Helpers ---

fn player_to_string(player: Player) -> String {
  case player {
    Player1 -> "Player 1"
    Player2 -> "Player 2"
    Player3 -> "Player 3"
    Player4 -> "Player 4"
  }
}

fn parse_player(s: String) -> Player {
  case s {
    "Player 1" -> Player1
    "Player 2" -> Player2
    "Player 3" -> Player3
    "Player 4" -> Player4
    _ -> Player1
  }
}

fn wind_to_string(wind: Wind) -> String {
  case wind {
    East -> "East"
    South -> "South"
    West -> "West"
    North -> "North"
  }
}

fn parse_wind(s: String) -> Wind {
  case s {
    "East" -> East
    "South" -> South
    "West" -> West
    "North" -> North
    _ -> East
  }
}

fn parse_winner(s: String) -> Option(Player) {
  case s {
    "Player 1" -> Some(Player1)
    "Player 2" -> Some(Player2)
    "Player 3" -> Some(Player3)
    "Player 4" -> Some(Player4)
    _ -> None
  }
}

fn styles() -> String {
  "
  .app {
    font-family: system-ui, sans-serif;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px;
  }
  .round-settings {
    display: flex;
    gap: 20px;
    margin-bottom: 20px;
    flex-wrap: wrap;
  }
  .setting {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .all-hands {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }
  @media (max-width: 700px) {
    .all-hands {
      grid-template-columns: 1fr;
    }
  }
  .player-hand {
    border: 1px solid #ddd;
    padding: 12px;
    border-radius: 8px;
    background: #fafafa;
  }
  .player-hand.winner {
    border-color: #ffc107;
    background: #fff8e1;
  }
  .hand-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  .hand-header h3 {
    margin: 0;
    font-size: 16px;
  }
  .points {
    font-weight: bold;
    color: #333;
    font-size: 18px;
  }
  .hand-items {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    min-height: 36px;
    margin-bottom: 10px;
    padding: 8px;
    background: #fff;
    border-radius: 4px;
    border: 1px dashed #ccc;
  }
  .add-items {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .scoring-item {
    padding: 6px 10px;
    border: 1px solid #999;
    background: #fff;
    cursor: pointer;
    font-weight: bold;
    font-size: 12px;
    border-radius: 4px;
  }
  .scoring-item.add {
    background: #e3f2fd;
    border-color: #90caf9;
  }
  .scoring-item.add:hover {
    background: #bbdefb;
  }
  .scoring-item.in-hand {
    background: #fffde7;
    border-color: #fdd835;
  }
  .scoring-item.in-hand:hover {
    background: #ffcdd2;
    border-color: #e57373;
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
