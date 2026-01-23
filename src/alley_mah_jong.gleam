import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h3, option, select, span}
import lustre/event
import storage

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
  // Pair of own/prevailing wind
  BonusPairDragon
  // Pair of dragon
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
    BonusPairWind -> 0
    BonusPairDragon -> 0
    BonusFlower -> 4
  }
}

fn item_label(item: ScoringItem) -> String {
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

fn item_display(item: ScoringItem) -> String {
  let pts = item_points(item)
  let label = item_label(item)
  case pts {
    0 -> label
    n -> label <> " (" <> int.to_string(n) <> ")"
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
    names: #(String, String, String, String),
  )
}

fn empty_hand() -> PlayerHand {
  PlayerHand(items: [])
}

fn default_model() -> Model {
  Model(
    east_wind: Player1,
    prevailing_wind: East,
    winner: None,
    hands: #(empty_hand(), empty_hand(), empty_hand(), empty_hand()),
    names: #("", "", "", ""),
  )
}

fn init(_flags) -> Model {
  case storage.load_state() {
    Some(state) -> model_from_state(state)
    None -> default_model()
  }
}

// --- State Conversion ---

pub fn model_to_state(model: Model) -> storage.GameState {
  storage.GameState(
    east_wind: player_to_storage(model.east_wind),
    prevailing_wind: wind_to_storage(model.prevailing_wind),
    winner: option.map(model.winner, player_to_storage),
    hands: #(
      hand_to_storage(model.hands.0),
      hand_to_storage(model.hands.1),
      hand_to_storage(model.hands.2),
      hand_to_storage(model.hands.3),
    ),
    names: model.names,
  )
}

fn model_from_state(state: storage.GameState) -> Model {
  Model(
    east_wind: player_from_storage(state.east_wind),
    prevailing_wind: wind_from_storage(state.prevailing_wind),
    winner: option.map(state.winner, player_from_storage),
    hands: #(
      hand_from_storage(state.hands.0),
      hand_from_storage(state.hands.1),
      hand_from_storage(state.hands.2),
      hand_from_storage(state.hands.3),
    ),
    names: state.names,
  )
}

fn player_to_storage(player: Player) -> storage.Player {
  case player {
    Player1 -> storage.Player1
    Player2 -> storage.Player2
    Player3 -> storage.Player3
    Player4 -> storage.Player4
  }
}

fn player_from_storage(player: storage.Player) -> Player {
  case player {
    storage.Player1 -> Player1
    storage.Player2 -> Player2
    storage.Player3 -> Player3
    storage.Player4 -> Player4
  }
}

fn wind_to_storage(wind: Wind) -> storage.Wind {
  case wind {
    North -> storage.North
    South -> storage.South
    East -> storage.East
    West -> storage.West
  }
}

fn wind_from_storage(wind: storage.Wind) -> Wind {
  case wind {
    storage.North -> North
    storage.South -> South
    storage.East -> East
    storage.West -> West
  }
}

fn hand_to_storage(hand: PlayerHand) -> storage.PlayerHand {
  storage.PlayerHand(items: list.map(hand.items, item_to_storage))
}

fn hand_from_storage(hand: storage.PlayerHand) -> PlayerHand {
  PlayerHand(items: list.map(hand.items, item_from_storage))
}

fn item_to_storage(item: ScoringItem) -> storage.ScoringItem {
  case item {
    Pung -> storage.Pung
    PungHonors -> storage.PungHonors
    PungHidden -> storage.PungHidden
    PungHonorsHidden -> storage.PungHonorsHidden
    Kong -> storage.Kong
    KongHonors -> storage.KongHonors
    KongHidden -> storage.KongHidden
    KongHonorsHidden -> storage.KongHonorsHidden
    BonusPairWind -> storage.BonusPairWind
    BonusPairDragon -> storage.BonusPairDragon
    BonusFlower -> storage.BonusFlower
  }
}

fn item_from_storage(item: storage.ScoringItem) -> ScoringItem {
  case item {
    storage.Pung -> Pung
    storage.PungHonors -> PungHonors
    storage.PungHidden -> PungHidden
    storage.PungHonorsHidden -> PungHonorsHidden
    storage.Kong -> Kong
    storage.KongHonors -> KongHonors
    storage.KongHidden -> KongHidden
    storage.KongHonorsHidden -> KongHonorsHidden
    storage.BonusPairWind -> BonusPairWind
    storage.BonusPairDragon -> BonusPairDragon
    storage.BonusFlower -> BonusFlower
  }
}

fn save_model(model: Model) -> Nil {
  storage.save_state(model_to_state(model))
}

// --- Messages ---

pub type Msg {
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  SetPlayerName(Player, String)
  AddItem(Player, ScoringItem)
  RemoveItem(Player, Int)
  NewRound
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  let new_model = case msg {
    SetEastWind(player) -> Model(..model, east_wind: player)
    SetPrevailingWind(wind) -> Model(..model, prevailing_wind: wind)
    SetWinner(winner) -> Model(..model, winner: winner)
    SetPlayerName(player, name) -> set_player_name(model, player, name)
    AddItem(player, item) -> add_item_to_hand(model, player, item)
    RemoveItem(player, index) -> remove_item_from_hand(model, player, index)
    NewRound ->
      Model(..model, winner: None, hands: #(
        empty_hand(),
        empty_hand(),
        empty_hand(),
        empty_hand(),
      ))
  }
  save_model(new_model)
  new_model
}

fn set_player_name(model: Model, player: Player, name: String) -> Model {
  let names = case player {
    Player1 -> #(name, model.names.1, model.names.2, model.names.3)
    Player2 -> #(model.names.0, name, model.names.2, model.names.3)
    Player3 -> #(model.names.0, model.names.1, name, model.names.3)
    Player4 -> #(model.names.0, model.names.1, model.names.2, name)
  }
  Model(..model, names: names)
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

pub fn calculate_hand_points(hand: PlayerHand, is_winner: Bool) -> Int {
  let base =
    list.fold(hand.items, 0, fn(total, item) { total + item_points(item) })
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
  div([class("settings-container")], [
    div([class("round-settings")], [
      div([class("setting")], [
        html.label([], [text("East Wind: ")]),
        select([event.on_input(fn(val) { SetEastWind(parse_player(val)) })], [
          player_option(Player1, model.east_wind, model.names),
          player_option(Player2, model.east_wind, model.names),
          player_option(Player3, model.east_wind, model.names),
          player_option(Player4, model.east_wind, model.names),
        ]),
      ]),
      div([class("setting")], [
        html.label([], [text("Prevailing Wind: ")]),
        select(
          [event.on_input(fn(val) { SetPrevailingWind(parse_wind(val)) })],
          [
            wind_option(East, model.prevailing_wind),
            wind_option(South, model.prevailing_wind),
            wind_option(West, model.prevailing_wind),
            wind_option(North, model.prevailing_wind),
          ],
        ),
      ]),
      div([class("setting")], [
        html.label([], [text("Mah-jong'd: ")]),
        select([event.on_input(fn(val) { SetWinner(parse_winner(val)) })], [
          winner_option(None, model.winner, model.names),
          winner_option(Some(Player1), model.winner, model.names),
          winner_option(Some(Player2), model.winner, model.names),
          winner_option(Some(Player3), model.winner, model.names),
          winner_option(Some(Player4), model.winner, model.names),
        ]),
      ]),
      button([class("new-round-btn"), event.on_click(NewRound)], [
        text("New Round"),
      ]),
    ]),
    div([class("name-settings")], [
      name_input(Player1, model.names.0),
      name_input(Player2, model.names.1),
      name_input(Player3, model.names.2),
      name_input(Player4, model.names.3),
    ]),
  ])
}

fn name_input(player: Player, current_name: String) -> Element(Msg) {
  html.input([
    class("name-input"),
    attribute.value(current_name),
    attribute.placeholder(player_to_string(player)),
    event.on_input(fn(val) { SetPlayerName(player, val) }),
  ])
}

fn player_option(
  player: Player,
  selected: Player,
  names: #(String, String, String, String),
) -> Element(Msg) {
  let display_name = get_player_name(player, names)
  option(
    [
      attribute.value(player_to_string(player)),
      attribute.selected(player == selected),
    ],
    display_name,
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

fn winner_option(
  winner: Option(Player),
  selected: Option(Player),
  names: #(String, String, String, String),
) -> Element(Msg) {
  let #(label, value) = case winner {
    None -> #("None", "None")
    Some(p) -> #(get_player_name(p, names), player_to_string(p))
  }
  option(
    [attribute.value(value), attribute.selected(winner == selected)],
    label,
  )
}

fn view_all_hands(model: Model) -> Element(Msg) {
  div([class("all-hands")], [
    view_player_hand(
      Player1,
      model.hands.0,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player2,
      model.hands.1,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player3,
      model.hands.2,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player4,
      model.hands.3,
      model.east_wind,
      model.winner,
      model.names,
    ),
  ])
}

fn view_player_hand(
  player: Player,
  hand: PlayerHand,
  east: Player,
  winner: Option(Player),
  names: #(String, String, String, String),
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
      h3([], [
        text(get_player_name(player, names) <> east_marker <> winner_marker),
      ]),
      span([class("points")], [text(int.to_string(points) <> " pts")]),
    ]),
    div(
      [class("hand-items")],
      list.index_map(hand.items, fn(item, i) { removable_item(player, item, i) }),
    ),
    div([class("add-section")], [
      div([class("add-row")], [
        span([class("row-label")], [text("Revealed:")]),
        item_button(player, Pung),
        item_button(player, PungHonors),
        item_button(player, Kong),
        item_button(player, KongHonors),
      ]),
      div([class("add-row")], [
        span([class("row-label")], [text("Hidden:")]),
        item_button(player, PungHidden),
        item_button(player, PungHonorsHidden),
        item_button(player, KongHidden),
        item_button(player, KongHonorsHidden),
      ]),
      div([class("add-row")], [
        span([class("row-label")], [text("Bonus:")]),
        item_button(player, BonusPairWind),
        item_button(player, BonusPairDragon),
        item_button(player, BonusFlower),
      ]),
    ]),
  ])
}

fn item_button(player: Player, item: ScoringItem) -> Element(Msg) {
  button([class("scoring-item add"), event.on_click(AddItem(player, item))], [
    text(item_label(item)),
  ])
}

fn removable_item(player: Player, item: ScoringItem, index: Int) -> Element(Msg) {
  button(
    [class("scoring-item in-hand"), event.on_click(RemoveItem(player, index))],
    [text(item_display(item))],
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

fn get_player_name(
  player: Player,
  names: #(String, String, String, String),
) -> String {
  let name = case player {
    Player1 -> names.0
    Player2 -> names.1
    Player3 -> names.2
    Player4 -> names.3
  }
  case name {
    "" -> player_to_string(player)
    _ -> name
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
  /* Vintage typewriter aesthetic */
  :root {
    --cream: #f4f1e8;
    --paper: #faf8f3;
    --carbon: #2c2c2c;
    --carbon-light: #4a4a4a;
    --carbon-faded: #8a8a8a;
    --btn-dark: #e8e4d9;
    --btn-darker: #ddd8c9;
    --ink-purple: #4a235a;
  }
  body {
    background: var(--cream);
    margin: 0;
  }
  .app {
    font-family: 'Courier New', Courier, monospace;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px;
    color: var(--carbon);
  }
  h1 {
    text-transform: uppercase;
    letter-spacing: 4px;
    border-bottom: 2px solid var(--carbon);
    padding-bottom: 8px;
    margin-bottom: 24px;
  }
  .settings-container {
    margin-bottom: 24px;
    background: var(--paper);
    border: 2px solid var(--carbon-faded);
    border-radius: 1px;
    box-shadow:
      3px 3px 0 rgba(44,44,44,0.15),
      5px 5px 8px rgba(44,44,44,0.08),
      1px 1px 0 rgba(44,44,44,0.2);
  }
  .round-settings {
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
    padding: 16px;
    padding-bottom: 12px;
  }
  .name-settings {
    display: flex;
    gap: 12px;
    padding: 12px 16px;
    border-top: 1px dashed var(--carbon-faded);
    flex-wrap: wrap;
  }
  .name-input {
    font-family: 'Courier New', Courier, monospace;
    padding: 6px 10px;
    border: 1px solid var(--carbon-faded);
    background: var(--cream);
    font-size: 13px;
    flex: 1;
    min-width: 100px;
    max-width: 180px;
  }
  .name-input:focus {
    outline: none;
    border-color: var(--carbon);
    background: var(--paper);
  }
  .setting {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .setting label {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 1px;
  }
  .setting select {
    font-family: 'Courier New', Courier, monospace;
    padding: 4px 8px;
    border: 1px solid var(--carbon-faded);
    background: var(--btn-dark);
    font-size: 14px;
  }
  .new-round-btn {
    padding: 8px 16px;
    background: var(--btn-darker);
    color: var(--ink-purple);
    border: 2px solid var(--ink-purple);
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 1px;
    box-shadow:
      2px 2px 0 rgba(74,35,90,0.2),
      3px 3px 6px rgba(44,44,44,0.1);
  }
  .new-round-btn:hover {
    background: var(--ink-purple);
    color: var(--paper);
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
    padding: 12px;
    background: var(--paper);
    border: 2px solid var(--carbon-faded);
    box-shadow:
      2px 2px 0 rgba(44,44,44,0.12),
      4px 4px 8px rgba(44,44,44,0.06),
      1px 0 0 rgba(44,44,44,0.15);
  }
  .player-hand.winner {
    border-color: var(--carbon);
    border-width: 3px;
    background: var(--paper);
    box-shadow:
      3px 3px 0 rgba(44,44,44,0.18),
      5px 5px 10px rgba(44,44,44,0.08),
      inset 0 0 30px rgba(139, 0, 0, 0.04);
  }
  .player-hand.winner .hand-header h3::after {
    content: ' ★';
    color: var(--ink-purple);
    font-size: 1.3em;
  }
  .hand-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
    border-bottom: 1px dashed var(--carbon-faded);
    padding-bottom: 8px;
  }
  .hand-header h3 {
    margin: 0;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 1px;
  }
  .points {
    font-weight: bold;
    color: var(--carbon);
    font-size: 18px;
  }
  .hand-items {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    min-height: 36px;
    margin-bottom: 10px;
    padding: 8px;
    background: var(--paper);
    border: 1px dotted var(--carbon-faded);
    opacity: 0.9;
  }
  .add-section {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding-top: 8px;
    border-top: 1px dotted var(--carbon-faded);
  }
  .add-row {
    display: flex;
    gap: 4px;
    align-items: center;
    flex-wrap: wrap;
  }
  .row-label {
    font-size: 10px;
    color: var(--carbon-light);
    width: 62px;
    flex-shrink: 0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .scoring-item {
    padding: 3px 6px;
    border: 1px solid var(--carbon-faded);
    background: var(--btn-dark);
    cursor: pointer;
    font-size: 10px;
    font-family: 'Courier New', Courier, monospace;
    box-shadow: 1px 1px 0 rgba(44,44,44,0.1);
    white-space: nowrap;
  }
  .scoring-item.add {
    background: var(--btn-dark);
    border-color: var(--carbon-faded);
  }
  .scoring-item.add:hover {
    background: var(--btn-darker);
    border-color: var(--carbon);
    box-shadow:
      1px 1px 0 rgba(44,44,44,0.15),
      2px 2px 4px rgba(44,44,44,0.08);
  }
  .scoring-item.in-hand {
    background: var(--btn-dark);
    border: 1px solid var(--carbon-faded);
    font-weight: bold;
  }
  .scoring-item.in-hand:hover {
    background: #e0d5c5;
    border-color: var(--ink-purple);
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
