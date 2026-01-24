import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}

// --- FFI for localStorage ---

@external(javascript, "./storage_ffi.mjs", "getItem")
pub fn get_item(key: String) -> Option(String)

@external(javascript, "./storage_ffi.mjs", "setItem")
pub fn set_item(key: String, value: String) -> Nil

@external(javascript, "./storage_ffi.mjs", "removeItem")
pub fn remove_item(key: String) -> Nil

// --- Types (re-exported for serialization) ---

pub type ScoringItem {
  Pung
  PungHonors
  PungHidden
  PungHonorsHidden
  Kong
  KongHonors
  KongHidden
  KongHonorsHidden
  BonusPairWind
  BonusPairDragon
  BonusFlower
}

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

pub type DoublesContext {
  DoublesContext(
    is_clean: Bool,
    has_dragon_pung_or_kong: Bool,
    has_own_wind_pung_or_kong: Bool,
    has_prevailing_wind_pung_or_kong: Bool,
    has_both_own_flowers: Bool,
    is_east_wind: Bool,
    has_all_red_flowers: Bool,
    has_all_blue_flowers: Bool,
    is_clean_no_winds_or_dragons: Bool,
  )
}

pub fn no_doubles() -> DoublesContext {
  DoublesContext(
    is_clean: False,
    has_dragon_pung_or_kong: False,
    has_own_wind_pung_or_kong: False,
    has_prevailing_wind_pung_or_kong: False,
    has_both_own_flowers: False,
    is_east_wind: False,
    has_all_red_flowers: False,
    has_all_blue_flowers: False,
    is_clean_no_winds_or_dragons: False,
  )
}

pub type HandStatus {
  Dirty
  Clean
  Limit
}

// A single round of play
pub type Round {
  Round(
    east_wind: Player,
    prevailing_wind: Wind,
    winner: Option(Player),
    hands: #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
    doubles: #(DoublesContext, DoublesContext, DoublesContext, DoublesContext),
    hand_statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
  )
}

// A full game with multiple rounds
pub type Game {
  Game(
    starting_score: Int,
    names: #(String, String, String, String),
    rounds: List(Round),
    editing_round: Option(Int),
  )
}

pub fn empty_round(east: Player, prevailing: Wind) -> Round {
  Round(
    east_wind: east,
    prevailing_wind: prevailing,
    winner: None,
    hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
    doubles: #(no_doubles(), no_doubles(), no_doubles(), no_doubles()),
    hand_statuses: #(Dirty, Dirty, Dirty, Dirty),
  )
}

pub fn new_game(
  starting_score: Int,
  names: #(String, String, String, String),
) -> Game {
  Game(
    starting_score: starting_score,
    names: names,
    rounds: [empty_round(Player1, East)],
    editing_round: Some(0),
  )
}

pub const default_starting_score = 3550

// --- JSON Encoding ---

pub fn encode_game(game: Game) -> String {
  json.to_string(encode_game_json(game))
}

fn encode_game_json(game: Game) -> Json {
  json.object([
    #("starting_score", json.int(game.starting_score)),
    #("names", encode_names(game.names)),
    #("rounds", json.array(game.rounds, encode_round_json)),
    #("editing_round", encode_option_int(game.editing_round)),
  ])
}

fn encode_round_json(round: Round) -> Json {
  json.object([
    #("east_wind", encode_player(round.east_wind)),
    #("prevailing_wind", encode_wind(round.prevailing_wind)),
    #("winner", encode_option_player(round.winner)),
    #("hands", encode_hands(round.hands)),
    #("doubles", encode_doubles_list(round.doubles)),
    #("hand_statuses", encode_hand_statuses(round.hand_statuses)),
  ])
}

fn encode_player(player: Player) -> Json {
  json.string(case player {
    Player1 -> "Player1"
    Player2 -> "Player2"
    Player3 -> "Player3"
    Player4 -> "Player4"
  })
}

fn encode_wind(wind: Wind) -> Json {
  json.string(case wind {
    North -> "North"
    South -> "South"
    East -> "East"
    West -> "West"
  })
}

fn encode_option_player(opt: Option(Player)) -> Json {
  case opt {
    None -> json.null()
    Some(p) -> encode_player(p)
  }
}

fn encode_option_int(opt: Option(Int)) -> Json {
  case opt {
    None -> json.null()
    Some(i) -> json.int(i)
  }
}

fn encode_hands(
  hands: #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
) -> Json {
  json.array([hands.0, hands.1, hands.2, hands.3], encode_hand)
}

fn encode_hand(hand: PlayerHand) -> Json {
  json.array(hand.items, encode_item)
}

fn encode_item(item: ScoringItem) -> Json {
  json.string(case item {
    Pung -> "Pung"
    PungHonors -> "PungHonors"
    PungHidden -> "PungHidden"
    PungHonorsHidden -> "PungHonorsHidden"
    Kong -> "Kong"
    KongHonors -> "KongHonors"
    KongHidden -> "KongHidden"
    KongHonorsHidden -> "KongHonorsHidden"
    BonusPairWind -> "BonusPairWind"
    BonusPairDragon -> "BonusPairDragon"
    BonusFlower -> "BonusFlower"
  })
}

fn encode_names(names: #(String, String, String, String)) -> Json {
  json.array([names.0, names.1, names.2, names.3], json.string)
}

fn encode_doubles_list(
  doubles: #(DoublesContext, DoublesContext, DoublesContext, DoublesContext),
) -> Json {
  json.array([doubles.0, doubles.1, doubles.2, doubles.3], encode_doubles)
}

fn encode_hand_statuses(
  statuses: #(HandStatus, HandStatus, HandStatus, HandStatus),
) -> Json {
  json.array(
    [statuses.0, statuses.1, statuses.2, statuses.3],
    encode_hand_status,
  )
}

fn encode_hand_status(status: HandStatus) -> Json {
  json.string(case status {
    Dirty -> "Dirty"
    Clean -> "Clean"
    Limit -> "Limit"
  })
}

fn encode_doubles(ctx: DoublesContext) -> Json {
  json.object([
    #("is_clean", json.bool(ctx.is_clean)),
    #("has_dragon_pung_or_kong", json.bool(ctx.has_dragon_pung_or_kong)),
    #("has_own_wind_pung_or_kong", json.bool(ctx.has_own_wind_pung_or_kong)),
    #(
      "has_prevailing_wind_pung_or_kong",
      json.bool(ctx.has_prevailing_wind_pung_or_kong),
    ),
    #("has_both_own_flowers", json.bool(ctx.has_both_own_flowers)),
    #("is_east_wind", json.bool(ctx.is_east_wind)),
    #("has_all_red_flowers", json.bool(ctx.has_all_red_flowers)),
    #("has_all_blue_flowers", json.bool(ctx.has_all_blue_flowers)),
    #(
      "is_clean_no_winds_or_dragons",
      json.bool(ctx.is_clean_no_winds_or_dragons),
    ),
  ])
}

// --- JSON Decoding ---

pub fn decode_game(json_string: String) -> Result(Game, json.DecodeError) {
  json.parse(json_string, game_decoder())
}

fn game_decoder() -> decode.Decoder(Game) {
  use starting_score <- decode.field("starting_score", decode.int)
  use names <- decode.field("names", names_decoder())
  use rounds <- decode.field("rounds", decode.list(round_decoder()))
  use editing_round <- decode.field(
    "editing_round",
    decode.optional(decode.int),
  )
  decode.success(Game(
    starting_score: starting_score,
    names: names,
    rounds: rounds,
    editing_round: editing_round,
  ))
}

fn round_decoder() -> decode.Decoder(Round) {
  use east_wind <- decode.field("east_wind", player_decoder())
  use prevailing_wind <- decode.field("prevailing_wind", wind_decoder())
  use winner <- decode.field("winner", decode.optional(player_decoder()))
  use hands <- decode.field("hands", hands_decoder())
  use doubles_opt <- decode.field(
    "doubles",
    decode.optional(doubles_list_decoder()),
  )
  let doubles = case doubles_opt {
    Some(d) -> d
    None -> #(no_doubles(), no_doubles(), no_doubles(), no_doubles())
  }
  use statuses_opt <- decode.field(
    "hand_statuses",
    decode.optional(hand_statuses_decoder()),
  )
  let hand_statuses = case statuses_opt {
    Some(s) -> s
    None -> #(Dirty, Dirty, Dirty, Dirty)
  }
  decode.success(Round(
    east_wind: east_wind,
    prevailing_wind: prevailing_wind,
    winner: winner,
    hands: hands,
    doubles: doubles,
    hand_statuses: hand_statuses,
  ))
}

fn player_decoder() -> decode.Decoder(Player) {
  use s <- decode.then(decode.string)
  case s {
    "Player1" -> decode.success(Player1)
    "Player2" -> decode.success(Player2)
    "Player3" -> decode.success(Player3)
    "Player4" -> decode.success(Player4)
    _ -> decode.failure(Player1, "Player")
  }
}

fn wind_decoder() -> decode.Decoder(Wind) {
  use s <- decode.then(decode.string)
  case s {
    "North" -> decode.success(North)
    "South" -> decode.success(South)
    "East" -> decode.success(East)
    "West" -> decode.success(West)
    _ -> decode.failure(East, "Wind")
  }
}

fn hands_decoder() -> decode.Decoder(
  #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
) {
  use hands <- decode.then(decode.list(hand_decoder()))
  case hands {
    [h1, h2, h3, h4] -> decode.success(#(h1, h2, h3, h4))
    _ ->
      decode.failure(
        #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
        "4 hands",
      )
  }
}

fn hand_decoder() -> decode.Decoder(PlayerHand) {
  use items <- decode.then(decode.list(item_decoder()))
  decode.success(PlayerHand(items: items))
}

fn item_decoder() -> decode.Decoder(ScoringItem) {
  use s <- decode.then(decode.string)
  case s {
    "Pung" -> decode.success(Pung)
    "PungHonors" -> decode.success(PungHonors)
    "PungHidden" -> decode.success(PungHidden)
    "PungHonorsHidden" -> decode.success(PungHonorsHidden)
    "Kong" -> decode.success(Kong)
    "KongHonors" -> decode.success(KongHonors)
    "KongHidden" -> decode.success(KongHidden)
    "KongHonorsHidden" -> decode.success(KongHonorsHidden)
    "BonusPairWind" -> decode.success(BonusPairWind)
    "BonusPairDragon" -> decode.success(BonusPairDragon)
    "BonusFlower" -> decode.success(BonusFlower)
    _ -> decode.failure(Pung, "ScoringItem")
  }
}

fn names_decoder() -> decode.Decoder(#(String, String, String, String)) {
  use names <- decode.then(decode.list(decode.string))
  case names {
    [n1, n2, n3, n4] -> decode.success(#(n1, n2, n3, n4))
    _ -> decode.failure(#("", "", "", ""), "4 names")
  }
}

fn doubles_list_decoder() -> decode.Decoder(
  #(DoublesContext, DoublesContext, DoublesContext, DoublesContext),
) {
  use doubles <- decode.then(decode.list(doubles_decoder()))
  case doubles {
    [d1, d2, d3, d4] -> decode.success(#(d1, d2, d3, d4))
    _ ->
      decode.failure(
        #(no_doubles(), no_doubles(), no_doubles(), no_doubles()),
        "4 doubles contexts",
      )
  }
}

fn hand_statuses_decoder() -> decode.Decoder(
  #(HandStatus, HandStatus, HandStatus, HandStatus),
) {
  use statuses <- decode.then(decode.list(hand_status_decoder()))
  case statuses {
    [s1, s2, s3, s4] -> decode.success(#(s1, s2, s3, s4))
    _ -> decode.failure(#(Dirty, Dirty, Dirty, Dirty), "4 hand statuses")
  }
}

fn hand_status_decoder() -> decode.Decoder(HandStatus) {
  use s <- decode.then(decode.string)
  case s {
    "Dirty" -> decode.success(Dirty)
    "Clean" -> decode.success(Clean)
    "Limit" -> decode.success(Limit)
    _ -> decode.failure(Dirty, "HandStatus")
  }
}

fn doubles_decoder() -> decode.Decoder(DoublesContext) {
  use is_clean <- decode.field("is_clean", decode.bool)
  use has_dragon_pung_or_kong <- decode.field(
    "has_dragon_pung_or_kong",
    decode.bool,
  )
  use has_own_wind_pung_or_kong <- decode.field(
    "has_own_wind_pung_or_kong",
    decode.bool,
  )
  use has_prevailing_wind_pung_or_kong <- decode.field(
    "has_prevailing_wind_pung_or_kong",
    decode.bool,
  )
  use has_both_own_flowers <- decode.field("has_both_own_flowers", decode.bool)
  use is_east_wind <- decode.field("is_east_wind", decode.bool)
  use has_all_red_flowers <- decode.field("has_all_red_flowers", decode.bool)
  use has_all_blue_flowers <- decode.field("has_all_blue_flowers", decode.bool)
  use is_clean_no_winds_or_dragons <- decode.field(
    "is_clean_no_winds_or_dragons",
    decode.bool,
  )
  decode.success(DoublesContext(
    is_clean: is_clean,
    has_dragon_pung_or_kong: has_dragon_pung_or_kong,
    has_own_wind_pung_or_kong: has_own_wind_pung_or_kong,
    has_prevailing_wind_pung_or_kong: has_prevailing_wind_pung_or_kong,
    has_both_own_flowers: has_both_own_flowers,
    is_east_wind: is_east_wind,
    has_all_red_flowers: has_all_red_flowers,
    has_all_blue_flowers: has_all_blue_flowers,
    is_clean_no_winds_or_dragons: is_clean_no_winds_or_dragons,
  ))
}

// --- Storage Key ---
// Changed key to avoid loading old incompatible data
const storage_key = "alley_mah_jong_game"

// --- Public API ---

pub fn save_game(game: Game) -> Nil {
  set_item(storage_key, encode_game(game))
}

pub fn load_game() -> Option(Game) {
  case get_item(storage_key) {
    None -> None
    Some(json_str) ->
      case decode_game(json_str) {
        Ok(game) -> Some(game)
        Error(_) -> None
      }
  }
}

pub fn clear_game() -> Nil {
  remove_item(storage_key)
}

// --- Round Helpers ---

pub fn update_round(game: Game, index: Int, round: Round) -> Game {
  Game(
    ..game,
    rounds: list.index_map(game.rounds, fn(r, i) {
      case i == index {
        True -> round
        False -> r
      }
    }),
  )
}

pub fn get_round(game: Game, index: Int) -> Option(Round) {
  get_at(game.rounds, index)
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
