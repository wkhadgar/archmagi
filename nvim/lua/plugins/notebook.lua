local host_python = vim.env.HOME .. "/.local/share/nvim/venv/bin/python"

if vim.fn.executable(host_python) == 1 then
  vim.g.python3_host_prog = host_python
end

local function upward_venvs(start)
  local found = {}
  local directory = start

  while directory and directory ~= "/" do
    for _, name in ipairs({ ".venv", "venv" }) do
      local candidate = directory .. "/" .. name
      if vim.fn.executable(candidate .. "/bin/python") == 1 then
        table.insert(found, candidate)
      end
    end
    directory = vim.fn.fnamemodify(directory, ":h")
  end

  return found
end

local function venv_candidates()
  local candidates = {}
  local seen = {}

  local function add(path)
    if path and path ~= "" and not seen[path] then
      seen[path] = true
      table.insert(candidates, path)
    end
  end

  add(vim.env.VIRTUAL_ENV)
  for _, path in ipairs(upward_venvs(vim.fn.expand("%:p:h"))) do
    add(path)
  end

  return candidates
end

local function kernel_name(venv)
  return vim.fn.fnamemodify(venv, ":h:t")
end

local function ensure_kernel(venv)
  local name = kernel_name(venv)
  local installed = vim.fn.stdpath("data"):gsub("/nvim$", "") .. "/jupyter/kernels/" .. name .. "/kernel.json"

  if vim.fn.filereadable(installed) == 1 then
    return name
  end

  local result = vim.system({
    venv .. "/bin/python", "-m", "ipykernel", "install",
    "--user", "--name", name, "--display-name", name,
  }, { text = true }):wait()

  if result.code ~= 0 then
    vim.notify(
      "falha ao registrar o kernel " .. name .. ", ipykernel instalado no venv?\n" .. (result.stderr or ""),
      vim.log.levels.ERROR
    )
    return nil
  end

  vim.notify("kernel registrado: " .. name)
  return name
end

local function select_kernel()
  local candidates = venv_candidates()

  if #candidates == 0 then
    vim.notify("nenhum venv encontrado no diretorio nem ativado", vim.log.levels.WARN)
    return
  end

  vim.ui.select(candidates, { prompt = "venv para este notebook" }, function(choice)
    if not choice then
      return
    end

    local name = ensure_kernel(choice)
    if name then
      vim.cmd("MoltenInit " .. name)
    end
  end)
end

vim.api.nvim_create_user_command("NotebookKernel", select_kernel, {})

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.ipynb",
  callback = function()
    vim.defer_fn(select_kernel, 200)
  end,
})

return {
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      style = "markdown",
      output_extension = "md",
      force_ft = "markdown",
    },
  },
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_text_output = true
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
    end,
    keys = {
      { "<localleader>mi", "<cmd>NotebookKernel<cr>", desc = "molten: escolher venv e iniciar" },
      { "<localleader>me", "<cmd>MoltenEvaluateOperator<cr>", desc = "molten: avaliar operador" },
      { "<localleader>ml", "<cmd>MoltenEvaluateLine<cr>", desc = "molten: avaliar linha" },
      { "<localleader>mr", "<cmd>MoltenReevaluateCell<cr>", desc = "molten: reavaliar celula" },
      { "<localleader>mo", "<cmd>MoltenShowOutput<cr>", desc = "molten: mostrar saida" },
      { "<localleader>mh", "<cmd>MoltenHideOutput<cr>", desc = "molten: esconder saida" },
      { "<localleader>md", "<cmd>MoltenDelete<cr>", desc = "molten: apagar celula" },
      { "<localleader>me", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "molten: avaliar selecao" },
    },
  },
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
    opts = {
      lspFeatures = {
        languages = { "python" },
        chunks = "all",
      },
      codeRunner = {
        enabled = true,
        default_method = "molten",
        ft_runners = { python = "molten" },
      },
    },
    keys = {
      { "<localleader>qr", "<cmd>QuartoSendAbove<cr>", desc = "quarto: rodar ate o cursor" },
      { "<localleader>qa", "<cmd>QuartoSendAll<cr>", desc = "quarto: rodar tudo" },
      { "<localleader>qc", "<cmd>QuartoSend<cr>", desc = "quarto: rodar celula" },
    },
  },
}
