import gleam/option.{None, Some}
import storage.{
  BonusFlower, BonusPairDragon, BonusPairWind, East, GameState, Kong, KongHidden,
  KongHonors, KongHonorsHidden, North, Player1, Player2, Player3, Player4,
  PlayerHand, Pung, PungHidden, PungHonors, PungHonorsHidden, South, West,
  decode_state, encode_state, no_doubles,
}

fn empty_doubles() {
  #(no_doubles(), no_doubles(), no_doubles(), no_doubles())
}

// --- Encoding/Decoding Tests ---

pub fn encode_decode_empty_state_test() {
  let state =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  let encoded = encode_state(state)
  let decoded = decode_state(encoded)
  assert decoded == Ok(state)
}

pub fn encode_decode_full_state_test() {
  let state =
    GameState(
      east_wind: Player3,
      prevailing_wind: South,
      winner: Some(Player2),
      hands: #(
        PlayerHand([Pung, PungHonors]),
        PlayerHand([Kong, KongHidden]),
        PlayerHand([BonusFlower, BonusPairWind]),
        PlayerHand([PungHidden, KongHonorsHidden]),
      ),
      names: #("Alice", "Bob", "Carol", "Dave"),
      doubles: empty_doubles(),
    )
  let encoded = encode_state(state)
  let decoded = decode_state(encoded)
  assert decoded == Ok(state)
}

pub fn encode_decode_all_players_test() {
  // Test all player values
  let state1 =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: Some(Player1),
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state1)) == Ok(state1)

  let state2 =
    GameState(
      east_wind: Player2,
      prevailing_wind: East,
      winner: Some(Player2),
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state2)) == Ok(state2)

  let state3 =
    GameState(
      east_wind: Player3,
      prevailing_wind: East,
      winner: Some(Player3),
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state3)) == Ok(state3)

  let state4 =
    GameState(
      east_wind: Player4,
      prevailing_wind: East,
      winner: Some(Player4),
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state4)) == Ok(state4)
}

pub fn encode_decode_all_winds_test() {
  let state_east =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state_east)) == Ok(state_east)

  let state_south =
    GameState(
      east_wind: Player1,
      prevailing_wind: South,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state_south)) == Ok(state_south)

  let state_west =
    GameState(
      east_wind: Player1,
      prevailing_wind: West,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state_west)) == Ok(state_west)

  let state_north =
    GameState(
      east_wind: Player1,
      prevailing_wind: North,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state_north)) == Ok(state_north)
}

pub fn encode_decode_all_scoring_items_test() {
  let all_items = [
    Pung,
    PungHonors,
    PungHidden,
    PungHonorsHidden,
    Kong,
    KongHonors,
    KongHidden,
    KongHonorsHidden,
    BonusPairWind,
    BonusPairDragon,
    BonusFlower,
  ]
  let state =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(
        PlayerHand(all_items),
        PlayerHand([]),
        PlayerHand([]),
        PlayerHand([]),
      ),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state)) == Ok(state)
}

pub fn encode_decode_no_winner_test() {
  let state =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    )
  assert decode_state(encode_state(state)) == Ok(state)
}

pub fn encode_decode_with_names_test() {
  let state =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("Alice", "Bob", "Carol", "Dave"),
      doubles: empty_doubles(),
    )
  let encoded = encode_state(state)
  let decoded = decode_state(encoded)
  assert decoded == Ok(state)
}

pub fn decode_invalid_json_test() {
  let result = decode_state("not valid json")
  assert result
    != Ok(GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: empty_doubles(),
    ))
}

pub fn encode_decode_with_doubles_test() {
  let state =
    GameState(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([])),
      names: #("", "", "", ""),
      doubles: #(
        storage.DoublesContext(
          is_clean: True,
          has_dragon_pung_or_kong: True,
          has_own_wind_pung_or_kong: False,
          has_prevailing_wind_pung_or_kong: False,
          has_both_own_flowers: False,
          is_east_wind: False,
          has_all_red_flowers: False,
          has_all_blue_flowers: False,
          is_clean_no_winds_or_dragons: False,
        ),
        no_doubles(),
        no_doubles(),
        no_doubles(),
      ),
    )
  let encoded = encode_state(state)
  let decoded = decode_state(encoded)
  assert decoded == Ok(state)
}
