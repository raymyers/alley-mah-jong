#!/usr/bin/env node
// Playwright script to capture screenshots of the app for the README.
// Usage: node screenshots.mjs
// Prerequisites: npx playwright install chromium

import { chromium } from "playwright";
import { spawn } from "child_process";

const PORT = 1234;
const BASE_URL = `http://localhost:${PORT}`;
const STORAGE_KEY = "alley_mah_jong_game";

// Sample game state with 3 completed rounds and varied hands
const sampleGame = {
  starting_score: 3550,
  names: ["Alice", "Bob", "Carol", "Dave"],
  editing_round: null,
  rounds: [
    {
      east_wind: "Player1",
      prevailing_wind: "East",
      winner: "Player1",
      hands: [
        // Alice (winner): clean hand with honors pungs and a kong
        ["PungHonors", "PungHidden", "Pung", "Kong", "BonusPairDragon"],
        // Bob
        ["Pung", "PungHonors", "BonusFlower"],
        // Carol
        ["Pung", "Pung", "BonusFlower", "BonusFlower"],
        // Dave
        ["PungHidden", "Pung"],
      ],
      doubles: [
        { is_clean: true, has_dragon_pung_or_kong: true, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: true, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
      ],
      hand_statuses: ["Clean", "Dirty", "Dirty", "Dirty"],
    },
    {
      east_wind: "Player2",
      prevailing_wind: "East",
      winner: "Player3",
      hands: [
        // Alice
        ["Pung", "Pung", "BonusFlower"],
        // Bob
        ["PungHonors", "Kong", "Pung"],
        // Carol (winner): clean with own wind
        ["PungHonorsHidden", "PungHidden", "Pung", "Pung", "BonusPairWind"],
        // Dave
        ["Pung", "BonusFlower", "BonusFlower"],
      ],
      doubles: [
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: true, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: true, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: false, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
      ],
      hand_statuses: ["Dirty", "Dirty", "Clean", "Dirty"],
    },
    {
      east_wind: "Player3",
      prevailing_wind: "South",
      winner: "Player4",
      hands: [
        // Alice: clean hand
        ["Pung", "PungHonors", "BonusFlower"],
        // Bob: clean hand
        ["Pung", "Pung", "BonusPairDragon"],
        // Carol (east): clean hand
        ["PungHidden", "Pung", "Pung", "BonusFlower"],
        // Dave (winner): clean with dragon pung + flowers
        ["KongHonorsHidden", "PungHidden", "Pung", "BonusPairDragon", "BonusFlower", "BonusFlower"],
      ],
      doubles: [
        { is_clean: true, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: true, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: true, has_dragon_pung_or_kong: false, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: false, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
        { is_clean: true, has_dragon_pung_or_kong: true, has_own_wind_pung_or_kong: false, has_prevailing_wind_pung_or_kong: false, has_both_own_flowers: true, is_east_wind: false, has_all_red_flowers: false, has_all_blue_flowers: false, is_clean_no_winds_or_dragons: false },
      ],
      hand_statuses: ["Clean", "Clean", "Clean", "Clean"],
    },
  ],
};

async function waitForServer(url, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const resp = await fetch(url);
      if (resp.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Server at ${url} did not start within ${timeoutMs}ms`);
}

async function main() {
  // Start dev server
  console.log("Starting dev server...");
  const server = spawn("gleam", ["run", "-m", "lustre/dev", "start"], {
    cwd: process.cwd(),
    stdio: "pipe",
  });
  server.stderr.on("data", (d) => {
    const msg = d.toString();
    if (!msg.includes("Downloading")) process.stderr.write(msg);
  });

  try {
    await waitForServer(BASE_URL);
    console.log("Dev server ready.");

    const browser = await chromium.launch();
    const context = await browser.newContext({
      viewport: { width: 900, height: 800 },
      deviceScaleFactor: 2,
    });
    const page = await context.newPage();

    // Inject game state before navigating
    await context.addInitScript((data) => {
      localStorage.setItem(data.key, JSON.stringify(data.value));
    }, { key: STORAGE_KEY, value: sampleGame });

    // Navigate and wait for app to render
    await page.goto(BASE_URL);
    await page.waitForSelector("#app");
    // Give Lustre a moment to hydrate with the localStorage state
    await page.waitForTimeout(500);

    // Screenshot game summary
    const appHandle = await page.$("#app");
    await appHandle.screenshot({ path: "assets/screenshot-game.png" });
    console.log("Saved assets/screenshot-game.png");

    // Click into round 2 (the second round) to capture round editor
    // Rounds are displayed as clickable elements - find the round buttons/links
    const roundLinks = await page.$$("text=/Round/");
    if (roundLinks.length >= 2) {
      await roundLinks[1].click();
    } else {
      // Fallback: click first round link
      await roundLinks[0]?.click();
    }
    await page.waitForTimeout(500);

    await page.screenshot({ path: "assets/screenshot-round.png", fullPage: true });
    console.log("Saved assets/screenshot-round.png");

    await browser.close();
    console.log("Done!");
  } finally {
    server.kill();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
