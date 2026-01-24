//// CSV-driven test harness for Alley Mah-Jong scoring
//// Reads test cases from test/cases/scoring.csv

import engine.{
  type DoublesContext, type PlayerHand, type ScoringItem, BonusFlower,
  BonusPairDragon, BonusPairWind, Clean, Dirty, DoublesContext, Kong,
  KongHidden, KongHonors, KongHonorsHidden, Limit, PlayerHand, Pung,
  PungHidden, PungHonors, PungHonorsHidden, calculate_final_score, no_doubles,
}
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gsv
import simplifile

/// Test case structure
pub type TestCase {
  TestCase(
    id: String,
    description: String,
    items: String,
    status: String,
    doubles: List(String),
    is_winner: Bool,
    is_east: Bool,
    expected_points: Int,
    expected_multiplier: Int,
    expected_doubles_count: Int,
  )
}

/// Parse a scoring item code into a ScoringItem
pub fn parse_item(code: String) -> Result(ScoringItem, String) {
  case code {
    "p" -> Ok(Pung)
    "ph" -> Ok(PungHonors)
    "hp" -> Ok(PungHidden)
    "hph" -> Ok(PungHonorsHidden)
    "k" -> Ok(Kong)
    "kh" -> Ok(KongHonors)
    "hk" -> Ok(KongHidden)
    "hkh" -> Ok(KongHonorsHidden)
    "bpw" -> Ok(BonusPairWind)
    "bpd" -> Ok(BonusPairDragon)
    "bf" -> Ok(BonusFlower)
    other -> Error("Unknown item code: " <> other)
  }
}

/// Parse a space-separated string of item codes into a PlayerHand
pub fn parse_items(items_str: String) -> Result(PlayerHand, String) {
  let trimmed = string.trim(items_str)
  case trimmed {
    "" -> Ok(PlayerHand(items: []))
    _ -> {
      let codes = string.split(trimmed, " ")
      let results = list.map(codes, parse_item)
      let errors =
        list.filter_map(results, fn(r) {
          case r {
            Error(e) -> Ok(e)
            Ok(_) -> Error(Nil)
          }
        })
      case errors {
        [] -> {
          let items =
            list.filter_map(results, fn(r) {
              case r {
                Ok(item) -> Ok(item)
                Error(_) -> Error(Nil)
              }
            })
          Ok(PlayerHand(items: items))
        }
        _ -> Error(string.join(errors, ", "))
      }
    }
  }
}

/// Parse hand status string
pub fn parse_status(status_str: String) -> Result(engine.HandStatus, String) {
  case status_str {
    "dirty" -> Ok(Dirty)
    "clean" -> Ok(Clean)
    "limit" -> Ok(Limit)
    other -> Error("Unknown status: " <> other)
  }
}

/// Parse doubles string (space-separated) into DoublesContext
pub fn parse_doubles(doubles_str: String) -> DoublesContext {
  let base = no_doubles()
  let trimmed = string.trim(doubles_str)
  case trimmed {
    "" -> base
    _ -> {
      let codes = string.split(trimmed, " ")
      list.fold(codes, base, fn(ctx, code) {
        case code {
          "dragon" -> DoublesContext(..ctx, has_dragon_pung_or_kong: True)
          "own_wind" -> DoublesContext(..ctx, has_own_wind_pung_or_kong: True)
          "prevail_wind" ->
            DoublesContext(..ctx, has_prevailing_wind_pung_or_kong: True)
          "own_flowers" -> DoublesContext(..ctx, has_both_own_flowers: True)
          "red_flowers" -> DoublesContext(..ctx, has_all_red_flowers: True)
          "blue_flowers" -> DoublesContext(..ctx, has_all_blue_flowers: True)
          "pure" -> DoublesContext(..ctx, is_clean_no_winds_or_dragons: True)
          _ -> ctx
        }
      })
    }
  }
}

/// Run a single test case
fn execute_case(test_case: TestCase) -> Result(Nil, String) {
  use hand <- result.try(parse_items(test_case.items))
  use status <- result.try(parse_status(test_case.status))
  let doubles = parse_doubles(string.join(test_case.doubles, " "))

  let #(actual_points, actual_mult, actual_doubles) =
    calculate_final_score(
      hand,
      status,
      doubles,
      test_case.is_winner,
      test_case.is_east,
    )

  case
    actual_points == test_case.expected_points
    && actual_mult == test_case.expected_multiplier
    && actual_doubles == test_case.expected_doubles_count
  {
    True -> Ok(Nil)
    False ->
      Error(
        "Expected ("
        <> int.to_string(test_case.expected_points)
        <> ", "
        <> int.to_string(test_case.expected_multiplier)
        <> "x, "
        <> int.to_string(test_case.expected_doubles_count)
        <> " doubles) but got ("
        <> int.to_string(actual_points)
        <> ", "
        <> int.to_string(actual_mult)
        <> "x, "
        <> int.to_string(actual_doubles)
        <> " doubles)",
      )
  }
}

/// Parse a row dict into a TestCase
fn parse_row(row: dict.Dict(String, String)) -> Result(TestCase, String) {
  use id <- result.try(
    dict.get(row, "id") |> result.map_error(fn(_) { "Missing id" }),
  )
  use description <- result.try(
    dict.get(row, "description")
    |> result.map_error(fn(_) { "Missing description" }),
  )
  let items = dict.get(row, "items") |> result.unwrap("")
  use status <- result.try(
    dict.get(row, "status") |> result.map_error(fn(_) { "Missing status" }),
  )
  let doubles_str = dict.get(row, "doubles") |> result.unwrap("")
  let doubles = case string.trim(doubles_str) {
    "" -> []
    s -> string.split(s, " ")
  }
  use is_winner_str <- result.try(
    dict.get(row, "is_winner")
    |> result.map_error(fn(_) { "Missing is_winner" }),
  )
  use is_east_str <- result.try(
    dict.get(row, "is_east") |> result.map_error(fn(_) { "Missing is_east" }),
  )
  use points_str <- result.try(
    dict.get(row, "points") |> result.map_error(fn(_) { "Missing points" }),
  )
  use multiplier_str <- result.try(
    dict.get(row, "multiplier")
    |> result.map_error(fn(_) { "Missing multiplier" }),
  )
  use doubles_count_str <- result.try(
    dict.get(row, "doubles_count")
    |> result.map_error(fn(_) { "Missing doubles_count" }),
  )

  use points <- result.try(
    int.parse(points_str) |> result.map_error(fn(_) { "Invalid points" }),
  )
  use multiplier <- result.try(
    int.parse(multiplier_str)
    |> result.map_error(fn(_) { "Invalid multiplier" }),
  )
  use doubles_count <- result.try(
    int.parse(doubles_count_str)
    |> result.map_error(fn(_) { "Invalid doubles_count" }),
  )

  Ok(TestCase(
    id: id,
    description: description,
    items: items,
    status: status,
    doubles: doubles,
    is_winner: is_winner_str == "true",
    is_east: is_east_str == "true",
    expected_points: points,
    expected_multiplier: multiplier,
    expected_doubles_count: doubles_count,
  ))
}

/// Load and run all tests from CSV file
pub fn run_csv_tests() -> Result(#(Int, Int), String) {
  // Read the CSV file
  use csv_content <- result.try(
    simplifile.read("test/cases/scoring.csv")
    |> result.map_error(fn(_) { "Failed to read test/cases/scoring.csv" }),
  )

  // Parse CSV with headers
  use rows <- result.try(
    gsv.to_dicts(csv_content, ",")
    |> result.map_error(fn(_) { "Failed to parse CSV" }),
  )

  // Parse and run each test case
  let results =
    list.map(rows, fn(row) {
      case parse_row(row) {
        Ok(test_case) -> {
          case execute_case(test_case) {
            Ok(Nil) -> #(test_case.id, Ok(Nil))
            Error(e) -> #(test_case.id, Error(e))
          }
        }
        Error(e) -> #("unknown", Error("Parse error: " <> e))
      }
    })

  // Count results
  let passed =
    list.count(results, fn(r) {
      case r.1 {
        Ok(_) -> True
        Error(_) -> False
      }
    })
  let failed = list.length(results) - passed

  // Print failures
  list.each(results, fn(r) {
    case r.1 {
      Ok(_) -> Nil
      Error(e) -> io.println("FAIL [" <> r.0 <> "]: " <> e)
    }
  })

  Ok(#(passed, failed))
}

/// Test entry point - gleeunit will run this
pub fn csv_harness_test() {
  case run_csv_tests() {
    Ok(#(passed, failed)) -> {
      io.println(
        "CSV tests: "
        <> int.to_string(passed)
        <> " passed, "
        <> int.to_string(failed)
        <> " failed",
      )
      case failed {
        0 -> Nil
        _ -> panic as "Some CSV tests failed"
      }
    }
    Error(e) -> {
      io.println("Error running CSV tests: " <> e)
      panic as e
    }
  }
}
