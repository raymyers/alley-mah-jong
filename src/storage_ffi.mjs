import { Some, None } from "../gleam_stdlib/gleam/option.mjs";

export function getItem(key) {
  try {
    const value = localStorage.getItem(key);
    if (value === null) {
      return new None();
    }
    return new Some(value);
  } catch (e) {
    // localStorage might not be available (e.g., in tests or private browsing)
    return new None();
  }
}

export function setItem(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch (e) {
    // Ignore errors (quota exceeded, private browsing, etc.)
  }
}

export function removeItem(key) {
  try {
    localStorage.removeItem(key);
  } catch (e) {
    // Ignore errors
  }
}
