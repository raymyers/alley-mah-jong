import engine.{
  type DoublesContext, type Player, type PlayerHand, type PlayerPayout,
  type ScoringItem, type Wind, BonusFlower, BonusPairDragon, BonusPairWind,
  DoublesContext, East, Kong, KongHidden, KongHonors, KongHonorsHidden, North,
  Player1, Player2, Player3, Player4, PlayerHand, Pung, PungHidden, PungHonors,
  PungHonorsHidden, South, West,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h2, h3, option, select, span}
import lustre/event
import storage.{type Game, type Round}

// --- UI Model ---

pub type Page {
  GamePage
  RoundPage(index: Int)
  RulesPage
  NewGamePage
}

pub type HandStatus {
  Dirty
  Clean
  Limit
}

pub type Model {
  Model(
    page: Page,
    game: Option(Game),
    // New game setup fields
    setup_starting_score: String,
    setup_names: #(String, String, String, String),
    // Edit confirmation
    pending_edit: Option(Int),
  )
}

fn default_model() -> Model {
  Model(
    page: GamePage,
    game: None,
    setup_starting_score: int.to_string(storage.default_starting_score),
    setup_names: #("", "", "", ""),
    pending_edit: None,
  )
}

fn init(_flags) -> Model {
  case storage.load_game() {
    Some(game) -> Model(..default_model(), game: Some(game))
    None -> default_model()
  }
}

// --- Messages ---

pub type Msg {
  GoToPage(Page)
  // New game setup
  SetSetupStartingScore(String)
  SetSetupName(Player, String)
  StartNewGame
  ConfirmNewGame
  CancelNewGame
  // Round editing
  SetEastWind(Player)
  SetPrevailingWind(Wind)
  SetWinner(Option(Player))
  AddItem(Player, ScoringItem)
  RemoveItem(Player, Int)
  ToggleDouble(Player, DoubleCondition)
  SetHandStatus(Player, HandStatus)
  // Game actions
  AddNewRound
  ConfirmEditRound(Int)
  CancelEditRound
}

pub type DoubleCondition {
  HasDragonPungOrKong
  HasOwnWindPungOrKong
  HasPrevailingWindPungOrKong
  HasBothOwnFlowers
  HasAllRedFlowers
  HasAllBlueFlowers
  IsCleanNoWindsOrDragons
}

// --- Update ---

fn update(model: Model, msg: Msg) -> Model {
  let new_model = case msg {
    GoToPage(page) -> Model(..model, page: page)

    // New game setup
    SetSetupStartingScore(s) -> Model(..model, setup_starting_score: s)
    SetSetupName(player, name) -> {
      let names = case player {
        Player1 -> #(
          name,
          model.setup_names.1,
          model.setup_names.2,
          model.setup_names.3,
        )
        Player2 -> #(
          model.setup_names.0,
          name,
          model.setup_names.2,
          model.setup_names.3,
        )
        Player3 -> #(
          model.setup_names.0,
          model.setup_names.1,
          name,
          model.setup_names.3,
        )
        Player4 -> #(
          model.setup_names.0,
          model.setup_names.1,
          model.setup_names.2,
          name,
        )
      }
      Model(..model, setup_names: names)
    }
    StartNewGame -> Model(..model, page: NewGamePage)
    ConfirmNewGame -> {
      let starting = case int.parse(model.setup_starting_score) {
        Ok(n) -> n
        Error(_) -> storage.default_starting_score
      }
      let game = storage.new_game(starting, model.setup_names)
      storage.save_game(game)
      Model(..model, page: RoundPage(0), game: Some(game))
    }
    CancelNewGame -> Model(..model, page: GamePage)

    // Round editing (only when viewing a round)
    SetEastWind(player) ->
      update_current_round(model, fn(r) {
        storage.Round(..r, east_wind: player_to_storage(player))
      })
    SetPrevailingWind(wind) ->
      update_current_round(model, fn(r) {
        storage.Round(..r, prevailing_wind: wind_to_storage(wind))
      })
    SetWinner(winner) ->
      update_current_round(model, fn(r) {
        storage.Round(..r, winner: option.map(winner, player_to_storage))
      })
    AddItem(player, item) ->
      update_current_round(model, fn(r) {
        let hands = add_item_to_hands(r.hands, player, item)
        storage.Round(..r, hands: hands)
      })
    RemoveItem(player, index) ->
      update_current_round(model, fn(r) {
        let hands = remove_item_from_hands(r.hands, player, index)
        storage.Round(..r, hands: hands)
      })
    ToggleDouble(player, condition) ->
      update_current_round(model, fn(r) {
        let doubles = toggle_doubles(r.doubles, player, condition)
        storage.Round(..r, doubles: doubles)
      })
    SetHandStatus(player, status) ->
      update_current_round(model, fn(r) {
        let statuses = set_status(r.hand_statuses, player, status)
        // When setting Limit and no winner yet, auto-set winner to this player
        let new_winner = case status {
          Limit ->
            case r.winner {
              None -> Some(player_to_storage(player))
              existing -> existing
            }
          _ -> r.winner
        }
        storage.Round(..r, hand_statuses: statuses, winner: new_winner)
      })

    // Game actions
    AddNewRound -> {
      case model.game {
        None -> model
        Some(game) -> {
          let last_round = list.last(game.rounds)
          let #(next_east, next_prevailing) = case last_round {
            Error(_) -> #(storage.Player1, storage.East)
            Ok(r) -> {
              let winner = option.unwrap(r.winner, r.east_wind)
              let new_east =
                engine.next_east_wind(
                  player_from_storage(r.east_wind),
                  player_from_storage(winner),
                )
              let new_prevailing =
                engine.next_prevailing_wind(
                  wind_from_storage(r.prevailing_wind),
                  player_from_storage(r.east_wind),
                  new_east,
                )
              #(player_to_storage(new_east), wind_to_storage(new_prevailing))
            }
          }
          let new_round = storage.empty_round(next_east, next_prevailing)
          let new_index = list.length(game.rounds)
          let new_game =
            storage.Game(
              ..game,
              rounds: list.append(game.rounds, [new_round]),
              editing_round: Some(new_index),
            )
          storage.save_game(new_game)
          Model(..model, game: Some(new_game), page: RoundPage(new_index))
        }
      }
    }
    ConfirmEditRound(index) -> {
      Model(..model, page: RoundPage(index), pending_edit: None)
    }
    CancelEditRound -> {
      Model(..model, pending_edit: None)
    }
  }
  new_model
}

fn update_current_round(model: Model, f: fn(Round) -> Round) -> Model {
  case model.page, model.game {
    RoundPage(index), Some(game) -> {
      case storage.get_round(game, index) {
        None -> model
        Some(round) -> {
          let new_round = f(round)
          let new_game = storage.update_round(game, index, new_round)
          storage.save_game(new_game)
          Model(..model, game: Some(new_game))
        }
      }
    }
    _, _ -> model
  }
}

fn add_item_to_hands(
  hands: #(
    storage.PlayerHand,
    storage.PlayerHand,
    storage.PlayerHand,
    storage.PlayerHand,
  ),
  player: Player,
  item: ScoringItem,
) -> #(
  storage.PlayerHand,
  storage.PlayerHand,
  storage.PlayerHand,
  storage.PlayerHand,
) {
  let storage_item = item_to_storage(item)
  case player {
    Player1 -> #(
      storage.PlayerHand(list.append({ hands.0 }.items, [storage_item])),
      hands.1,
      hands.2,
      hands.3,
    )
    Player2 -> #(
      hands.0,
      storage.PlayerHand(list.append({ hands.1 }.items, [storage_item])),
      hands.2,
      hands.3,
    )
    Player3 -> #(
      hands.0,
      hands.1,
      storage.PlayerHand(list.append({ hands.2 }.items, [storage_item])),
      hands.3,
    )
    Player4 -> #(
      hands.0,
      hands.1,
      hands.2,
      storage.PlayerHand(list.append({ hands.3 }.items, [storage_item])),
    )
  }
}

fn remove_item_from_hands(
  hands: #(
    storage.PlayerHand,
    storage.PlayerHand,
    storage.PlayerHand,
    storage.PlayerHand,
  ),
  player: Player,
  index: Int,
) -> #(
  storage.PlayerHand,
  storage.PlayerHand,
  storage.PlayerHand,
  storage.PlayerHand,
) {
  case player {
    Player1 -> #(
      storage.PlayerHand(remove_at({ hands.0 }.items, index)),
      hands.1,
      hands.2,
      hands.3,
    )
    Player2 -> #(
      hands.0,
      storage.PlayerHand(remove_at({ hands.1 }.items, index)),
      hands.2,
      hands.3,
    )
    Player3 -> #(
      hands.0,
      hands.1,
      storage.PlayerHand(remove_at({ hands.2 }.items, index)),
      hands.3,
    )
    Player4 -> #(
      hands.0,
      hands.1,
      hands.2,
      storage.PlayerHand(remove_at({ hands.3 }.items, index)),
    )
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

fn toggle_doubles(
  doubles: #(
    storage.DoublesContext,
    storage.DoublesContext,
    storage.DoublesContext,
    storage.DoublesContext,
  ),
  player: Player,
  condition: DoubleCondition,
) -> #(
  storage.DoublesContext,
  storage.DoublesContext,
  storage.DoublesContext,
  storage.DoublesContext,
) {
  case player {
    Player1 -> #(
      toggle_condition_storage(doubles.0, condition),
      doubles.1,
      doubles.2,
      doubles.3,
    )
    Player2 -> #(
      doubles.0,
      toggle_condition_storage(doubles.1, condition),
      doubles.2,
      doubles.3,
    )
    Player3 -> #(
      doubles.0,
      doubles.1,
      toggle_condition_storage(doubles.2, condition),
      doubles.3,
    )
    Player4 -> #(
      doubles.0,
      doubles.1,
      doubles.2,
      toggle_condition_storage(doubles.3, condition),
    )
  }
}

fn toggle_condition_storage(
  ctx: storage.DoublesContext,
  condition: DoubleCondition,
) -> storage.DoublesContext {
  case condition {
    HasDragonPungOrKong ->
      storage.DoublesContext(
        ..ctx,
        has_dragon_pung_or_kong: !ctx.has_dragon_pung_or_kong,
      )
    HasOwnWindPungOrKong ->
      storage.DoublesContext(
        ..ctx,
        has_own_wind_pung_or_kong: !ctx.has_own_wind_pung_or_kong,
      )
    HasPrevailingWindPungOrKong ->
      storage.DoublesContext(
        ..ctx,
        has_prevailing_wind_pung_or_kong: !ctx.has_prevailing_wind_pung_or_kong,
      )
    HasBothOwnFlowers ->
      storage.DoublesContext(
        ..ctx,
        has_both_own_flowers: !ctx.has_both_own_flowers,
      )
    HasAllRedFlowers ->
      storage.DoublesContext(
        ..ctx,
        has_all_red_flowers: !ctx.has_all_red_flowers,
      )
    HasAllBlueFlowers ->
      storage.DoublesContext(
        ..ctx,
        has_all_blue_flowers: !ctx.has_all_blue_flowers,
      )
    IsCleanNoWindsOrDragons ->
      storage.DoublesContext(
        ..ctx,
        is_clean_no_winds_or_dragons: !ctx.is_clean_no_winds_or_dragons,
      )
  }
}

fn set_status(
  statuses: #(
    storage.HandStatus,
    storage.HandStatus,
    storage.HandStatus,
    storage.HandStatus,
  ),
  player: Player,
  status: HandStatus,
) -> #(
  storage.HandStatus,
  storage.HandStatus,
  storage.HandStatus,
  storage.HandStatus,
) {
  let s = hand_status_to_storage(status)
  case player {
    Player1 -> #(s, statuses.1, statuses.2, statuses.3)
    Player2 -> #(statuses.0, s, statuses.2, statuses.3)
    Player3 -> #(statuses.0, statuses.1, s, statuses.3)
    Player4 -> #(statuses.0, statuses.1, statuses.2, s)
  }
}

// --- Type Conversions ---

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

fn hand_status_to_engine(status: HandStatus) -> engine.HandStatus {
  case status {
    Dirty -> engine.Dirty
    Clean -> engine.Clean
    Limit -> engine.Limit
  }
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

fn hand_from_storage(hand: storage.PlayerHand) -> PlayerHand {
  PlayerHand(items: list.map(hand.items, item_from_storage))
}

fn get_condition_value(
  ctx: storage.DoublesContext,
  condition: DoubleCondition,
) -> Bool {
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

// --- View ---

fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    html.style([], styles()),
    view_header(model.page),
    case model.page {
      GamePage -> view_game_page(model)
      RoundPage(index) -> view_round_page(model, index)
      RulesPage -> view_rules_page()
      NewGamePage -> view_new_game_page(model)
    },
  ])
}

fn view_header(current_page: Page) -> Element(Msg) {
  div([class("header")], [
    h1([], [text("Alley Mah-jong")]),
    html.nav([class("nav")], [
      case current_page {
        GamePage ->
          html.a([class("nav-link"), event.on_click(GoToPage(RulesPage))], [
            text("Rules"),
          ])
        RoundPage(_) ->
          html.a([class("nav-link"), event.on_click(GoToPage(GamePage))], [
            text("Submit score"),
          ])
        RulesPage ->
          html.a([class("nav-link"), event.on_click(GoToPage(GamePage))], [
            text("Back to Game"),
          ])
        NewGamePage ->
          html.a([class("nav-link"), event.on_click(CancelNewGame)], [
            text("Cancel"),
          ])
      },
    ]),
  ])
}

// --- Game Page ---

fn view_game_page(model: Model) -> Element(Msg) {
  case model.game {
    None -> view_no_game()
    Some(game) -> view_game_summary(game)
  }
}

fn view_no_game() -> Element(Msg) {
  div([class("no-game")], [
    h2([], [text("No Game in Progress")]),
    button([class("new-game-btn"), event.on_click(StartNewGame)], [
      text("New Game"),
    ]),
  ])
}

fn view_game_summary(game: Game) -> Element(Msg) {
  let running_scores = calculate_all_running_scores(game)

  div([class("game-summary")], [
    div([class("game-header")], [
      h2([], [text("Game Summary")]),
      div([class("game-actions")], [
        button([class("new-game-btn secondary"), event.on_click(StartNewGame)], [
          text("New Game"),
        ]),
      ]),
    ]),
    view_current_standings(game, running_scores),
    div(
      [class("rounds-list")],
      list.index_map(game.rounds, fn(round, index) {
        view_round_summary(game, round, index, running_scores)
      }),
    ),
    button([class("add-round-btn"), event.on_click(AddNewRound)], [
      text("+ New Round"),
    ]),
  ])
}

fn view_current_standings(
  game: Game,
  running_scores: List(#(Int, Int, Int, Int)),
) -> Element(Msg) {
  let current = case list.last(running_scores) {
    Ok(scores) -> scores
    Error(_) -> #(
      game.starting_score,
      game.starting_score,
      game.starting_score,
      game.starting_score,
    )
  }
  div([class("standings")], [
    view_standing(game.names.0, "Player 1", current.0),
    view_standing(game.names.1, "Player 2", current.1),
    view_standing(game.names.2, "Player 3", current.2),
    view_standing(game.names.3, "Player 4", current.3),
  ])
}

fn view_standing(name: String, default: String, score: Int) -> Element(Msg) {
  let display_name = case name {
    "" -> default
    n -> n
  }
  div([class("standing")], [
    span([class("standing-name")], [text(display_name)]),
    span([class("standing-score")], [text(int.to_string(score))]),
  ])
}

fn view_round_summary(
  game: Game,
  round: Round,
  index: Int,
  running_scores: List(#(Int, Int, Int, Int)),
) -> Element(Msg) {
  let round_num = index + 1
  let east = player_from_storage(round.east_wind)

  // Check if round is scoreable using engine validation
  let winner_opt = option.map(round.winner, player_from_storage)
  let statuses = #(
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.0)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.1)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.2)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.3)),
  )
  let is_scoreable = engine.is_round_scoreable(winner_opt, statuses)

  // Determine status message
  let winner_name = case round.winner {
    None -> "No winner"
    Some(p) -> {
      case is_scoreable {
        True -> get_player_display_name(p, game.names) <> " won"
        False -> get_player_display_name(p, game.names) <> " won (invalid)"
      }
    }
  }

  // For running totals, use last completed round's running score
  let running =
    get_last_running_before(running_scores, index, game.starting_score)

  let summary_class = case is_scoreable {
    True -> "round-summary"
    False -> "round-summary no-winner"
  }

  div([class(summary_class), event.on_click(GoToPage(RoundPage(index)))], [
    div([class("round-header")], [
      span([class("round-number")], [text("Round " <> int.to_string(round_num))]),
      span([class("round-winner")], [text(winner_name)]),
    ]),
    view_round_details(game, round, east, running, is_scoreable),
  ])
}

fn get_last_running_before(
  running_scores: List(#(Int, Int, Int, Int)),
  index: Int,
  starting_score: Int,
) -> #(Int, Int, Int, Int) {
  // Running scores list only contains entries for completed rounds
  // So we get the entry at this index if it exists, otherwise the last one
  case get_at(running_scores, index) {
    Some(scores) -> scores
    None ->
      case list.last(running_scores) {
        Ok(scores) -> scores
        Error(_) -> #(
          starting_score,
          starting_score,
          starting_score,
          starting_score,
        )
      }
  }
}

fn view_round_details(
  game: Game,
  round: Round,
  east: Player,
  running: #(Int, Int, Int, Int),
  has_winner: Bool,
) -> Element(Msg) {
  let scores = calculate_round_scores(round)
  let statuses = #(
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.0)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.1)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.2)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.3)),
  )
  let winner =
    option.unwrap(option.map(round.winner, player_from_storage), Player1)
  let payouts = engine.calculate_payouts(scores, statuses, winner, east)

  div([class("round-details")], [
    view_player_row(
      game.names.0,
      "Player 1",
      Player1,
      east,
      winner,
      scores.0,
      payouts.0,
      running.0,
      has_winner,
    ),
    view_player_row(
      game.names.1,
      "Player 2",
      Player2,
      east,
      winner,
      scores.1,
      payouts.1,
      running.1,
      has_winner,
    ),
    view_player_row(
      game.names.2,
      "Player 3",
      Player3,
      east,
      winner,
      scores.2,
      payouts.2,
      running.2,
      has_winner,
    ),
    view_player_row(
      game.names.3,
      "Player 4",
      Player4,
      east,
      winner,
      scores.3,
      payouts.3,
      running.3,
      has_winner,
    ),
  ])
}

fn view_player_row(
  name: String,
  default: String,
  player: Player,
  east: Player,
  winner: Player,
  score: Int,
  payout: PlayerPayout,
  running: Int,
  has_winner: Bool,
) -> Element(Msg) {
  let display_name = case name {
    "" -> default
    n -> n
  }
  let markers = case has_winner {
    True -> {
      let east_mark = case player == east {
        True -> " (E)"
        False -> ""
      }
      let win_mark = case player == winner {
        True -> " ★"
        False -> ""
      }
      east_mark <> win_mark
    }
    False -> {
      case player == east {
        True -> " (E)"
        False -> ""
      }
    }
  }
  let net = engine.net_payout(payout)
  let net_str = case net >= 0 {
    True -> "+" <> int.to_string(net)
    False -> int.to_string(net)
  }
  let running_str = case has_winner {
    True -> int.to_string(running)
    False -> "-"
  }

  div([class("player-row")], [
    span([class("player-name")], [text(display_name <> markers)]),
    span([class("player-score")], [text(int.to_string(score))]),
    span([class("player-net")], [text(net_str)]),
    span([class("player-running")], [text(running_str)]),
  ])
}

// --- New Game Page ---

fn view_new_game_page(model: Model) -> Element(Msg) {
  div([class("new-game-page")], [
    h2([], [text("New Game")]),
    div([class("setup-form")], [
      div([class("setup-field")], [
        html.label([], [text("Starting Score:")]),
        html.input([
          class("setup-input"),
          attribute.type_("number"),
          attribute.value(model.setup_starting_score),
          event.on_input(SetSetupStartingScore),
        ]),
      ]),
      div([class("setup-section")], [
        html.label([], [text("Player Names:")]),
        setup_name_input(Player1, model.setup_names.0),
        setup_name_input(Player2, model.setup_names.1),
        setup_name_input(Player3, model.setup_names.2),
        setup_name_input(Player4, model.setup_names.3),
      ]),
      div([class("setup-actions")], [
        button([class("new-game-btn"), event.on_click(ConfirmNewGame)], [
          text("Start Game"),
        ]),
        button([class("cancel-btn"), event.on_click(CancelNewGame)], [
          text("Cancel"),
        ]),
      ]),
    ]),
  ])
}

fn setup_name_input(player: Player, current_name: String) -> Element(Msg) {
  html.input([
    class("name-input"),
    attribute.value(current_name),
    attribute.placeholder(engine.player_to_string(player)),
    event.on_input(fn(val) { SetSetupName(player, val) }),
  ])
}

// --- Round Page ---

fn view_round_page(model: Model, index: Int) -> Element(Msg) {
  case model.game {
    None -> div([], [text("No game")])
    Some(game) -> {
      case storage.get_round(game, index) {
        None -> div([], [text("Round not found")])
        Some(round) -> view_round_editor(game, round, index)
      }
    }
  }
}

fn view_round_editor(game: Game, round: Round, index: Int) -> Element(Msg) {
  let east = player_from_storage(round.east_wind)
  let prevailing = wind_from_storage(round.prevailing_wind)
  let winner = option.map(round.winner, player_from_storage)

  div([], [
    div([class("round-title")], [
      h2([], [text("Round " <> int.to_string(index + 1))]),
    ]),
    view_round_settings(game, east, prevailing, winner),
    view_all_hands(game, round, east, winner),
  ])
}

fn view_round_settings(
  game: Game,
  east: Player,
  prevailing: Wind,
  winner: Option(Player),
) -> Element(Msg) {
  div([class("settings-container")], [
    div([class("round-settings")], [
      div([class("setting")], [
        html.label([], [text("East Wind: ")]),
        select([event.on_input(fn(val) { SetEastWind(parse_player(val)) })], [
          player_option(Player1, east, game.names),
          player_option(Player2, east, game.names),
          player_option(Player3, east, game.names),
          player_option(Player4, east, game.names),
        ]),
      ]),
      div([class("setting")], [
        html.label([], [text("Prevailing Wind: ")]),
        select(
          [event.on_input(fn(val) { SetPrevailingWind(parse_wind(val)) })],
          [
            wind_option(East, prevailing),
            wind_option(South, prevailing),
            wind_option(West, prevailing),
            wind_option(North, prevailing),
          ],
        ),
      ]),
      div([class("setting")], [
        html.label([], [text("Mah-jong'd: ")]),
        select([event.on_input(fn(val) { SetWinner(parse_winner(val)) })], [
          winner_option(None, winner, game.names),
          winner_option(Some(Player1), winner, game.names),
          winner_option(Some(Player2), winner, game.names),
          winner_option(Some(Player3), winner, game.names),
          winner_option(Some(Player4), winner, game.names),
        ]),
      ]),
    ]),
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

fn view_all_hands(
  game: Game,
  round: Round,
  east: Player,
  winner: Option(Player),
) -> Element(Msg) {
  // Calculate scores and payouts for display
  let scores = calculate_round_scores(round)
  let statuses = #(
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.0)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.1)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.2)),
    hand_status_to_engine(hand_status_from_storage(round.hand_statuses.3)),
  )
  let payouts = case winner {
    Some(w) -> Some(engine.calculate_payouts(scores, statuses, w, east))
    None -> None
  }

  div([class("all-hands")], [
    view_player_hand(
      Player1,
      round.hands.0,
      round.doubles.0,
      round.hand_statuses.0,
      east,
      winner,
      game.names,
      option.map(payouts, fn(p) { p.0 }),
    ),
    view_player_hand(
      Player2,
      round.hands.1,
      round.doubles.1,
      round.hand_statuses.1,
      east,
      winner,
      game.names,
      option.map(payouts, fn(p) { p.1 }),
    ),
    view_player_hand(
      Player3,
      round.hands.2,
      round.doubles.2,
      round.hand_statuses.2,
      east,
      winner,
      game.names,
      option.map(payouts, fn(p) { p.2 }),
    ),
    view_player_hand(
      Player4,
      round.hands.3,
      round.doubles.3,
      round.hand_statuses.3,
      east,
      winner,
      game.names,
      option.map(payouts, fn(p) { p.3 }),
    ),
  ])
}

fn view_player_hand(
  player: Player,
  hand: storage.PlayerHand,
  doubles_ctx: storage.DoublesContext,
  hand_status: storage.HandStatus,
  east: Player,
  winner: Option(Player),
  names: #(String, String, String, String),
  payout: Option(PlayerPayout),
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
  let ui_hand_status = hand_status_from_storage(hand_status)
  let engine_status = hand_status_to_engine(ui_hand_status)
  let engine_doubles = doubles_from_storage(doubles_ctx)
  let engine_hand = hand_from_storage(hand)
  let #(total_points, multiplier, doubles_count, reasons) =
    engine.calculate_final_score(
      engine_hand,
      engine_status,
      engine_doubles,
      is_winner,
      is_east,
    )
  let tooltip_text = case reasons {
    [] -> ""
    _ -> string.join(reasons, "\n")
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
            span(
              [class("multiplier"), attribute.attribute("title", tooltip_text)],
              [text("(" <> int.to_string(multiplier) <> "x)")],
            )
          False -> text("")
        },
      ]),
    ]),
    view_hand_status_selector(player, ui_hand_status, winner),
    case ui_hand_status {
      Clean ->
        div([], [
          div(
            [class("hand-items")],
            list.index_map(hand.items, fn(item, i) {
              removable_item(player, item_from_storage(item), i)
            }),
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
    view_payout_section(payout, is_winner, names),
  ])
}

fn view_hand_status_selector(
  player: Player,
  status: HandStatus,
  winner: Option(Player),
) -> Element(Msg) {
  // Check for limit conflict: player has Limit but isn't the winner
  let has_limit_conflict = case status {
    Limit ->
      case winner {
        Some(w) -> w != player
        None -> False
      }
    _ -> False
  }

  div([class("hand-status-row")], [
    span([class("row-label")], [text("Status:")]),
    status_button(player, status, Dirty, "Dirty"),
    status_button(player, status, Clean, "Clean"),
    status_button(player, status, Limit, "Limit"),
    case has_limit_conflict {
      True ->
        span([class("limit-conflict-warning")], [text("Multiple Mah-jongs?")])
      False -> text("")
    },
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
  ctx: storage.DoublesContext,
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
  ctx: storage.DoublesContext,
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

fn view_payout_section(
  payout: Option(PlayerPayout),
  is_winner: Bool,
  names: #(String, String, String, String),
) -> Element(Msg) {
  case payout {
    None -> text("")
    Some(p) ->
      div([class("payout-section")], [
        case is_winner {
          True -> text("")
          False ->
            div([class("payout-row")], [
              span([class("payout-label")], [text("Paying:")]),
              div(
                [class("payout-entries")],
                list.map(p.paying, fn(entry) {
                  span([class("payout-entry")], [
                    text(
                      get_player_name(entry.to, names)
                      <> ": "
                      <> int.to_string(entry.amount),
                    ),
                  ])
                }),
              ),
            ])
        },
        div([class("payout-row")], [
          span([class("payout-label")], [text("Received:")]),
          span([class("payout-amount")], [text(int.to_string(p.received))]),
        ]),
      ])
  }
}

// --- Rules Page ---

fn view_rules_page() -> Element(Msg) {
  div([class("rules-page")], [
    html.article([class("rules-content")], [
      h2([], [text("Scoring Rules")]),
      html.details([class("original-ref")], [
        html.summary([], [text("Show original")]),
        html.img([
          attribute.src("/scoring.jpg"),
          attribute.alt("Original scoring reference"),
          class("original-img"),
        ]),
      ]),
      html.p([], [
        text(
          "This app calculates Mah-jong hand scores. Enter each player's melds and bonuses to see their points.",
        ),
      ]),
      h3([], [text("Pungs (3 of a kind)")]),
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
      h3([], [text("Kongs (4 of a kind)")]),
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
      h3([], [text("Bonuses")]),
      html.ul([], [
        html.li([], [text("Pair of Winds: 2 pts")]),
        html.li([], [text("Pair of Dragons: 2 pts")]),
        html.li([], [text("Flower: 4 pts")]),
        html.li([], [text("Mah-jonging: 20 pts")]),
      ]),
      h3([], [text("Doubles")]),
      html.p([], [
        text("Each double multiplies the final score by 2. Doubles stack."),
      ]),
      html.table([class("rules-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [text("Condition")]),
            html.th([], [text("Doubles")]),
          ]),
        ]),
        html.tbody([], [
          html.tr([], [
            html.td([], [text("Being clean (no chows)")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("Pung/Kong of Dragons")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("Pung/Kong of own Wind")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("Pung/Kong of Prevailing Wind")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("Both own Flowers")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("Being East Wind")]),
            html.td([], [text("1")]),
          ]),
          html.tr([], [
            html.td([], [text("All 4 Red or all 4 Blue Flowers")]),
            html.td([], [text("3")]),
          ]),
          html.tr([], [
            html.td([], [text("Clean without Winds or Dragons")]),
            html.td([], [text("3")]),
          ]),
        ]),
      ]),
      h3([], [text("Payouts")]),
      html.ul([], [
        html.li([], [
          text("Each loser pays the winner their own score difference"),
        ]),
        html.li([], [text("East Wind pays and receives double")]),
        html.li([], [
          text("Limit: 500 pts (1000 for East)"),
        ]),
      ]),
      h2([], [text("Limit Hands")]),
      html.details([class("original-ref")], [
        html.summary([], [text("Show original")]),
        html.img([
          attribute.src("/limit-hands.jpg"),
          attribute.alt("Original limit hands reference"),
          class("original-img"),
        ]),
      ]),
      html.p([], [
        text(
          "Limit hands are special winning patterns worth the maximum score. Must be clean.",
        ),
      ]),
      html.ul([], [
        html.li([], [
          html.strong([], [text("Celestial Wonder: ")]),
          text("1 & 9 of each of 3 suits + one of each Wind & Dragon, pair to one of them"),
        ]),
        html.li([], [
          html.strong([], [text("1-9: ")]),
          text("1-9 of a suit + 4 Winds or Dragons + pair to one of them"),
        ]),
        html.li([], [
          html.strong([], [text("Crochet: ")]),
          text("4 sets of 3 + pair in three suits, no Winds or Dragons"),
        ]),
        html.li([], [
          html.strong([], [text("Knitting: ")]),
          text("7 pairs in 2 suits, no Winds or Dragons"),
        ]),
        html.li([], [
          html.strong([], [text("Clean Pairs: ")]),
          text("7 pairs all in 1 suit or with Winds & Dragons"),
        ]),
        html.li([], [
          html.strong([], [text("Green Hand: ")]),
          text("3 of a kind of all green sticks (2, 3, 4, 6, 8) and Green Dragon"),
        ]),
        html.li([], [
          html.strong([], [text("Regular Hand: ")]),
          text("4 sets of 3 & a pair, clean (1 suit or honors incl. 1 & 9) and Winds & Dragons"),
        ]),
        html.li([], [
          html.strong([], [text("Heavenly Twins: ")]),
          text("7 pairs of honors (1s & 9s of Winds & Dragons)"),
        ]),
      ]),
      h2([], [text("Feedback")]),
      html.p([], [
        text(
          "This is open source software created by Ray and Liz based on family rules played by the original Ray and Liz.",
        ),
      ]),
      html.p([], [
        text("Found a bug or have a suggestion? "),
        html.a(
          [
            attribute.href(
              "https://github.com/raymyers/alley-mah-jong/issues",
            ),
            attribute.attribute("target", "_blank"),
          ],
          [text("Open an issue on GitHub")],
        ),
        text("."),
      ]),
    ]),
  ])
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

fn get_player_display_name(
  player: storage.Player,
  names: #(String, String, String, String),
) -> String {
  get_player_name(player_from_storage(player), names)
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

// --- Score Calculation Helpers ---

fn calculate_round_scores(round: Round) -> #(Int, Int, Int, Int) {
  let winner = option.map(round.winner, player_from_storage)
  let east = player_from_storage(round.east_wind)

  let calc = fn(hand, doubles, status, player) {
    let is_winner = winner == Some(player)
    let is_east = player == east
    let engine_hand = hand_from_storage(hand)
    let engine_doubles = doubles_from_storage(doubles)
    let engine_status = hand_status_to_engine(hand_status_from_storage(status))
    let #(score, _, _, _) =
      engine.calculate_final_score(
        engine_hand,
        engine_status,
        engine_doubles,
        is_winner,
        is_east,
      )
    score
  }

  #(
    calc(round.hands.0, round.doubles.0, round.hand_statuses.0, Player1),
    calc(round.hands.1, round.doubles.1, round.hand_statuses.1, Player2),
    calc(round.hands.2, round.doubles.2, round.hand_statuses.2, Player3),
    calc(round.hands.3, round.doubles.3, round.hand_statuses.3, Player4),
  )
}

fn calculate_all_running_scores(game: Game) -> List(#(Int, Int, Int, Int)) {
  list.fold(game.rounds, [], fn(acc, round) {
    let prev = case list.last(acc) {
      Ok(scores) -> scores
      Error(_) -> #(
        game.starting_score,
        game.starting_score,
        game.starting_score,
        game.starting_score,
      )
    }
    // Check if round is scoreable (has winner AND limit invariants satisfied)
    let winner_opt = option.map(round.winner, player_from_storage)
    let statuses = #(
      hand_status_to_engine(hand_status_from_storage(round.hand_statuses.0)),
      hand_status_to_engine(hand_status_from_storage(round.hand_statuses.1)),
      hand_status_to_engine(hand_status_from_storage(round.hand_statuses.2)),
      hand_status_to_engine(hand_status_from_storage(round.hand_statuses.3)),
    )
    case engine.is_round_scoreable(winner_opt, statuses) {
      False -> acc
      // Skip unscorable rounds (no winner, limit conflict, multiple limits)
      True -> {
        let scores = calculate_round_scores(round)
        let east = player_from_storage(round.east_wind)
        let winner = option.unwrap(winner_opt, Player1)
        let payouts = engine.calculate_payouts(scores, statuses, winner, east)
        let nets = #(
          engine.net_payout(payouts.0),
          engine.net_payout(payouts.1),
          engine.net_payout(payouts.2),
          engine.net_payout(payouts.3),
        )
        let new_running = #(
          prev.0 + nets.0,
          prev.1 + nets.1,
          prev.2 + nets.2,
          prev.3 + nets.3,
        )
        list.append(acc, [new_running])
      }
    }
  })
}

fn get_at(items: List(a), index: Int) -> Option(a) {
  case items {
    [] -> None
    [first, ..rest] ->
      case index {
        0 -> Some(first)
        _ -> get_at(rest, index - 1)
      }
  }
}

// --- Styles ---

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
    --row-label-width: 75px;
    --row-gap: 4px;
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
  h1, h2 {
    text-transform: uppercase;
    letter-spacing: 4px;
    margin: 0;
  }
  h2 {
    letter-spacing: 2px;
    font-size: 18px;
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
  /* Game page */
  .no-game {
    text-align: center;
    padding: 60px 20px;
  }
  .game-summary {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .game-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .standings {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
    padding: 16px;
    background: var(--paper);
    border: 2px solid var(--carbon-faded);
  }
  .standing {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 100px;
  }
  .standing-name {
    font-size: 12px;
    text-transform: uppercase;
    color: var(--carbon-light);
  }
  .standing-score {
    font-size: 24px;
    font-weight: bold;
  }
  .rounds-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .round-summary {
    background: var(--paper);
    border: 1px solid var(--carbon-faded);
    padding: 12px;
    cursor: pointer;
  }
  .round-summary:hover {
    border-color: var(--carbon);
  }
  .round-summary.no-winner .round-details {
    text-decoration: line-through;
    opacity: 0.6;
  }
  .round-summary.no-winner .round-winner {
    color: var(--carbon-faded);
    font-style: italic;
  }
  .round-header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .round-number {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 12px;
  }
  .round-winner {
    font-size: 12px;
    color: var(--carbon-light);
  }
  .round-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 11px;
  }
  .player-row {
    display: grid;
    grid-template-columns: 1fr 60px 60px 80px;
    gap: 8px;
    padding: 4px 0;
    border-bottom: 1px dotted var(--carbon-faded);
  }
  .player-name { font-weight: bold; }
  .player-score { text-align: right; }
  .player-net { text-align: right; color: var(--ink-purple); }
  .player-running { text-align: right; font-weight: bold; }
  .add-round-btn {
    padding: 12px 24px;
    background: var(--ink-purple);
    color: var(--paper);
    border: none;
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 12px;
    letter-spacing: 1px;
  }
  .add-round-btn:hover {
    background: var(--carbon);
  }
  .new-game-btn {
    padding: 12px 24px;
    background: var(--ink-purple);
    color: var(--paper);
    border: none;
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 12px;
    letter-spacing: 1px;
  }
  .new-game-btn:hover {
    background: var(--carbon);
  }
  .new-game-btn.secondary {
    background: var(--btn-dark);
    color: var(--carbon);
    border: 1px solid var(--carbon-faded);
  }
  .new-game-btn.secondary:hover {
    background: var(--btn-darker);
    border-color: var(--carbon);
  }
  /* New game page */
  .new-game-page {
    background: var(--paper);
    border: 2px solid var(--carbon-faded);
    padding: 24px;
  }
  .setup-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-top: 16px;
  }
  .setup-field {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .setup-field label {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
  }
  .setup-input {
    font-family: 'Courier New', Courier, monospace;
    padding: 8px 12px;
    border: 1px solid var(--carbon-faded);
    font-size: 14px;
    max-width: 200px;
  }
  .setup-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .setup-section label {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
  }
  .setup-actions {
    display: flex;
    gap: 12px;
    margin-top: 16px;
  }
  .cancel-btn {
    padding: 12px 24px;
    background: var(--btn-dark);
    color: var(--carbon);
    border: 1px solid var(--carbon-faded);
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-weight: bold;
    text-transform: uppercase;
    font-size: 12px;
  }
  .cancel-btn:hover {
    background: var(--btn-darker);
  }
  /* Round page */
  .round-title {
    margin-bottom: 16px;
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
    gap: var(--row-gap);
    align-items: center;
    flex-wrap: wrap;
  }
  .row-label {
    font-size: 10px;
    color: var(--carbon-light);
    width: var(--row-label-width);
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
  .rules-content h2 + .original-ref {
    margin-top: 0;
  }
  .rules-content h2 {
    margin-top: 32px;
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
  .original-ref {
    margin-top: 16px;
    margin-bottom: 16px;
  }
  .original-ref summary {
    cursor: pointer;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--ink-purple);
    font-weight: bold;
    padding: 8px 0;
  }
  .original-ref summary:hover {
    text-decoration: underline;
  }
  .original-img {
    max-width: 100%;
    margin-top: 12px;
    border: 1px solid var(--carbon-faded);
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
    gap: var(--row-gap);
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
  .limit-conflict-warning {
    color: #8b0000;
    font-size: 10px;
    font-style: italic;
    margin-left: 8px;
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
  .doubles-section .add-row {
    padding-left: calc(var(--row-label-width) + var(--row-gap));
  }
  .doubles-section .row-label {
    margin-left: calc(-1 * var(--row-label-width) - var(--row-gap));
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
  /* Payout section */
  .payout-section {
    margin-top: 10px;
    padding-top: 10px;
    border-top: 2px solid var(--carbon-faded);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .payout-row {
    display: flex;
    align-items: baseline;
    gap: 8px;
  }
  .payout-label {
    font-size: 10px;
    color: var(--carbon-light);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    width: var(--row-label-width);
    flex-shrink: 0;
  }
  .payout-entries {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }
  .payout-entry {
    font-size: 11px;
    color: var(--carbon);
  }
  .payout-amount {
    font-size: 14px;
    font-weight: bold;
    color: var(--ink-purple);
  }
  "
}

// --- Main ---

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
