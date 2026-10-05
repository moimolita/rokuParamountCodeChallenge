# Movie Search — Roku Channel

A Roku channel that searches movies via the [OMDb API](https://www.omdbapi.com),
browses paginated results in a grid, shows movie details, and plays a sample HLS
video. Built with BrightScript + SceneGraph.

## Features

- **Search** with an on-screen keyboard and incremental (debounced) search.
- **Scrollable, paginated grid** — results load automatically as you scroll
  (infinite scroll, appended smoothly without losing focus).
- **Detail pane** that updates as you move focus across the grid.
- **Details screen** with a large poster, title, year, rating, and full plot
  (plot/rating fetched lazily per movie).
- **Video playback** of a sample HLS stream (Big Buck Bunny).
- **Graceful error handling** — network errors (with request timeout) show a modal;
  empty results show an inline message.
- **Efficient images** — posters are requested at the size each context needs
  (small in the grid, medium in the detail pane, large on the details screen).

## Requirements

- A Roku device in **Developer Mode**
  ([how to enable](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md)).
- The device and your computer on the **same local network**.
- An OMDb API key — one is already included for evaluation (`5f57a942`). It lives in
  `source/constants.brs` (`OMDB_API_KEY`); replace it there if you hit the daily
  request limit.

## Sideload & Run

### Option A — VS Code (BrightScript extension)

1. Install the **BrightScript Language** extension (RokuCommunity) in VS Code.
2. Open this project folder in VS Code.
3. Edit `.vscode/launch.json` and set:
   - `host` — your Roku's IP (Settings → Network → About).
   - `password` — your Roku's Developer Mode password.
4. Press **F5** to build, sideload, and launch the channel.

### Option B — Manual sideload (ZIP upload)

1. Create a ZIP of the project **contents** (not the parent folder). The ZIP must
   contain `manifest`, `source/`, `components/`, and `images/` at its root:
   ```
   zip -r channel.zip manifest source components images
   ```
2. In a browser, go to `http://<ROKU_IP>` (the Development Application Installer).
3. Sign in with your Developer Mode username/password.
4. Upload `channel.zip` and click **Install**. The channel launches automatically.

## Using the Channel

- The channel opens with a default search ("batman") so the grid is populated.
- Move focus to the keyboard (**left**) to type; results update as you type
  (minimum 3 characters — OMDb's requirement).
- Press **right** to move focus from the keyboard into the grid.
- Navigate the grid with the D-pad; the detail pane (right) updates on each move.
- Scroll toward the end of the grid to auto-load more results.
- Press **OK** on a movie to open its details screen.
- On details, press **OK** (or the remote's Play key) to play the sample video.
- Press **Back** to return (details → search, or exit the video).

## Project Structure

```
manifest                       Channel metadata
source/
  main.brs                     App entry point + message loop
  constants.brs                App constants (OMDb config, poster sizes, tuning)
  utils.brs                    Pure helpers (poster URL sizing)
  mock_data.brs                Offline mock data source (not wired in; dev aid)
components/
  home_scene.xml/.brs          Root scene — navigation orchestrator
  screens/
    search_screen.xml/.brs     Keyboard + grid + detail pane
    details_screen.xml/.brs    Large poster + metadata + Play
  components/
    movie_card.xml/.brs        Custom grid item (observer + binding + lifecycle)
  tasks/
    search_task.xml/.brs       Async OMDb search (?s=) with timeout
    detail_task.xml/.brs       Async OMDb detail (?i=) for plot/rating
  models/
    movie_item.xml             ContentNode data model
images/                        Icons, splash, poster placeholder
```

## Technical Notes

- **Separation of concerns** — network/data lives in Task nodes, UI in screens, data
  in a ContentNode model (`movie_item`). Screens never make HTTP calls directly.
- **Async networking** — all OMDb requests run in Task nodes off the render thread;
  results return via interface fields observed on the UI thread.
- **Two Task variants (intentional)** — `search_task` uses an async GET with an
  explicit timeout (robust against a hung connection); `detail_task` uses a simple
  blocking GET (compact, used where a timeout is less critical).
- **Observer scope** — grid item renderers (`movie_card`) use `observeFieldScoped`
  since they are recycled on scroll; permanent screens use plain `observeField`.
- **Performance** — posters are fetched at the size each surface needs (grid 200px,
  detail pane 300px, details 514px) to limit bandwidth and texture memory; the grid
  appends new pages instead of rebuilding, preserving scroll and focus.
- **One custom component** — `movie_card` demonstrates a field observer, data
  binding, and lifecycle handling.

## Notes

- Sample video is a fixed HLS stream — OMDb provides metadata, not video sources.
- The channel is designed for 1080p (FHD).
