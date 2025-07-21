# pdfreader.nvim

Read and navigate PDF documents **without leaving Neovim**.  
pdfreader.nvim renders PDF pages directly in the terminal (via Kitty’s graphics
protocol).
![demo](https://github.com/user-attachments/assets/5a98c65f-650b-4548-b130-ee3118ac5e86)

---

## ✨ Features

* Render PDF pages in **standard**, **dark**, or **text-only** mode.
* **Bookmarks**
* **Telescope.nvim** integration.
* Works on Mac and Linux.

## 📋 Requirements

* [Kitty terminal](https://github.com/kovidgoyal/kitty)
* [Neovim](https://github.com/neovim/neovim) ≥ 0.9
* [ImageMagick](https://github.com/ImageMagick/ImageMagick)
* [poppler-utils](https://poppler.freedesktop.org/)

If Kitty is unavailable, the plugin will automatically work in *text* mode only.

## 📦 Installation

### lazy.nvim

```lua
{
  "r-pletnev/pdfreader.nvim",
  lazy   = false,
  dependencies = {
    "folke/snacks.nvim", -- image rendering
    "nvim-telescope/telescope.nvim", -- pickers

  },
  config = function()
    require("pdfreader").setup()
  end,
}
```

## 🚀 Usage

Open a PDF as you would any file:

```vim
:e ~/docs/paper.pdf
```

### Key mappings

| Key | Action            |
|-----|-------------------|
| `n` | Next page         |
| `p` | Previous page     |
| `z` | Zoom **in**       |
| `q` | Zoom **out**      |
| `e` | Reset zoom        |

### `:PDFReader` sub-commands

| Command                                             | Description |
|-----------------------------------------------------|-------------|
| `:PDFReader setViewMode {standard, dark, text}`         | Change view mode |
| `:PDFReader setAutosave {on, off}`                     | Toggle autosave |
| `:PDFReader setPage {num}`                          | Jump to page |
| `:PDFReader addBookmark [{num}][,comment]`          | Add bookmark |
| `:PDFReader showBookmarks`                          | Telescope bookmarks picker |
| `:PDFReader showRecentBooks`                        | Telescope recent books picker |
| `:PDFReader saveState`                              | Force save state |
| `:PDFReader clearState`                             | Delete state & covers |
| `:PDFReader redrawPage`                             | Re-render current page |

Command arguments are fully tab-completable.

## 🛠 Troubleshooting

* **Blank buffer / no images** → ensure you are using Kitty and have installed ImageMagick and poppler-utils.
* Consult `:messages` for detailed logs emitted by pdfreader.nvim.

## 🤝 Contributing

Pull requests and issues are welcome!
