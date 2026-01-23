import gleam/dynamic/decode
import gleam/json.{type Json}
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

pub type GameState {
  GameState(
    east_wind: Player,
    prevailing_wind: Wind,
    winner: Option(Player),
    hands: #(PlayerHand, PlayerHand, PlayerHand, PlayerHand),
    names: #(String, String, String, String),
  )
}

// --- JSON Encoding ---

pub fn encode_state(state: GameState) -> String {
  json.to_string(encode_state_json(state))
}

fn encode_state_json(state: GameState) -> Json {
  json.object([
    #("east_wind", encode_player(state.east_wind)),
    #("prevailing_wind", encode_wind(state.prevailing_wind)),
    #("winner", encode_option_player(state.winner)),
    #("hands", encode_hands(state.hands)),
    #("names", encode_names(state.names)),
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

// --- JSON Decoding ---

pub fn decode_state(json_string: String) -> Result(GameState, json.DecodeError) {
  json.parse(json_string, state_decoder())
}

fn state_decoder() -> decode.Decoder(GameState) {
  use east_wind <- decode.field("east_wind", player_decoder())
  use prevailing_wind <- decode.field("prevailing_wind", wind_decoder())
  use winner <- decode.field("winner", decode.optional(player_decoder()))
  use hands <- decode.field("hands", hands_decoder())
  use names <- decode.field("names", names_decoder())
  decode.success(GameState(
    east_wind: east_wind,
    prevailing_wind: prevailing_wind,
    winner: winner,
    hands: hands,
    names: names,
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

// --- Storage Key ---

const storage_key = "alley_mah_jong_state"

// --- Public API ---

pub fn save_state(state: GameState) -> Nil {
  set_item(storage_key, encode_state(state))
}

pub fn load_state() -> Option(GameState) {
  case get_item(storage_key) {
    None -> None
    Some(json_str) ->
      case decode_state(json_str) {
        Ok(state) -> Some(state)
        Error(_) -> None
      }
  }
}

pub fn clear_state() -> Nil {
  remove_item(storage_key)
}
