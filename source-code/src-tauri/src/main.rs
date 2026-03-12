// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::process::Command;
use std::fs;
use std::env;
use std::path::Path;
use serde::{Deserialize, Serialize};

fn get_home_dir() -> String {
    env::var("HOME").unwrap_or_else(|_| String::from("/home/hacker"))
}

fn get_data_dir() -> String {
    format!("{}/.hackeros/HackerDeck", get_home_dir())
}

#[derive(Serialize, Deserialize, Clone)]
struct Game {
    id: String,
    title: String,
    image: String,
    #[serde(rename = "exePath")]
    exe_path: String,
    is_favorite: bool,
    proton_version: String,
}

#[tauri::command]
fn load_games() -> Result<Vec<Game>, String> {
    let path = format!("{}/games.json", get_data_dir());
    if Path::new(&path).exists() {
        let data = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&data).map_err(|e| e.to_string())
    } else {
        Ok(vec![])
    }
}

#[tauri::command]
fn save_games(games: Vec<Game>) -> Result<(), String> {
    let dir = get_data_dir();
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let path = format!("{}/games.json", dir);
    let data = serde_json::to_string_pretty(&games).map_err(|e| e.to_string())?;
    fs::write(&path, data).map_err(|e| e.to_string())
}

#[tauri::command]
fn get_proton_versions() -> Result<Vec<String>, String> {
    let dir = format!("{}/Protons", get_data_dir());
    if !Path::new(&dir).exists() {
        return Ok(vec![]);
    }
    let mut versions = vec![];
    for entry in fs::read_dir(&dir).map_err(|e| e.to_string())? {
        if let Ok(entry) = entry {
            if entry.path().is_dir() {
                if let Some(name) = entry.file_name().to_str() {
                    versions.push(name.to_string());
                }
            }
        }
    }
    Ok(versions)
}

#[tauri::command]
fn download_proton(version_url: String, version_name: String) -> Result<String, String> {
    let proton_dir = format!("{}/Protons", get_data_dir());
    fs::create_dir_all(&proton_dir).map_err(|e| e.to_string())?;

    let tar_path = format!("{}/{}.tar.gz", proton_dir, version_name);

    let status = Command::new("wget")
    .arg("-q")
    .arg("-O")
    .arg(&tar_path)
    .arg(&version_url)
    .status()
    .map_err(|e| format!("Failed to execute wget: {}", e))?;

    if !status.success() {
        return Err("Failed to download Proton".to_string());
    }

    let status = Command::new("tar")
    .arg("-xzf")
    .arg(&tar_path)
    .arg("-C")
    .arg(&proton_dir)
    .status()
    .map_err(|e| format!("Failed to execute tar: {}", e))?;

    if !status.success() {
        return Err("Failed to extract Proton".to_string());
    }

    let _ = fs::remove_file(&tar_path);

    Ok(format!("Successfully installed {}", version_name))
}

#[tauri::command]
fn create_prefix(game_name: String, proton_version: String) -> Result<String, String> {
    let prefix_path = format!("{}/Prefix/{}", get_data_dir(), game_name.replace(" ", ""));
    fs::create_dir_all(&prefix_path).map_err(|e| e.to_string())?;

    let wine_path = format!("{}/Protons/{}/files/bin/wine", get_data_dir(), proton_version);

    let actual_wine = if Path::new(&wine_path).exists() {
        wine_path
    } else {
        "wine".to_string()
    };

    let output = Command::new(&actual_wine)
    .env("WINEPREFIX", &prefix_path)
    .arg("wineboot")
    .arg("--init")
    .output()
    .map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(format!("Prefix created at {}", prefix_path))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[tauri::command]
fn run_game(game_name: String, exe_path: String, proton_version: String) -> Result<String, String> {
    let prefix_path = format!("{}/Prefix/{}", get_data_dir(), game_name.replace(" ", ""));
    let wine_path = format!("{}/Protons/{}/files/bin/wine", get_data_dir(), proton_version);

    let actual_wine = if Path::new(&wine_path).exists() {
        wine_path
    } else {
        "wine".to_string()
    };

    Command::new(&actual_wine)
    .env("WINEPREFIX", &prefix_path)
    .arg(&exe_path)
    .spawn()
    .map_err(|e| e.to_string())?;

    Ok(format!("Game {} started", game_name))
}

#[tauri::command]
fn scan_steam_games() -> Result<Vec<Game>, String> {
    let home = get_home_dir();
    let steam_paths = vec![
        format!("{}/.steam/steam/steamapps", home),
            format!("{}/.local/share/Steam/steamapps", home),
    ];

    let mut games = vec![];

    for path in steam_paths {
        if Path::new(&path).exists() {
            if let Ok(entries) = fs::read_dir(&path) {
                for entry in entries.flatten() {
                    let file_name = entry.file_name().into_string().unwrap_or_default();
                    if file_name.starts_with("appmanifest_") && file_name.ends_with(".acf") {
                        if let Ok(content) = fs::read_to_string(entry.path()) {
                            let mut name = String::new();
                            let mut install_dir = String::new();
                            for line in content.lines() {
                                if line.contains("\"name\"") {
                                    let parts: Vec<&str> = line.split('"').collect();
                                    if parts.len() >= 4 {
                                        name = parts[3].to_string();
                                    }
                                }
                                if line.contains("\"installdir\"") {
                                    let parts: Vec<&str> = line.split('"').collect();
                                    if parts.len() >= 4 {
                                        install_dir = parts[3].to_string();
                                    }
                                }
                            }

                            if !name.is_empty() && !install_dir.is_empty() {
                                games.push(Game {
                                    id: format!("steam_{}", name.replace(" ", "")),
                                           title: name.clone(),
                                           image: format!("https://picsum.photos/seed/{}/400/600", name.replace(" ", "")),
                                           exe_path: format!("{}/common/{}", path, install_dir),
                                           is_favorite: false,
                                           proton_version: String::new(),
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(games)
}

fn main() {
    tauri::Builder::default()
    .invoke_handler(tauri::generate_handler![
        create_prefix,
        download_proton,
        run_game,
        load_games,
        save_games,
        get_proton_versions,
        scan_steam_games
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
