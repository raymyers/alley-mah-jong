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

- `src/alley_mah_jong.gleam` - Main application entry point
- `test/` - Test files
- `gleam.toml` - Project configuration
