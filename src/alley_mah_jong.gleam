import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h2, h3, option, select, span}
import lustre/event

// --- Tiles ---

pub type Suit {
  Sticks
  Circles
  Characters
}

pub type Dragon {
  GreenDragon
  RedDragon
  WhiteDragon
}

pub type Wind {
  North
  South
  East
  West
}

pub type FlowerColor {
  BlueFlower
  RedFlower
}

pub type Tile {
  SuitTile(suit: Suit, value: Int)
  DragonTile(Dragon)
  WindTile(Wind)
  FlowerTile(color: FlowerColor, number: Int)
}

// --- Model ---

pub type Player {
  Player1
  Player2
  Player3
  Player4
}

pub type Hand {
  Hand(hidden: List(Tile), revealed: List(Tile))
}

pub type Model {
  Model(
    east_wind: Player,
    prevailing_wind: Wind,
    winner: Option(Player),
    hands: #(Hand, Hand, Hand, Hand),
    selected_player: Player,
    adding_to: AddingTo,
  )
}

pub type AddingTo {
  Hidden
  Revealed
}

fn empty_hand() -> Hand {
  Hand(hidden: [], revealed: [])
}

fn init(_flags) -> Model {
  Model(
    east_wind: Player1,
    prevailing_wind: East,
    winner: None,
    hands: #(empty_hand(), empty_hand(), empty_hand(), empty_hand()),
    selected_player: Player1,
    adding_to: Hidden,
  )
}

// --- Messages ---

pub type Msg {
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  SelectPlayer(Player)
  SetAddingTo(AddingTo)
  AddTile(Tile)
  RemoveTile(Player, AddingTo, Int)
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SetEastWind(player) -> Model(..model, east_wind: player)
    SetPrevailingWind(wind) -> Model(..model, prevailing_wind: wind)
    SetWinner(winner) -> Model(..model, winner: winner)
    SelectPlayer(player) -> Model(..model, selected_player: player)
    SetAddingTo(adding_to) -> Model(..model, adding_to: adding_to)
    AddTile(tile) -> add_tile_to_hand(model, tile)
    RemoveTile(player, adding_to, index) ->
      remove_tile_from_hand(model, player, adding_to, index)
  }
}

fn add_tile_to_hand(model: Model, tile: Tile) -> Model {
  let hands = case model.selected_player {
    Player1 -> #(
      add_to_hand(model.hands.0, tile, model.adding_to),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      add_to_hand(model.hands.1, tile, model.adding_to),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      add_to_hand(model.hands.2, tile, model.adding_to),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      add_to_hand(model.hands.3, tile, model.adding_to),
    )
  }
  Model(..model, hands: hands)
}

fn add_to_hand(hand: Hand, tile: Tile, adding_to: AddingTo) -> Hand {
  case adding_to {
    Hidden -> Hand(..hand, hidden: list.append(hand.hidden, [tile]))
    Revealed -> Hand(..hand, revealed: list.append(hand.revealed, [tile]))
  }
}

fn remove_tile_from_hand(
  model: Model,
  player: Player,
  adding_to: AddingTo,
  index: Int,
) -> Model {
  let hands = case player {
    Player1 -> #(
      remove_from_hand(model.hands.0, adding_to, index),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      remove_from_hand(model.hands.1, adding_to, index),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      remove_from_hand(model.hands.2, adding_to, index),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      remove_from_hand(model.hands.3, adding_to, index),
    )
  }
  Model(..model, hands: hands)
}

fn remove_from_hand(hand: Hand, adding_to: AddingTo, index: Int) -> Hand {
  case adding_to {
    Hidden -> Hand(..hand, hidden: remove_at(hand.hidden, index))
    Revealed -> Hand(..hand, revealed: remove_at(hand.revealed, index))
  }
}

fn remove_at(items: List(a), index: Int) -> List(a) {
  list.index_fold(items, [], fn(acc, item, i) {
    case i == index {
      True -> acc
      False -> list.append(acc, [item])
    }
  })
}

// --- View ---

fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    html.style([], styles()),
    h1([], [text("Alley Mah-jong")]),
    view_round_settings(model),
    view_player_tabs(model),
    view_adding_toggle(model),
    view_tile_palette(),
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

fn view_adding_toggle(model: Model) -> Element(Msg) {
  div([class("adding-toggle")], [
    html.label([], [text("Add tiles to: ")]),
    button(
      [
        class(case model.adding_to {
          Hidden -> "toggle-btn selected"
          Revealed -> "toggle-btn"
        }),
        event.on_click(SetAddingTo(Hidden)),
      ],
      [text("Hidden")],
    ),
    button(
      [
        class(case model.adding_to {
          Revealed -> "toggle-btn selected"
          Hidden -> "toggle-btn"
        }),
        event.on_click(SetAddingTo(Revealed)),
      ],
      [text("Revealed")],
    ),
  ])
}

fn view_tile_palette() -> Element(Msg) {
  div([class("tile-palette")], [
    h2([], [text("Tiles")]),
    div([class("tile-section")], [
      h3([], [text("Sticks")]),
      div([class("tile-row")], list.map(list.range(1, 9), fn(n) {
        tile_button(SuitTile(Sticks, n))
      })),
    ]),
    div([class("tile-section")], [
      h3([], [text("Circles")]),
      div([class("tile-row")], list.map(list.range(1, 9), fn(n) {
        tile_button(SuitTile(Circles, n))
      })),
    ]),
    div([class("tile-section")], [
      h3([], [text("Characters")]),
      div([class("tile-row")], list.map(list.range(1, 9), fn(n) {
        tile_button(SuitTile(Characters, n))
      })),
    ]),
    div([class("tile-section")], [
      h3([], [text("Dragons")]),
      div([class("tile-row")], [
        tile_button(DragonTile(GreenDragon)),
        tile_button(DragonTile(RedDragon)),
        tile_button(DragonTile(WhiteDragon)),
      ]),
    ]),
    div([class("tile-section")], [
      h3([], [text("Winds")]),
      div([class("tile-row")], [
        tile_button(WindTile(East)),
        tile_button(WindTile(South)),
        tile_button(WindTile(West)),
        tile_button(WindTile(North)),
      ]),
    ]),
    div([class("tile-section")], [
      h3([], [text("Flowers")]),
      div([class("tile-row")], [
        tile_button(FlowerTile(BlueFlower, 1)),
        tile_button(FlowerTile(BlueFlower, 2)),
        tile_button(FlowerTile(BlueFlower, 3)),
        tile_button(FlowerTile(BlueFlower, 4)),
        tile_button(FlowerTile(RedFlower, 1)),
        tile_button(FlowerTile(RedFlower, 2)),
        tile_button(FlowerTile(RedFlower, 3)),
        tile_button(FlowerTile(RedFlower, 4)),
      ]),
    ]),
  ])
}

fn tile_button(tile: Tile) -> Element(Msg) {
  button([class("tile"), event.on_click(AddTile(tile))], [
    text(tile_to_string(tile)),
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
  hand: Hand,
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
  div([class(hand_class)], [
    h3([], [text(player_to_string(player) <> east_marker <> winner_marker)]),
    div([class("hand-section")], [
      span([class("hand-label")], [text("Hidden: ")]),
      div(
        [class("tiles")],
        list.index_map(hand.hidden, fn(tile, i) {
          removable_tile(player, Hidden, tile, i)
        }),
      ),
    ]),
    div([class("hand-section")], [
      span([class("hand-label")], [text("Revealed: ")]),
      div(
        [class("tiles")],
        list.index_map(hand.revealed, fn(tile, i) {
          removable_tile(player, Revealed, tile, i)
        }),
      ),
    ]),
  ])
}

fn removable_tile(
  player: Player,
  adding_to: AddingTo,
  tile: Tile,
  index: Int,
) -> Element(Msg) {
  button(
    [class("tile in-hand"), event.on_click(RemoveTile(player, adding_to, index))],
    [text(tile_to_string(tile))],
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

fn tile_to_string(tile: Tile) -> String {
  case tile {
    SuitTile(Sticks, n) -> int.to_string(n) <> "S"
    SuitTile(Circles, n) -> int.to_string(n) <> "C"
    SuitTile(Characters, n) -> int.to_string(n) <> "W"
    DragonTile(GreenDragon) -> "DG"
    DragonTile(RedDragon) -> "DR"
    DragonTile(WhiteDragon) -> "DW"
    WindTile(East) -> "E"
    WindTile(South) -> "S"
    WindTile(West) -> "W"
    WindTile(North) -> "N"
    FlowerTile(BlueFlower, n) -> "B" <> int.to_string(n)
    FlowerTile(RedFlower, n) -> "R" <> int.to_string(n)
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
  .adding-toggle {
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .toggle-btn {
    padding: 6px 12px;
    border: 1px solid #ccc;
    background: #f5f5f5;
    cursor: pointer;
  }
  .toggle-btn.selected {
    background: #28a745;
    color: white;
    border-color: #28a745;
  }
  .tile-palette {
    background: #f9f9f9;
    padding: 16px;
    border-radius: 8px;
    margin-bottom: 20px;
  }
  .tile-section {
    margin-bottom: 12px;
  }
  .tile-section h3 {
    margin: 0 0 8px 0;
    font-size: 14px;
    color: #666;
  }
  .tile-row {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .tile {
    width: 36px;
    height: 48px;
    border: 1px solid #999;
    background: #fff;
    cursor: pointer;
    font-weight: bold;
    font-size: 12px;
  }
  .tile:hover {
    background: #e0e0e0;
  }
  .tile.in-hand {
    background: #fffde7;
  }
  .tile.in-hand:hover {
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
  .hand-section {
    display: flex;
    align-items: center;
    margin-bottom: 8px;
  }
  .hand-label {
    width: 80px;
    font-weight: bold;
  }
  .tiles {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    min-height: 48px;
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
