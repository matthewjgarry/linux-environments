return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}

      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#f2c35f" })
      vim.api.nvim_set_hl(0, "WormlogicGreen", { fg = "#8fd46a" })
      vim.api.nvim_set_hl(0, "WormlogicGold", { fg = "#f2c35f" })

      opts.dashboard.preset.header = [[
   ░███                  ░███    
  ░██                      ░██   
  ░██                      ░██   
  ░██       ░████          ░██   
░███       ░██ ░██ ░██      ░███ 
  ░██           ░████      ░██   
  ░██                      ░██   
  ░██                      ░██   
   ░███                  ░███    
      ]]

      opts.dashboard.sections = {
        { section = "header", align = "center", padding = 2 },
        {
          text = {
            { "{", hl = "WormlogicGold" },
            { "~", hl = "WormlogicGreen" },
            { "}", hl = "WormlogicGold" },
            { " ", hl = "SnacksDashboardHeader" },
            { "worm", hl = "WormlogicGreen" },
            { "logic", hl = "WormlogicGold" },
          },
          align = "center",
          padding = 1,
        },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }
    end,
  },
}
