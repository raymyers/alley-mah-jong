import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h2, h3, option, select, span}
import lustre/event

// --- Scoring Items ---

pub type ScoringItem {
  // Pungs (3 of a kind)
  Pung          // 2-8 revealed: 2 pts
  PungHonors    // 1,9,W,D revealed: 4 pts
  PungHidden    // 2-8 hidden: 4 pts
  PungHonorsHidden  // 1,9,W,D hidden: 8 pts
  // Kongs (4 of a kind)
  Kong          // 2-8 revealed: 8 pts
  KongHonors    // 1,9,W,D revealed: 16 pts
  KongHidden    // 2-8 hidden: 16 pts
  KongHonorsHidden  // 1,9,W,D hidden: 32 pts
  // Bonuses
  BonusPairWind    // Pair of own/prevailing wind
  BonusPairDragon  // Pair of dragon
  BonusFlower      // Flower: 4 pts
  // Winning
  MahJong          // 20 pts
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
    BonusPairWind -> 0  // Contributes to doubles, not base points
    BonusPairDragon -> 0
    BonusFlower -> 4
    MahJong -> 20
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
    MahJong -> "mj"
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
    selected_player: Player,
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
    selected_player: Player1,
  )
}

// --- Messages ---

pub type Msg {
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  SelectPlayer(Player)
  AddItem(ScoringItem)
  RemoveItem(Player, Int)
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SetEastWind(player) -> Model(..model, east_wind: player)
    SetPrevailingWind(wind) -> Model(..model, prevailing_wind: wind)
    SetWinner(winner) -> Model(..model, winner: winner)
    SelectPlayer(player) -> Model(..model, selected_player: player)
    AddItem(item) -> add_item_to_hand(model, item)
    RemoveItem(player, index) -> remove_item_from_hand(model, player, index)
  }
}

fn add_item_to_hand(model: Model, item: ScoringItem) -> Model {
  let hands = case model.selected_player {
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

fn calculate_hand_points(hand: PlayerHand) -> Int {
  list.fold(hand.items, 0, fn(total, item) { total + item_points(item) })
}

// --- View ---

fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    html.style([], styles()),
    h1([], [text("Alley Mah-jong")]),
    view_round_settings(model),
    view_player_tabs(model),
    view_scoring_palette(),
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

fn view_player_tabs(model: Model) -> Element(Msg) {
  div([class("player-tabs")], [
    player_tab(Player1, model.selected_player, model.east_wind),
    player_tab(Player2, model.selected_player, model.east_wind),
    player_tab(Player3, model.selected_player, model.east_wind),
    player_tab(Player4, model.selected_player, model.east_wind),
  ])
}

fn player_tab(player: Player, selected: Player, east: Player) -> Element(Msg) {
  let selected_class = case player == selected {
    True -> " selected"
    False -> ""
  }
  let east_marker = case player == east {
    True -> " (E)"
    False -> ""
  }
  button(
    [class("player-tab" <> selected_class), event.on_click(SelectPlayer(player))],
    [text(player_to_string(player) <> east_marker)],
  )
}

fn view_scoring_palette() -> Element(Msg) {
  div([class("scoring-palette")], [
    h2([], [text("Add Scoring Items")]),
    div([class("item-section")], [
      h3([], [text("Pungs (3 of a kind)")]),
      div([class("item-row")], [
        item_button(Pung),
        item_button(PungHonors),
        item_button(PungHidden),
        item_button(PungHonorsHidden),
      ]),
    ]),
    div([class("item-section")], [
      h3([], [text("Kongs (4 of a kind)")]),
      div([class("item-row")], [
        item_button(Kong),
        item_button(KongHonors),
        item_button(KongHidden),
        item_button(KongHonorsHidden),
      ]),
    ]),
    div([class("item-section")], [
      h3([], [text("Bonuses")]),
      div([class("item-row")], [
        item_button(BonusPairWind),
        item_button(BonusPairDragon),
        item_button(BonusFlower),
        item_button(MahJong),
      ]),
    ]),
  ])
}

fn item_button(item: ScoringItem) -> Element(Msg) {
  let pts = item_points(item)
  let pts_text = case pts {
    0 -> ""
    n -> " (" <> int.to_string(n) <> ")"
  }
  button([class("scoring-item"), event.on_click(AddItem(item))], [
    text(item_code(item) <> pts_text),
  ])
}

fn view_all_hands(model: Model) -> Element(Msg) {
  div([class("all-hands")], [
    h2([], [text("Hands")]),
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
  let east_marker = case player == east {
    True -> " (East)"
    False -> ""
  }
  let winner_marker = case winner {
    Some(w) if w == player -> " - Mah-jong!"
    _ -> ""
  }
  let hand_class = case winner {
    Some(w) if w == player -> "player-hand winner"
    _ -> "player-hand"
  }
  let points = calculate_hand_points(hand)
  div([class(hand_class)], [
    h3([], [
      text(player_to_string(player) <> east_marker <> winner_marker),
      span([class("points")], [text(" - " <> int.to_string(points) <> " pts")]),
    ]),
    div([class("hand-items")],
      list.index_map(hand.items, fn(item, i) {
        removable_item(player, item, i)
      }),
    ),
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
    max-width: 800px;
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
  .player-tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
  }
  .player-tab {
    padding: 8px 16px;
    border: 1px solid #ccc;
    background: #f5f5f5;
    cursor: pointer;
  }
  .player-tab.selected {
    background: #007bff;
    color: white;
    border-color: #007bff;
  }
  .scoring-palette {
    background: #f9f9f9;
    padding: 16px;
    border-radius: 8px;
    margin-bottom: 20px;
  }
  .item-section {
    margin-bottom: 12px;
  }
  .item-section h3 {
    margin: 0 0 8px 0;
    font-size: 14px;
    color: #666;
  }
  .item-row {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .scoring-item {
    padding: 8px 12px;
    border: 1px solid #999;
    background: #fff;
    cursor: pointer;
    font-weight: bold;
    font-size: 14px;
    border-radius: 4px;
  }
  .scoring-item:hover {
    background: #e0e0e0;
  }
  .scoring-item.in-hand {
    background: #fffde7;
  }
  .scoring-item.in-hand:hover {
    background: #ffcdd2;
  }
  .all-hands {
    margin-top: 20px;
  }
  .player-hand {
    border: 1px solid #ddd;
    padding: 12px;
    margin-bottom: 12px;
    border-radius: 4px;
  }
  .player-hand.winner {
    border-color: #ffc107;
    background: #fff8e1;
  }
  .player-hand h3 {
    margin: 0 0 8px 0;
  }
  .points {
    font-weight: normal;
    color: #666;
  }
  .hand-items {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    min-height: 40px;
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
