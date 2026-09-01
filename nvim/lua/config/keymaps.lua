local keymap = vim.keymap

-- 是否為 Windows (git bash 內執行 nvim 時, vim.fn.has("win32") 仍為 1)
local is_windows = vim.fn.has("win32") == 1
local exe_ext = is_windows and ".exe" or ""

-- 統一把 Windows 反斜線路徑轉成正斜線
local function unixpath(p)
  return (p:gsub("\\", "/"))
end

-- 處理可執行檔路徑前綴
local function to_exec(p)
  if p:match("^%a:/") or p:match("^/") then
    return p
  else
    return "./" .. p
  end
end

-- 記住上次開的 terminal 視窗與 buffer，避免重複疊加視窗或覆蓋主程式碼視窗
local term_win = nil
local term_buf = nil

local function run_in_terminal(cmd)
  -- 1. 如果舊的 Terminal Buffer 還存在，強制關閉並清理（同時自動強刪未結束的 job）
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    vim.api.nvim_buf_delete(term_buf, { force = true })
  end

  -- 2. 檢查舊視窗是否還有效，無效才開新的 split 視窗
  if not (term_win and vim.api.nvim_win_is_valid(term_win)) then
    vim.cmd("botright split")
    vim.cmd("resize 15")
    term_win = vim.api.nvim_get_current_win()
  else
    -- 如果視窗還在，將焦點切換至下方的 terminal 視窗
    vim.api.nvim_set_current_win(term_win)
  end

  -- 3. 在下方視窗建立全新的 buffer 並執行 terminal 指令
  vim.cmd("enew")
  term_buf = vim.api.nvim_get_current_buf()

  vim.fn.termopen({ "bash", "-lc", cmd })
  vim.cmd("startinsert")
end

-- 各語言的編譯/執行指令產生器
local runners = {
  -- 全套 GNU 工具鏈 (gcc), 警告全開
  c = function(file, root, out)
    local flags = table.concat({
      "-std=c17",
      "-O2 -g",
      "-Wall -Wextra -Wpedantic",
      "-Wshadow",
      "-Wconversion -Wsign-conversion",
      "-Wcast-align -Wcast-qual",
      "-Wnull-dereference",
      "-Wdouble-promotion",
      "-Wformat=2",
      "-Wundef",
      "-Wswitch-enum",
      "-static-libgcc",
    }, " ")
    local bin = out .. exe_ext
    return string.format('gcc %s "%s" -o "%s" && "%s"', flags, file, bin, to_exec(bin))
  end,

  -- 全套 GNU 工具鏈 (g++), C++17, 警告全開
  cpp = function(file, root, out)
    local flags = table.concat({
      "-std=c++17",
      "-O2 -g",
      "-Wall -Wextra -Wpedantic",
      "-Wshadow",
      "-Wconversion -Wsign-conversion",
      "-Wnon-virtual-dtor",
      "-Wold-style-cast",
      "-Wcast-align -Wcast-qual",
      "-Woverloaded-virtual",
      "-Wnull-dereference",
      "-Wdouble-promotion",
      "-Wformat=2",
      "-Wundef",
      "-Wuseless-cast",
      "-Wlogical-op",
      "-Wduplicated-cond",
      "-Wduplicated-branches",
      "-static-libgcc -static-libstdc++",
    }, " ")
    local bin = out .. exe_ext
    return string.format('g++ %s "%s" -o "%s" && "%s"', flags, file, bin, to_exec(bin))
  end,

  rust = function(file, root, out)
    if vim.fn.filereadable("Cargo.toml") == 1 then
      return "cargo run"
    end
    local bin = out .. exe_ext
    return string.format('rustc "%s" -o "%s" && "%s"', file, bin, to_exec(bin))
  end,

  python = function(file, root, out)
    if vim.fn.executable("python3.14") == 1 then
      return string.format('python3.14 "%s"', file)
    elseif vim.fn.executable("python3") == 1 then
      return string.format('python3 "%s"', file)
    else
      return string.format('python "%s"', file)
    end
  end,

  java = function(file, root, out)
    local dir = unixpath(vim.fn.expand("%:p:h"))
    local classname = vim.fn.expand("%:t:r")
    return string.format('javac -source 1.8 -target 1.8 "%s" && java -cp "%s" %s', file, dir, classname)
  end,

  go = function(file, root, out)
    return string.format('go run "%s"', file)
  end,

  javascript = function(file, root, out)
    return string.format('node "%s"', file)
  end,

  typescript = function(file, root, out)
    if vim.fn.executable("ts-node") == 1 then
      return string.format('ts-node "%s"', file)
    else
      return string.format('npx ts-node "%s"', file)
    end
  end,
}

keymap.set("n", "<F5>", function()
  vim.cmd("w") -- 先自動存檔

  local ft = vim.bo.filetype
  local file = unixpath(vim.fn.expand("%"))
  local root = unixpath(vim.fn.expand("%:r"))
  local out = root

  local runner = runners[ft]
  if not runner then
    print("尚不支援此檔案型態的 <F5> 執行：" .. ft)
    return
  end

  local cmd = runner(file, root, out)
  run_in_terminal(cmd)
end, { desc = "Compile and Run (C17 / C++17 / Rust / Python3 / Java1.8 / Go / JS / TS)" })
