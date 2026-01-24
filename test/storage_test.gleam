import gleam/option.{None, Some}
import storage.{
  BonusFlower, BonusPairDragon, BonusPairWind, Clean, Dirty, East, Game, Kong,
  KongHidden, KongHonors, KongHonorsHidden, Limit, North, Player1, Player2,
  Player3, Player4, PlayerHand, Pung, PungHidden, PungHonors, PungHonorsHidden,
  Round, South, West, decode_game, encode_game, no_doubles,
}

fn empty_doubles() {
  #(no_doubles(), no_doubles(), no_doubles(), no_doubles())
}

fn default_statuses() {
  #(Dirty, Dirty, Dirty, Dirty)
}

fn empty_hands() {
  #(PlayerHand([]), PlayerHand([]), PlayerHand([]), PlayerHand([]))
}

// --- Game Encoding/Decoding Tests ---

pub fn encode_decode_empty_game_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: Some(0),
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn encode_decode_full_game_test() {
  let round =
    Round(
      east_wind: Player3,
      prevailing_wind: South,
      winner: Some(Player2),
      hands: #(
        PlayerHand([Pung, PungHonors]),
        PlayerHand([Kong, KongHidden]),
        PlayerHand([BonusFlower, BonusPairWind]),
        PlayerHand([PungHidden, KongHonorsHidden]),
      ),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("Alice", "Bob", "Carol", "Dave"),
      rounds: [round],
      editing_round: None,
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn encode_decode_all_players_test() {
  let round1 =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: Some(Player1),
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game1 =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round1],
      editing_round: None,
    )
  assert decode_game(encode_game(game1)) == Ok(game1)

  let round2 =
    Round(
      east_wind: Player2,
      prevailing_wind: East,
      winner: Some(Player2),
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game2 = Game(..game1, rounds: [round2])
  assert decode_game(encode_game(game2)) == Ok(game2)

  let round3 =
    Round(
      east_wind: Player3,
      prevailing_wind: East,
      winner: Some(Player3),
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game3 = Game(..game1, rounds: [round3])
  assert decode_game(encode_game(game3)) == Ok(game3)

  let round4 =
    Round(
      east_wind: Player4,
      prevailing_wind: East,
      winner: Some(Player4),
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game4 = Game(..game1, rounds: [round4])
  assert decode_game(encode_game(game4)) == Ok(game4)
}

pub fn encode_decode_all_winds_test() {
  let base_round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let base_game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [base_round],
      editing_round: None,
    )

  // Test East
  assert decode_game(encode_game(base_game)) == Ok(base_game)

  // Test South
  let round_south = Round(..base_round, prevailing_wind: South)
  let game_south = Game(..base_game, rounds: [round_south])
  assert decode_game(encode_game(game_south)) == Ok(game_south)

  // Test West
  let round_west = Round(..base_round, prevailing_wind: West)
  let game_west = Game(..base_game, rounds: [round_west])
  assert decode_game(encode_game(game_west)) == Ok(game_west)

  // Test North
  let round_north = Round(..base_round, prevailing_wind: North)
  let game_north = Game(..base_game, rounds: [round_north])
  assert decode_game(encode_game(game_north)) == Ok(game_north)
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
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: #(
        PlayerHand(all_items),
        PlayerHand([]),
        PlayerHand([]),
        PlayerHand([]),
      ),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: None,
    )
  assert decode_game(encode_game(game)) == Ok(game)
}

pub fn encode_decode_no_winner_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: None,
    )
  assert decode_game(encode_game(game)) == Ok(game)
}

pub fn encode_decode_with_names_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("Alice", "Bob", "Carol", "Dave"),
      rounds: [round],
      editing_round: None,
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn decode_invalid_json_test() {
  let result = decode_game("not valid json")
  assert result
    != Ok(Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [],
      editing_round: None,
    ))
}

pub fn encode_decode_with_doubles_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
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
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: None,
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn encode_decode_with_hand_statuses_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: #(Clean, Dirty, Limit, Clean),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: None,
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn encode_decode_multiple_rounds_test() {
  let round1 =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: Some(Player1),
      hands: #(
        PlayerHand([Pung]),
        PlayerHand([]),
        PlayerHand([]),
        PlayerHand([]),
      ),
      doubles: empty_doubles(),
      hand_statuses: #(Clean, Dirty, Dirty, Dirty),
    )
  let round2 =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: Some(Player2),
      hands: #(
        PlayerHand([]),
        PlayerHand([Kong]),
        PlayerHand([]),
        PlayerHand([]),
      ),
      doubles: empty_doubles(),
      hand_statuses: #(Dirty, Clean, Dirty, Dirty),
    )
  let game =
    Game(
      starting_score: 3550,
      names: #("Alice", "Bob", "Carol", "Dave"),
      rounds: [round1, round2],
      editing_round: Some(1),
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}

pub fn encode_decode_custom_starting_score_test() {
  let round =
    Round(
      east_wind: Player1,
      prevailing_wind: East,
      winner: None,
      hands: empty_hands(),
      doubles: empty_doubles(),
      hand_statuses: default_statuses(),
    )
  let game =
    Game(
      starting_score: 5000,
      names: #("", "", "", ""),
      rounds: [round],
      editing_round: None,
    )
  let encoded = encode_game(game)
  let decoded = decode_game(encoded)
  assert decoded == Ok(game)
}
