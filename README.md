# ForeverChatCopy

A lightweight, zero-taint World of Warcraft addon built for **World of Warcraft: Forever** (`Interface: 16001` / `16000`, `camelot` game type) with one focused purpose:

1. **Open any chat frame in a new window to copy text.**
2. **Make links posted in chat clickable** (both directly in chat and inside the Copy Window).

## Features

- **Chat Copy Window (`ForeverChatCopyFrame`)**
  - Movable and resizable popup window containing a scrollable multi-line text box.
  - **Mode: Copy Text** (default): Unwraps hyperlinks so you can drag-select any text, URL, player name, or message and press `Ctrl+C` (or `Cmd+C` on macOS). Includes a one-click **Select All** button.
  - **Mode: Click Links**: Keeps links interactive inside the copy window so you can click URLs or hover/click game links (items, spells, quests, achievements).
  - **Colors: ON / OFF**: Toggle between preserving chat colors or stripping color codes for plain-text copying.
  - **Refresh**: Re-reads the latest lines from the active chat frame.
- **Clickable Links in Chat**
  - Automatically detects web links (`https://...`, `http://...`, `www....`, `discord.gg/...`, `wowhead.com/...`, `wago.io/...`, etc.) in incoming chat messages without corrupting existing WoW item/spell/player links or false-matching numbers like `5.5k` or patch versions like `1.60.1`.
  - Clicking a URL opens a pre-highlighted quick-copy popup (`Ctrl+C` / `Cmd+C` to copy, `Esc` or `Enter` to close).
  - `Shift + Click` on a URL inserts it into an active chat input box if one is open.

## Installation

Copy the `ForeverChatCopy` folder into your World of Warcraft Forever AddOns directory:

- **macOS:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/ForeverChatCopy` (or `_classic_era_` if applicable)
- **Windows:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverChatCopy`

Ensure the folder contains:
- `ForeverChatCopy.toc`
- `ForeverChatCopy.lua`

Restart the client or run `/reload` in-game.

## Controls & Slash Commands

- **Copy Button:** Click the small note button in the top-right corner of any chat frame:
  - **Left-Click:** Open or toggle the Chat Copy Window.
  - **Right-Click:** Open the Chat Copy Window directly in **Click Links** mode.
- **Chat Tab Shortcut:** `Shift + Left-Click` any chat tab (including the Combat Log or whisper tabs) to open its contents in the Chat Copy Window.
- **Slash Commands:** `/cc`, `/chatcopy`, or `/copychat` opens the Chat Copy Window for the currently active chat tab.
