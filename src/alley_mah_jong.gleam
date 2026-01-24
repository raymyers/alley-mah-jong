import engine.{
  type DoublesContext, type Player, type PlayerHand, type ScoringItem, type Wind,
  BonusFlower, BonusPairDragon, BonusPairWind, DoublesContext, East, Kong,
  KongHidden, KongHonors, KongHonorsHidden, North, Player1, Player2, Player3,
  Player4, PlayerHand, Pung, PungHidden, PungHonors, PungHonorsHidden, South,
  West,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h3, option, select, span}
import lustre/event
import storage

// --- UI Model ---

pub type Page {
  MainPage
  RulesPage
}

pub type HandStatus {
  Dirty
  Clean
  Limit
}

pub type Model {
  Model(
    page: Page,
    east_wind: Player,
    prevailing_wind: Wind,
    winner: Option(Player),
    hands: #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
    names: #(String, String, String, String),
    doubles: #(DoublesContext, DoublesContext, DoublesContext, DoublesContext),
    hand_statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
  )
}

fn default_model() -> Model {
  Model(
    page: MainPage,
    east_wind: Player1,
    prevailing_wind: East,
    winner: None,
    hands: #(
      engine.empty_hand(),
      engine.empty_hand(),
      engine.empty_hand(),
      engine.empty_hand(),
    ),
    names: #("", "", "", ""),
    doubles: #(
      engine.no_doubles(),
      engine.no_doubles(),
      engine.no_doubles(),
      engine.no_doubles(),
    ),
    hand_statuses: #(Dirty, Dirty, Dirty, Dirty),
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
    doubles: #(
      doubles_to_storage(model.doubles.0),
      doubles_to_storage(model.doubles.1),
      doubles_to_storage(model.doubles.2),
      doubles_to_storage(model.doubles.3),
    ),
    hand_statuses: #(
      hand_status_to_storage(model.hand_statuses.0),
      hand_status_to_storage(model.hand_statuses.1),
      hand_status_to_storage(model.hand_statuses.2),
      hand_status_to_storage(model.hand_statuses.3),
    ),
  )
}

fn model_from_state(state: storage.GameState) -> Model {
  Model(
    page: MainPage,
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
    doubles: #(
      doubles_from_storage(state.doubles.0),
      doubles_from_storage(state.doubles.1),
      doubles_from_storage(state.doubles.2),
      doubles_from_storage(state.doubles.3),
    ),
    hand_statuses: #(
      hand_status_from_storage(state.hand_statuses.0),
      hand_status_from_storage(state.hand_statuses.1),
      hand_status_from_storage(state.hand_statuses.2),
      hand_status_from_storage(state.hand_statuses.3),
    ),
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

fn doubles_to_storage(ctx: DoublesContext) -> storage.DoublesContext {
  storage.DoublesContext(
    is_clean: ctx.is_clean,
    has_dragon_pung_or_kong: ctx.has_dragon_pung_or_kong,
    has_own_wind_pung_or_kong: ctx.has_own_wind_pung_or_kong,
    has_prevailing_wind_pung_or_kong: ctx.has_prevailing_wind_pung_or_kong,
    has_both_own_flowers: ctx.has_both_own_flowers,
    is_east_wind: ctx.is_east_wind,
    has_all_red_flowers: ctx.has_all_red_flowers,
    has_all_blue_flowers: ctx.has_all_blue_flowers,
    is_clean_no_winds_or_dragons: ctx.is_clean_no_winds_or_dragons,
  )
}

fn doubles_from_storage(ctx: storage.DoublesContext) -> DoublesContext {
  DoublesContext(
    is_clean: ctx.is_clean,
    has_dragon_pung_or_kong: ctx.has_dragon_pung_or_kong,
    has_own_wind_pung_or_kong: ctx.has_own_wind_pung_or_kong,
    has_prevailing_wind_pung_or_kong: ctx.has_prevailing_wind_pung_or_kong,
    has_both_own_flowers: ctx.has_both_own_flowers,
    is_east_wind: ctx.is_east_wind,
    has_all_red_flowers: ctx.has_all_red_flowers,
    has_all_blue_flowers: ctx.has_all_blue_flowers,
    is_clean_no_winds_or_dragons: ctx.is_clean_no_winds_or_dragons,
  )
}

fn hand_status_to_storage(status: HandStatus) -> storage.HandStatus {
  case status {
    Dirty -> storage.Dirty
    Clean -> storage.Clean
    Limit -> storage.Limit
  }
}

fn hand_status_from_storage(status: storage.HandStatus) -> HandStatus {
  case status {
    storage.Dirty -> Dirty
    storage.Clean -> Clean
    storage.Limit -> Limit
  }
}

fn save_model(model: Model) -> Nil {
  storage.save_state(model_to_state(model))
}

// --- Double Conditions (for UI toggling) ---

pub type DoubleCondition {
  HasDragonPungOrKong
  HasOwnWindPungOrKong
  HasPrevailingWindPungOrKong
  HasBothOwnFlowers
  HasAllRedFlowers
  HasAllBlueFlowers
  IsCleanNoWindsOrDragons
}

// --- Messages ---

pub type Msg {
  GoToPage(Page)
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  SetPlayerName(Player, String)
  AddItem(Player, ScoringItem)
  RemoveItem(Player, Int)
  ToggleDouble(Player, DoubleCondition)
  SetHandStatus(Player, HandStatus)
  NewRound
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    GoToPage(page) -> Model(..model, page: page)
    _ -> {
      let new_model = case msg {
        GoToPage(_) -> model
        SetEastWind(player) -> Model(..model, east_wind: player)
        SetPrevailingWind(wind) -> Model(..model, prevailing_wind: wind)
        SetWinner(winner) -> Model(..model, winner: winner)
        SetPlayerName(player, name) -> set_player_name(model, player, name)
        AddItem(player, item) -> add_item_to_hand(model, player, item)
        RemoveItem(player, index) -> remove_item_from_hand(model, player, index)
        ToggleDouble(player, condition) ->
          toggle_double(model, player, condition)
        SetHandStatus(player, status) -> set_hand_status(model, player, status)
        NewRound ->
          Model(
            ..model,
            winner: None,
            hands: #(
              engine.empty_hand(),
              engine.empty_hand(),
              engine.empty_hand(),
              engine.empty_hand(),
            ),
            doubles: #(
              engine.no_doubles(),
              engine.no_doubles(),
              engine.no_doubles(),
              engine.no_doubles(),
            ),
            hand_statuses: #(Dirty, Dirty, Dirty, Dirty),
          )
      }
      save_model(new_model)
      new_model
    }
  }
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
      engine.add_to_hand(model.hands.0, item),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      engine.add_to_hand(model.hands.1, item),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      engine.add_to_hand(model.hands.2, item),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      engine.add_to_hand(model.hands.3, item),
    )
  }
  Model(..model, hands: hands)
}

fn remove_item_from_hand(model: Model, player: Player, index: Int) -> Model {
  let hands = case player {
    Player1 -> #(
      engine.remove_from_hand(model.hands.0, index),
      model.hands.1,
      model.hands.2,
      model.hands.3,
    )
    Player2 -> #(
      model.hands.0,
      engine.remove_from_hand(model.hands.1, index),
      model.hands.2,
      model.hands.3,
    )
    Player3 -> #(
      model.hands.0,
      model.hands.1,
      engine.remove_from_hand(model.hands.2, index),
      model.hands.3,
    )
    Player4 -> #(
      model.hands.0,
      model.hands.1,
      model.hands.2,
      engine.remove_from_hand(model.hands.3, index),
    )
  }
  Model(..model, hands: hands)
}

fn toggle_double(
  model: Model,
  player: Player,
  condition: DoubleCondition,
) -> Model {
  let doubles = case player {
    Player1 -> #(
      toggle_condition(model.doubles.0, condition),
      model.doubles.1,
      model.doubles.2,
      model.doubles.3,
    )
    Player2 -> #(
      model.doubles.0,
      toggle_condition(model.doubles.1, condition),
      model.doubles.2,
      model.doubles.3,
    )
    Player3 -> #(
      model.doubles.0,
      model.doubles.1,
      toggle_condition(model.doubles.2, condition),
      model.doubles.3,
    )
    Player4 -> #(
      model.doubles.0,
      model.doubles.1,
      model.doubles.2,
      toggle_condition(model.doubles.3, condition),
    )
  }
  Model(..model, doubles: doubles)
}

fn toggle_condition(
  ctx: DoublesContext,
  condition: DoubleCondition,
) -> DoublesContext {
  case condition {
    HasDragonPungOrKong ->
      DoublesContext(
        ..ctx,
        has_dragon_pung_or_kong: !ctx.has_dragon_pung_or_kong,
      )
    HasOwnWindPungOrKong ->
      DoublesContext(
        ..ctx,
        has_own_wind_pung_or_kong: !ctx.has_own_wind_pung_or_kong,
      )
    HasPrevailingWindPungOrKong ->
      DoublesContext(
        ..ctx,
        has_prevailing_wind_pung_or_kong: !ctx.has_prevailing_wind_pung_or_kong,
      )
    HasBothOwnFlowers ->
      DoublesContext(..ctx, has_both_own_flowers: !ctx.has_both_own_flowers)
    HasAllRedFlowers ->
      DoublesContext(..ctx, has_all_red_flowers: !ctx.has_all_red_flowers)
    HasAllBlueFlowers ->
      DoublesContext(..ctx, has_all_blue_flowers: !ctx.has_all_blue_flowers)
    IsCleanNoWindsOrDragons ->
      DoublesContext(
        ..ctx,
        is_clean_no_winds_or_dragons: !ctx.is_clean_no_winds_or_dragons,
      )
  }
}

fn get_condition_value(ctx: DoublesContext, condition: DoubleCondition) -> Bool {
  case condition {
    HasDragonPungOrKong -> ctx.has_dragon_pung_or_kong
    HasOwnWindPungOrKong -> ctx.has_own_wind_pung_or_kong
    HasPrevailingWindPungOrKong -> ctx.has_prevailing_wind_pung_or_kong
    HasBothOwnFlowers -> ctx.has_both_own_flowers
    HasAllRedFlowers -> ctx.has_all_red_flowers
    HasAllBlueFlowers -> ctx.has_all_blue_flowers
    IsCleanNoWindsOrDragons -> ctx.is_clean_no_winds_or_dragons
  }
}

fn set_hand_status(model: Model, player: Player, status: HandStatus) -> Model {
  let statuses = case player {
    Player1 -> #(
      status,
      model.hand_statuses.1,
      model.hand_statuses.2,
      model.hand_statuses.3,
    )
    Player2 -> #(
      model.hand_statuses.0,
      status,
      model.hand_statuses.2,
      model.hand_statuses.3,
    )
    Player3 -> #(
      model.hand_statuses.0,
      model.hand_statuses.1,
      status,
      model.hand_statuses.3,
    )
    Player4 -> #(
      model.hand_statuses.0,
      model.hand_statuses.1,
      model.hand_statuses.2,
      status,
    )
  }
  Model(..model, hand_statuses: statuses)
}

// --- View ---

fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    html.style([], styles()),
    view_header(model.page),
    case model.page {
      MainPage -> view_main_page(model)
      RulesPage -> view_rules_page()
    },
  ])
}

fn view_header(current_page: Page) -> Element(Msg) {
  div([class("header")], [
    h1([], [text("Alley Mah-jong")]),
    html.nav([class("nav")], [
      case current_page {
        MainPage ->
          html.a([class("nav-link"), event.on_click(GoToPage(RulesPage))], [
            text("Rules"),
          ])
        RulesPage ->
          html.a([class("nav-link"), event.on_click(GoToPage(MainPage))], [
            text("Back to Game"),
          ])
      },
    ]),
  ])
}

fn view_main_page(model: Model) -> Element(Msg) {
  div([], [view_round_settings(model), view_all_hands(model)])
}

fn view_rules_page() -> Element(Msg) {
  div([class("rules-page")], [
    html.article([class("rules-content")], [
      html.h2([], [text("Scoring Rules")]),
      html.p([], [
        text(
          "This app calculates Mah-jong hand scores. Enter each player's melds and bonuses to see their points.",
        ),
      ]),
      html.h3([], [text("Pungs (3 of a kind)")]),
      html.table([class("rules-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [text("Type")]),
            html.th([], [text("Revealed")]),
            html.th([], [text("Hidden")]),
          ]),
        ]),
        html.tbody([], [
          html.tr([], [
            html.td([], [text("Simple (2-8)")]),
            html.td([], [text("2 pts")]),
            html.td([], [text("4 pts")]),
          ]),
          html.tr([], [
            html.td([], [text("Honors (1, 9, Winds, Dragons)")]),
            html.td([], [text("4 pts")]),
            html.td([], [text("8 pts")]),
          ]),
        ]),
      ]),
      html.h3([], [text("Kongs (4 of a kind)")]),
      html.table([class("rules-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [text("Type")]),
            html.th([], [text("Revealed")]),
            html.th([], [text("Hidden")]),
          ]),
        ]),
        html.tbody([], [
          html.tr([], [
            html.td([], [text("Simple (2-8)")]),
            html.td([], [text("8 pts")]),
            html.td([], [text("16 pts")]),
          ]),
          html.tr([], [
            html.td([], [text("Honors (1, 9, Winds, Dragons)")]),
            html.td([], [text("16 pts")]),
            html.td([], [text("32 pts")]),
          ]),
        ]),
      ]),
      html.h3([], [text("Bonuses")]),
      html.ul([], [
        html.li([], [text("Pair of Winds: 2 pts")]),
        html.li([], [text("Pair of Dragons: 2 pts")]),
        html.li([], [text("Flower: 4 pts")]),
        html.li([], [text("Mah-jonging: 20 pts")]),
      ]),
      html.h3([], [text("Terminology")]),
      html.ul([], [
        html.li([], [
          html.strong([], [text("Revealed: ")]),
          text("Melds formed by claiming a discarded tile (face-up on table)"),
        ]),
        html.li([], [
          html.strong([], [text("Hidden: ")]),
          text("Melds formed entirely from drawn tiles (kept concealed)"),
        ]),
        html.li([], [
          html.strong([], [text("Honors: ")]),
          text("Terminal tiles (1 and 9), Wind tiles, and Dragon tiles"),
        ]),
      ]),
    ]),
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
    attribute.placeholder(engine.player_to_string(player)),
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
      attribute.value(engine.player_to_string(player)),
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
    Some(p) -> #(get_player_name(p, names), engine.player_to_string(p))
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
      model.doubles.0,
      model.hand_statuses.0,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player2,
      model.hands.1,
      model.doubles.1,
      model.hand_statuses.1,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player3,
      model.hands.2,
      model.doubles.2,
      model.hand_statuses.2,
      model.east_wind,
      model.winner,
      model.names,
    ),
    view_player_hand(
      Player4,
      model.hands.3,
      model.doubles.3,
      model.hand_statuses.3,
      model.east_wind,
      model.winner,
      model.names,
    ),
  ])
}

fn view_player_hand(
  player: Player,
  hand: PlayerHand,
  doubles_ctx: DoublesContext,
  hand_status: HandStatus,
  east: Player,
  winner: Option(Player),
  names: #(String, String, String, String),
) -> Element(Msg) {
  let is_winner = winner == Some(player)
  let is_east = player == east
  let east_marker = case is_east {
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
  // Calculate score based on hand status
  let #(total_points, multiplier, doubles_count) = case hand_status {
    Limit -> {
      // Limit hands are always 500, or 1000 for East Wind
      let limit_score = case is_east {
        True -> 1000
        False -> 500
      }
      #(limit_score, 1, 0)
    }
    _ -> {
      // Normal scoring with doubles
      let is_clean = case hand_status {
        Clean -> True
        _ -> False
      }
      let effective_doubles =
        DoublesContext(..doubles_ctx, is_east_wind: is_east, is_clean: is_clean)
      let base_points = engine.calculate_hand_points(hand, is_winner)
      let mult = engine.calculate_multiplier(effective_doubles)
      let points = engine.calculate_round_score(base_points, mult)
      let dbl_count = engine.calculate_doubles(effective_doubles)
      #(points, mult, dbl_count)
    }
  }
  div([class(hand_class)], [
    div([class("hand-header")], [
      h3([], [
        text(get_player_name(player, names) <> east_marker <> winner_marker),
      ]),
      div([class("points-display")], [
        span([class("points")], [text(int.to_string(total_points) <> " pts")]),
        case doubles_count > 0 {
          True ->
            span([class("multiplier")], [
              text("(" <> int.to_string(multiplier) <> "x)"),
            ])
          False -> text("")
        },
      ]),
    ]),
    view_hand_status_selector(player, hand_status),
    case hand_status {
      Clean -> div([], [
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
        view_doubles_section(player, doubles_ctx, is_east),
      ])
      _ -> text("")
    },
  ])
}

fn view_hand_status_selector(player: Player, status: HandStatus) -> Element(Msg) {
  div([class("hand-status-row")], [
    span([class("row-label")], [text("Status:")]),
    status_button(player, status, Dirty, "Dirty"),
    status_button(player, status, Clean, "Clean"),
    status_button(player, status, Limit, "Limit"),
  ])
}

fn status_button(
  player: Player,
  current: HandStatus,
  target: HandStatus,
  label: String,
) -> Element(Msg) {
  let btn_class = case current == target {
    True -> "status-btn selected"
    False -> "status-btn"
  }
  button([class(btn_class), event.on_click(SetHandStatus(player, target))], [
    text(label),
  ])
}

fn view_doubles_section(
  player: Player,
  ctx: DoublesContext,
  is_east: Bool,
) -> Element(Msg) {
  div([class("doubles-section")], [
    div([class("add-row")], [
      span([class("row-label")], [text("Doubles:")]),
      double_checkbox(player, ctx, HasDragonPungOrKong, "Dragon P/K"),
      double_checkbox(player, ctx, HasOwnWindPungOrKong, "Own Wind P/K"),
      double_checkbox(
        player,
        ctx,
        HasPrevailingWindPungOrKong,
        "Prevail Wind P/K",
      ),
      double_checkbox(player, ctx, HasBothOwnFlowers, "Both Your Flowers"),
    ]),
    div([class("add-row")], [
      span([class("row-label")], []),
      case is_east {
        True -> span([class("double-auto")], [text("East Wind (auto)")])
        False -> text("")
      },
    ]),
    div([class("add-row")], [
      span([class("row-label")], [text("3x:")]),
      double_checkbox(player, ctx, HasAllRedFlowers, "4 Red Flowers"),
      double_checkbox(player, ctx, HasAllBlueFlowers, "4 Blue Flowers"),
      double_checkbox(
        player,
        ctx,
        IsCleanNoWindsOrDragons,
        "Clean No Winds/Dragons",
      ),
    ]),
  ])
}

fn double_checkbox(
  player: Player,
  ctx: DoublesContext,
  condition: DoubleCondition,
  label: String,
) -> Element(Msg) {
  let is_checked = get_condition_value(ctx, condition)
  let checkbox_class = case is_checked {
    True -> "double-checkbox checked"
    False -> "double-checkbox"
  }
  button(
    [class(checkbox_class), event.on_click(ToggleDouble(player, condition))],
    [text(label)],
  )
}

fn item_button(player: Player, item: ScoringItem) -> Element(Msg) {
  button([class("scoring-item add"), event.on_click(AddItem(player, item))], [
    text(engine.item_label(item)),
  ])
}

fn removable_item(player: Player, item: ScoringItem, index: Int) -> Element(Msg) {
  button(
    [class("scoring-item in-hand"), event.on_click(RemoveItem(player, index))],
    [text(engine.item_display(item))],
  )
}

// --- Helpers ---

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
    "" -> engine.player_to_string(player)
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
    margin: 0;
  }
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid var(--carbon);
    padding-bottom: 8px;
    margin-bottom: 24px;
  }
  .nav {
    display: flex;
    gap: 16px;
  }
  .nav-link {
    color: var(--ink-purple);
    text-decoration: none;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 12px;
    letter-spacing: 1px;
    cursor: pointer;
    padding: 4px 8px;
    border: 1px solid transparent;
  }
  .nav-link:hover {
    border-color: var(--ink-purple);
    background: var(--btn-dark);
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
    min-height: 280px;
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
  /* Rules page */
  .rules-page {
    background: var(--paper);
    border: 2px solid var(--carbon-faded);
    padding: 24px;
    box-shadow:
      3px 3px 0 rgba(44,44,44,0.15),
      5px 5px 8px rgba(44,44,44,0.08);
  }
  .rules-content h2 {
    margin-top: 0;
    text-transform: uppercase;
    letter-spacing: 2px;
    border-bottom: 1px solid var(--carbon-faded);
    padding-bottom: 8px;
  }
  .rules-content h3 {
    margin-top: 24px;
    margin-bottom: 12px;
    text-transform: uppercase;
    font-size: 14px;
    letter-spacing: 1px;
  }
  .rules-content p {
    line-height: 1.6;
    margin-bottom: 16px;
  }
  .rules-content ul {
    margin: 0;
    padding-left: 24px;
  }
  .rules-content li {
    margin-bottom: 8px;
    line-height: 1.5;
  }
  .rules-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 16px;
  }
  .rules-table th,
  .rules-table td {
    border: 1px solid var(--carbon-faded);
    padding: 8px 12px;
    text-align: left;
  }
  .rules-table th {
    background: var(--btn-dark);
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 1px;
  }
  .rules-table td {
    background: var(--cream);
  }
  /* Points display with multiplier */
  .points-display {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .multiplier {
    font-size: 12px;
    color: var(--ink-purple);
    font-weight: bold;
  }
  /* Hand status selector */
  .hand-status-row {
    display: flex;
    gap: 4px;
    align-items: center;
    margin-bottom: 8px;
    padding-bottom: 8px;
    border-bottom: 1px dotted var(--carbon-faded);
  }
  .status-btn {
    padding: 3px 8px;
    font-size: 10px;
    font-family: 'Courier New', Courier, monospace;
    border: 1px solid var(--carbon-faded);
    background: var(--btn-dark);
    cursor: pointer;
    box-shadow: 1px 1px 0 rgba(44,44,44,0.1);
  }
  .status-btn:hover {
    background: var(--btn-darker);
    border-color: var(--carbon);
  }
  .status-btn.selected {
    background: var(--ink-purple);
    color: var(--paper);
    border-color: var(--ink-purple);
    font-weight: bold;
  }
  /* Doubles section */
  .doubles-section {
    margin-top: 10px;
    padding-top: 10px;
    border-top: 1px dashed var(--carbon-faded);
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .double-checkbox {
    padding: 3px 6px;
    font-size: 10px;
    font-family: 'Courier New', Courier, monospace;
    border: 1px solid var(--carbon-faded);
    background: var(--btn-dark);
    cursor: pointer;
    box-shadow: 1px 1px 0 rgba(44,44,44,0.1);
    white-space: nowrap;
  }
  .double-checkbox:hover {
    background: var(--btn-darker);
    border-color: var(--carbon);
    box-shadow:
      1px 1px 0 rgba(44,44,44,0.15),
      2px 2px 4px rgba(44,44,44,0.08);
  }
  .double-checkbox.checked {
    background: var(--ink-purple);
    color: var(--paper);
    border-color: var(--ink-purple);
    font-weight: bold;
  }
  .double-auto {
    font-size: 10px;
    color: var(--carbon-light);
    font-style: italic;
    padding: 3px 6px;
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
