return {
  -- disable competing starters
  { "goolord/alpha-nvim", enabled = false },
  { "nvim-mini/mini.starter", enabled = false },
  { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    opts = {
      theme = "doom",
      config = {
        vertical_center = true,
        header = {
          "",
          "",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣤⣤⣤⣤⣤⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⠁⠀⠀⠀⠀⠀⠀⠀",
          " ⠀⠀⠀⠀⠀⠠⣾⡀⠀⠀⠀⠀⠀⠐⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⡀⠀⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠈⠻⣄⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣤⣤⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆",
          " ⠀⣀⣀⡀⠀⠀⢀⣀⡀⠀⣈⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢿⣿⣿⠿⠟⠛⠀⠀",
          " ⠀⢘⢿⣿⣦⠀⠀⢹⠀⠀⢸⣿⡏⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀",
          " ⠀⢸⠀⠙⢿⣷⣄⢸⠀⠀⢸⣿⡧⣴⡏⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀",
          " ⠀⢸⠀⠀⠀⠹⣿⣿⠀⠀⢸⣿⡇⠈⠃⠀⡌⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀",
          " ⠀⠼⠦⠀⠀⠀⠈⠻⠀⠠⠼⠿⠷⠤⠶⠾⠃⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢶⣶⠒⠒⢶⣦⡀⠐⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠀⠀⣸⣿⠇⠀⠘⣿⣿⠻⣿⣿⣿⣿⣿⣿⣇⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠉⢿⣿⣅⠀⠀⠀⠘⣿⣧⡸⠻⣿⣿⣿⣿⡟⠀⠀",
          " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⡀⠀⠹⣿⣦⡀⠀⠀⠹⡿⠁⠀⠈⠻⣿⣿⡏⠀⠀",
          "⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⠀⠀",
          "⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀",
          "",
          "   MAGI SYSTEM  //  AUTHORIZED PERSONNEL ONLY",
          "",
        },
        center = {
          { icon = "  ", desc = "New File", key = "n", action = "enew" },
          { icon = "  ", desc = "Find File", key = "f", action = "Telescope find_files" },
          { icon = "  ", desc = "Recent Files", key = "r", action = "Telescope oldfiles" },
          { icon = "  ", desc = "Find Word", key = "g", action = "Telescope live_grep" },
          { icon = "  ", desc = "Config", key = "c", action = "e ~/.config/nvim/lua/plugins/" },
          { icon = "󰒲  ", desc = "Lazy", key = "l", action = "Lazy" },
          { icon = "  ", desc = "Quit", key = "q", action = "qa" },
        },
        footer = {
          "",
          "GOD'S IN HIS HEAVEN. ALL'S RIGHT WITH THE WORLD.",
        },
      },
    },
    config = function(_, opts)
      require("dashboard").setup(opts)
      vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#cc0000" })
      vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#333333" })
      vim.api.nvim_set_hl(0, "DashboardIcon", { fg = "#cc0000" })
      vim.api.nvim_set_hl(0, "DashboardDesc", { fg = "#eeeeee" })
      vim.api.nvim_set_hl(0, "DashboardKey", { fg = "#ffbf00" })
    end,
  },
}
