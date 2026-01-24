# Agent Instructions

This is a Gleam web application using Lustre for the UI.

## Tech Stack

- **Language**: Gleam (targeting JavaScript)
- **UI Framework**: Lustre
- **Styling**: Inline CSS via `styles()` function

## Commands

```sh
gleam run -m lustre/dev start  # Start dev server with hot reload
gleam run -m lustre/dev build  # Build static site to dist/
gleam test                     # Run tests
```

## Project Structure

- `src/alley_mah_jong.gleam` - UI layer (Lustre views, styles)
- `src/engine.gleam` - Pure game logic (scoring, doubles, hand status)
- `src/storage.gleam` - localStorage persistence
- `test/doubles_test.gleam` - Unit tests for engine
- `test/storage_test.gleam` - Unit tests for serialization
- `test/csv_harness.gleam` - CSV-driven test harness
- `test/cases/scoring.csv` - Test cases for scoring scenarios
- `docs/NOTATION.md` - Notation reference for test data
- `docs/SPEC.md` - Game rules specification
