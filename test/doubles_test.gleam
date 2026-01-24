import engine.{
  DoublesContext, calculate_doubles, calculate_multiplier, calculate_round_score,
  max_round_score, no_doubles,
}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// --- No Doubles ---

pub fn no_doubles_returns_zero_test() {
  let ctx = no_doubles()
  assert calculate_doubles(ctx) == 0
}

pub fn no_doubles_multiplier_is_one_test() {
  let ctx = no_doubles()
  assert calculate_multiplier(ctx) == 1
}

// --- Single Double Conditions (1 double each = 2x) ---

pub fn is_clean_gives_one_double_test() {
  let ctx = DoublesContext(..no_doubles(), is_clean: True)
  assert calculate_doubles(ctx) == 1
}

pub fn has_dragon_pung_or_kong_gives_one_double_test() {
  let ctx = DoublesContext(..no_doubles(), has_dragon_pung_or_kong: True)
  assert calculate_doubles(ctx) == 1
}

pub fn has_own_wind_pung_or_kong_gives_one_double_test() {
  let ctx = DoublesContext(..no_doubles(), has_own_wind_pung_or_kong: True)
  assert calculate_doubles(ctx) == 1
}

pub fn has_prevailing_wind_pung_or_kong_gives_one_double_test() {
  let ctx =
    DoublesContext(..no_doubles(), has_prevailing_wind_pung_or_kong: True)
  assert calculate_doubles(ctx) == 1
}

pub fn has_both_own_flowers_gives_one_double_test() {
  let ctx = DoublesContext(..no_doubles(), has_both_own_flowers: True)
  assert calculate_doubles(ctx) == 1
}

pub fn is_east_wind_gives_one_double_test() {
  let ctx = DoublesContext(..no_doubles(), is_east_wind: True)
  assert calculate_doubles(ctx) == 1
}

// --- Triple Double Conditions (3 doubles each = 8x) ---

pub fn has_all_red_flowers_gives_three_doubles_test() {
  let ctx = DoublesContext(..no_doubles(), has_all_red_flowers: True)
  assert calculate_doubles(ctx) == 3
}

pub fn has_all_blue_flowers_gives_three_doubles_test() {
  let ctx = DoublesContext(..no_doubles(), has_all_blue_flowers: True)
  assert calculate_doubles(ctx) == 3
}

pub fn is_clean_no_winds_or_dragons_gives_three_doubles_test() {
  let ctx = DoublesContext(..no_doubles(), is_clean_no_winds_or_dragons: True)
  assert calculate_doubles(ctx) == 3
}

// --- Multiplier Calculation ---

pub fn one_double_gives_2x_multiplier_test() {
  let ctx = DoublesContext(..no_doubles(), is_clean: True)
  assert calculate_multiplier(ctx) == 2
}

pub fn two_doubles_gives_4x_multiplier_test() {
  let ctx = DoublesContext(..no_doubles(), is_clean: True, is_east_wind: True)
  assert calculate_multiplier(ctx) == 4
}

pub fn three_doubles_gives_8x_multiplier_test() {
  let ctx = DoublesContext(..no_doubles(), has_all_red_flowers: True)
  assert calculate_multiplier(ctx) == 8
}

pub fn four_doubles_gives_16x_multiplier_test() {
  // 3 from all red flowers + 1 from being east
  let ctx =
    DoublesContext(
      ..no_doubles(),
      has_all_red_flowers: True,
      is_east_wind: True,
    )
  assert calculate_multiplier(ctx) == 16
}

// --- Stacking Doubles ---

pub fn multiple_single_doubles_stack_test() {
  // clean + dragon + east = 3 doubles = 8x
  let ctx =
    DoublesContext(
      ..no_doubles(),
      is_clean: True,
      has_dragon_pung_or_kong: True,
      is_east_wind: True,
    )
  assert calculate_doubles(ctx) == 3
  assert calculate_multiplier(ctx) == 8
}

pub fn triple_doubles_stack_with_singles_test() {
  // all red (3) + all blue (3) + east (1) = 7 doubles = 128x
  let ctx =
    DoublesContext(
      ..no_doubles(),
      has_all_red_flowers: True,
      has_all_blue_flowers: True,
      is_east_wind: True,
    )
  assert calculate_doubles(ctx) == 7
  assert calculate_multiplier(ctx) == 128
}

pub fn all_single_conditions_test() {
  // All 6 single-double conditions = 6 doubles = 64x
  let ctx =
    DoublesContext(
      ..no_doubles(),
      is_clean: True,
      has_dragon_pung_or_kong: True,
      has_own_wind_pung_or_kong: True,
      has_prevailing_wind_pung_or_kong: True,
      has_both_own_flowers: True,
      is_east_wind: True,
    )
  assert calculate_doubles(ctx) == 6
  assert calculate_multiplier(ctx) == 64
}

// --- Clean Interaction ---

pub fn clean_no_winds_dragons_implies_clean_test() {
  // If you're clean with no winds/dragons, you're also clean
  // But the 3-double condition is separate, so both can apply
  // clean (1) + clean_no_winds_dragons (3) = 4 doubles
  let ctx =
    DoublesContext(
      ..no_doubles(),
      is_clean: True,
      is_clean_no_winds_or_dragons: True,
    )
  assert calculate_doubles(ctx) == 4
  assert calculate_multiplier(ctx) == 16
}

// --- Round Score with Max Cap ---

pub fn max_round_score_is_1000_test() {
  assert max_round_score == 1000
}

pub fn round_score_under_max_not_capped_test() {
  // 100 pts * 4x = 400, under max
  assert calculate_round_score(100, 4) == 400
}

pub fn round_score_at_max_not_capped_test() {
  // 500 pts * 2x = 1000, exactly at max
  assert calculate_round_score(500, 2) == 1000
}

pub fn round_score_over_max_capped_test() {
  // 200 pts * 8x = 1600, capped to 1000
  assert calculate_round_score(200, 8) == 1000
}

pub fn round_score_high_multiplier_capped_test() {
  // 50 pts * 128x = 6400, capped to 1000
  assert calculate_round_score(50, 128) == 1000
}

pub fn round_score_no_multiplier_test() {
  // 500 pts * 1x = 500
  assert calculate_round_score(500, 1) == 500
}
