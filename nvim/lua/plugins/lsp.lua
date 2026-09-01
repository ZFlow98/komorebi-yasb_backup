return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          enabled = true, -- 重新開啟 clangd
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            -- 【核心救援參數】允許 clangd 向 g++ 查詢隱式 include 目錄
            "--query-driver=C:/MinGW/bin/g++.exe,g++,*g++*",
          },
        },
      },
    },
  },
}
