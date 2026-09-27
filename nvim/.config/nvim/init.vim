set encoding=utf-8
set nocp " don't need arcane vi support

let mapleader = " "
let maplocalleader = " "

" [company, model]. ['github', 'gpt-4o'] loads Copilot, which starts node and
" asks macOS for the login-keychain item "copilot-language-server".
" ['xai', 'grok-4.7'] points Avante at api.x.ai with XAI_API_KEY.
" ['', ''] skips the provider.
let g:ai_driver = ['', '']
let s:ai_company = get(g:ai_driver, 0, '')

" ==============================================================================
" Vim-Plug plugin manager
" ==============================================================================


if has('nvim')
call plug#begin('~/.local/share/nvim/plugged')
else
call plug#begin('~/.vim/plugged')
end

Plug 'kassio/neoterm' " better terminal, launch with T
" Plug 'jnurmine/Zenburn'


" Smoother scrolling
Plug 'petertriho/nvim-scrollbar'

" Completion (blink.cmp) — modern replacement for nvim-cmp
" tag v1.* downloads the prebuilt fuzzy matcher binary automatically
Plug 'saghen/blink.cmp', { 'tag': 'v1.*' }
Plug 'rafamadriz/friendly-snippets'

" Quarto
Plug 'quarto-dev/quarto-nvim'
Plug 'jmbuhr/otter.nvim'
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
Plug 'luyiyun/quarto-sync.nvim'

" color codes:
Plug 'norcalli/nvim-colorizer.lua'

" DirDiff
Plug 'will133/vim-dirdiff'

" Dependency for telescope and avante
Plug 'nvim-lua/plenary.nvim'

" Further dependencies for avante
Plug 'MunifTanjim/nui.nvim'
Plug 'MeanderingProgrammer/render-markdown.nvim'
Plug 'HakonHarnes/img-clip.nvim'
if s:ai_company ==# 'github'
  Plug 'zbirenbaum/copilot.lua'
  Plug 'github/copilot.vim'
endif

" Avante
if executable('cargo')
  Plug 'yetone/avante.nvim', { 'branch': 'main', 'do': 'make' }
endif

" Telescope
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'jvgrootveld/telescope-zoxide'



""" Plugins I stopped using
"Plug 'neomake/neomake' " nvim-lspconfig takes care of most things I cared about.
"Plug 'jupyter-vim/jupyter-vim'
"Plug 'vim-airline/vim-airline' " prefer using minimal vim look
"Plug 'vim-airline/vim-airline-themes'
"Plug 'jceb/vim-orgmode'
"Plug 'tpope/vim-speeddating' " required for org-mode

call plug#end()

lua << EOF
  -- Compatibility shim for plugins that still call deprecated vim.tbl_flatten.
  if vim.fn.has('nvim-0.11') == 1 and vim.iter then
    vim.tbl_flatten = function(t)
      return vim.iter(t):flatten(math.huge):totable()
    end
  end
EOF

" ==============================================================================
" Theme related
" ==============================================================================

""" Zenburn theme
" :let g:zenburn_high_Contrast=1
" :colors zenburn

""" colorizer
if (has("termguicolors"))
  if $TERM_PROGRAM != "Apple_Terminal"
    set termguicolors
    lua require 'colorizer'.setup()
  endif
endif

" ==============================================================================
" Copilot
" ==============================================================================
" Manually authenticate using :Copilot auth
" Verify using :Copilot auth info

if s:ai_company ==# 'github'
  lua << EOF
  local ok, copilot = pcall(require, 'copilot')
  if ok then
    copilot.setup({
      panel = { enabled = true },
      suggestion = { enabled = true },
    })
  end
  EOF
endif

" ==============================================================================
" Avante
" ==============================================================================

if exists('g:plugs') && has_key(g:plugs, 'avante.nvim') && isdirectory(g:plugs['avante.nvim'].dir)
  lua << EOF
  local ai_driver = vim.g.ai_driver or {}
  local ai_company = ai_driver[1] or ''
  local ai_model = ai_driver[2] or ''
  local company_provider = {
    github = 'copilot',
    anthropic = 'claude',
    openai = 'openai',
    google = 'gemini',
    perplexity = 'perplexity',
    xai = 'xai',
  }
  local provider_module = {
    xai = 'openai',
  }
  local ai_provider = company_provider[ai_company]

  if ai_company == 'github' then
    -- Compatibility shim for Avante Copilot auth: https://github.com/yetone/avante.nvim/issues/3121
    local copilot_config_dir = vim.env.XDG_CONFIG_HOME or vim.fn.expand('~/.config')
    local copilot_dir = vim.fs.joinpath(copilot_config_dir, 'github-copilot')
    local auth_db = vim.fs.joinpath(copilot_dir, 'auth.db')
    local apps_json = vim.fs.joinpath(copilot_dir, 'apps.json')
    if vim.uv.fs_stat(auth_db) and not vim.uv.fs_stat(apps_json) and vim.fn.executable('sqlite3') == 1 then
      local token = vim.trim(vim.fn.system({ 'sqlite3', auth_db, 'SELECT CAST(token_ciphertext AS TEXT) FROM oauth_tokens LIMIT 1;' }))
      if vim.v.shell_error == 0 and token ~= '' then
        vim.fn.writefile({ vim.json.encode({ ['github.com'] = { oauth_token = token } }) }, apps_json)
      end
    end
  end

  local terminal_cell_aspect_ratio = 2
  local function avante_position()
    return vim.o.columns >= vim.o.lines * terminal_cell_aspect_ratio and 'right' or 'bottom'
  end

  -- Avante places its input beside the result in horizontal layouts.
  local AvanteSidebar = require('avante.sidebar')
  local AvanteConfig = require('avante.config')
  if not AvanteSidebar.horizontal_stack_fixed then
    local original_create_input = AvanteSidebar.create_input_container
    local original_open = AvanteSidebar.open
    local original_resize = AvanteSidebar.resize

    function AvanteSidebar:open(opts)
      AvanteConfig.windows.position = avante_position()
      self.razordot_position = AvanteConfig.windows.position
      return original_open(self, opts)
    end

    function AvanteSidebar:create_input_container()
      original_create_input(self)
      self.razordot_position = AvanteConfig.windows.position
      if self:get_layout() == 'horizontal'
        and self.containers.input
        and self.containers.input.winid
        and vim.api.nvim_win_is_valid(self.containers.input.winid)
      then
        vim.fn.win_splitmove(self.containers.input.winid, self.containers.result.winid, {
          vertical = 0,
          rightbelow = 1,
        })
        vim.api.nvim_win_set_height(self.containers.input.winid, AvanteConfig.windows.input.height)
      end
    end

    function AvanteSidebar:resize()
      local desired_position = avante_position()
      if self.razordot_position ~= desired_position then
        local input = self:get_input_value()
        AvanteConfig.windows.position = desired_position
        self:close()
        self:open({ ask = true })
        self:set_input_value(input)
        return
      end

      if self:get_layout() ~= 'horizontal' then
        local result = original_resize(self)
        if self.containers.input and self.containers.input.winid then
          vim.api.nvim_win_set_height(self.containers.input.winid, AvanteConfig.windows.input.height)
        end
        return result
      end

      self:adjust_layout()
      if self.containers.input and self.containers.input.winid then
        vim.api.nvim_win_set_height(self.containers.input.winid, AvanteConfig.windows.input.height)
      end
      self:render_result()
      self:render_input()
      self:render_selected_code()
    end

    AvanteSidebar.horizontal_stack_fixed = true
  end

  local provider_opts = { model = ai_model }
  if ai_provider == 'xai' then
    provider_opts = {
      __inherited_from = 'openai',
      endpoint = 'https://api.x.ai/v1',
      model = ai_model,
      api_key_name = 'XAI_API_KEY',
    }
  end

  local module_name = provider_module[ai_provider] or ai_provider
  if ai_provider and pcall(require, 'avante.providers.' .. module_name) then
  require('avante').setup({
      provider = ai_provider,
      providers = {
        [ai_provider] = provider_opts,
      },
      windows = {
        position = avante_position(),
        height = 40,
        ask = {
          start_insert = false,
        },
      },
      mappings = {
        ask            = '<leader>aa', -- also use it for closing the chat pane.
        new_ask        = '<leader>an',
        zen_mode       = '<leader>az',
        edit           = '<leader>ae',
        refresh        = '<leader>ar',
        focus          = '<leader>af',
        stop           = '<leader>aS',
        select_model   = '<leader>a?',
        select_history = '<leader>ah',
        toggle = {
          default    = '<leader>at',
          debug      = '<leader>ad',
          selection  = '<leader>aC',
          suggestion = '<leader>as',
          repomap    = '<leader>aR',
        },
      },
  })
  end
EOF
endif


" ==============================================================================
" Quarto
" ==============================================================================

lua << EOF
  local ok, quarto = pcall(require, 'quarto')
  if not ok then
    vim.notify('quarto.nvim not available: ' .. tostring(quarto), vim.log.levels.WARN, { title = 'init' })
    return
  end

  quarto.setup({
    lspFeatures = {
      languages = { 'python' },  -- add 'r', 'julia', 'bash' if you use them
      chunks = 'curly',
      enabled = true,
      diagnostics = {
        enabled = true,
        triggers = { 'BufWritePost' },
      },
      completion = {
        enabled = true,
      },
    },
    codeRunner = {
      enabled = false,
    },
  })

  local function quarto_clean_artifacts(root)
    root = root or vim.fn.getcwd()
    for _, pattern in ipairs({
      '/.qsync-*.html',
      '/.qsync-*.qmd',
      '/.qsync-*_files',
      '/*.quarto_ipynb*',
    }) do
      for _, path in ipairs(vim.fn.glob(root .. pattern, false, true)) do
        local flags = path:match('_files$') and 'rf' or ''
        vim.fn.delete(path, flags)
      end
    end
  end

  local function quarto_preview()
    local source_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h')
    quarto.quartoPreview()

    local ok_output, output_buf = pcall(vim.api.nvim_buf_get_var, 0, 'quartoOutputBuf')
    if ok_output then
      vim.api.nvim_create_autocmd('TermClose', {
        buffer = output_buf,
        once = true,
        callback = function()
          quarto_clean_artifacts(source_dir)
        end,
      })
    end
  end

  vim.keymap.set('n', '<leader>qp', quarto_preview, { silent = true, noremap = true, desc = 'Quarto preview' })
  vim.keymap.set('n', '<leader>qP', '<cmd>QuartoClosePreview<CR>', { silent = true, noremap = true, desc = 'Quarto close preview' })
  
  vim.treesitter.language.register('markdown', 'quarto')

  local ok_qsync, qsync = pcall(require, 'quarto_sync')
  if not ok_qsync then
    vim.notify('quarto-sync.nvim not available: ' .. tostring(qsync), vim.log.levels.WARN, { title = 'init' })
    return
  end

  qsync.setup({
    port = 18787,
    quarto_cmd = 'quarto',
    open_browser = true,
    preview_mode = 'auto',       -- document, or website overlay when project.type = website
    sync_on_cursor_move = true,  -- nvim -> browser
    sync_from_browser = true,    -- browser -> nvim
    debounce_ms = 120,
  })

  local preview = require('quarto_sync.preview')
  local original_stop = preview.stop
  preview.stop = function(opts)
    local ok_stop, result = pcall(original_stop, opts)
    -- Move this after the error check to retain artifacts while debugging stop failures.
    quarto_clean_artifacts(vim.fn.getcwd())
    if not ok_stop then
      error(result)
    end
    return result
  end

  vim.api.nvim_create_user_command('QSyncCleanArtifacts', function()
    quarto_clean_artifacts()
  end, {})

  vim.keymap.set('n', '<leader>qs', '<cmd>QSyncPreview<CR>', {
    silent = true, desc = 'Quarto sync preview'
  })
  vim.keymap.set('n', '<leader>qS', '<cmd>QSyncStop<CR>', {
    silent = true, desc = 'Quarto sync stop'
  })
EOF

" ==============================================================================
" Treesitter (syntax highlighting + Quarto/otter support)
" ==============================================================================
lua << EOF
local ok, treesitter = pcall(require, 'nvim-treesitter')
if not ok then
  vim.notify('nvim-treesitter not available: ' .. tostring(treesitter), vim.log.levels.WARN, { title = 'init' })
  return
end

treesitter.setup({})

local parsers = {
  -- Quarto / markdown
  'markdown',
  'markdown_inline',
  'yaml',
  'json',
  'html',

  -- Code cells for Quarto / otter
  'python',
  -- 'r',       -- uncomment if you use it
  -- 'julia',   -- uncomment if you use it
  'bash',

  -- Neovim / config
  'lua',
  'vim',
  'vimdoc',
  'query',
}

treesitter.install(parsers)

local available_parsers = treesitter.get_available()
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local language = vim.treesitter.language.get_lang(args.match)
    if not language then return end

    local function attach()
      if not vim.api.nvim_buf_is_valid(args.buf) then return end
      if not vim.treesitter.language.add(language) then return end

      if language ~= 'latex' then
        vim.treesitter.start(args.buf, language)
      end

      if vim.treesitter.query.get(language, 'indents') then
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    if vim.list_contains(treesitter.get_installed('parsers'), language) then
      attach()
    elseif vim.list_contains(available_parsers, language) then
      treesitter.install(language):await(attach)
    else
      attach()
    end
  end,
})
EOF

" ==============================================================================
" Telescope: fuzzy finder (files, grep, buffers, LSP, zoxide, …)
" ==============================================================================

lua << EOF
local ok, telescope = pcall(require, 'telescope')
if not ok then
  vim.notify('telescope.nvim not available: ' .. tostring(telescope), vim.log.levels.WARN, { title = 'init' })
  return
end

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = 'smart_case',
    },
  },
})

-- native fzf sorter (compiled C library)
pcall(telescope.load_extension, 'fzf')

-- zoxide integration (you already install zoxide system-wide)
pcall(telescope.load_extension, 'zoxide')

local tel = require('telescope.builtin')

-- Everyday maps
vim.keymap.set('n', '<leader>ff', tel.find_files, { desc = 'TELE: Find files' })
vim.keymap.set('n', '<leader>fg', tel.live_grep,  { desc = 'TELE: Live grep' })
vim.keymap.set('n', '<leader>fb', tel.buffers,    { desc = 'TELE: Buffers' })
vim.keymap.set('n', '<leader>fh', tel.help_tags,  { desc = 'TELE: Help tags' })
vim.keymap.set('n', '<leader>fo', tel.oldfiles,   { desc = 'TELE: Recent files' })
vim.keymap.set('n', '<leader>/', function()
  tel.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
    previewer = false,
  }))
end, { desc = 'TELE: Search in buffer' })

-- zoxide
vim.keymap.set('n', '<leader>cd', require('telescope').extensions.zoxide.list, { desc = 'TELE: Zoxide' })
EOF

" ==============================================================================
" Completion + LSP (blink.cmp + vim.lsp)
" ==============================================================================
" Note: I will never use mason. An LSP should be in your PATH and you should know
" how to install an LSP yourself. Manage your dotfiles!

set completeopt=menu,menuone,noselect

lua << EOF
  ---------------------------------------------------------------
  -- blink.cmp
  ---------------------------------------------------------------
  require('blink.cmp').setup({
    keymap = { preset = 'default' },
  
    appearance = {
      nerd_font_variant = 'mono',
    },
  
    completion = {
      documentation = {
        auto_show = true,          -- your preference
        auto_show_delay_ms = 200,
      },
    },
  
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
    },
  
    snippets = {
      preset = 'default',          -- uses vim.snippet + friendly-snippets
    },
  
    fuzzy = {
      implementation = 'prefer_rust_with_warning',
    },
  })

  ---------------------------------------------------------------
  -- LSP capabilities
  ---------------------------------------------------------------
  local capabilities = require('blink.cmp').get_lsp_capabilities()

  --- This function was added, because I don't want to use mason.nvim.
  --- This simply checks if the LSP is available and if so adds it, if not writes a warning.
  ---@param name string
  ---@param cmd string[]          -- required
  ---@param capabilities table    -- required
  ---@param opts? table           -- optional extra settings
  local function add_lsp_if_available(name, cmd, capabilities, opts)
    assert(type(name) == "string" and name ~= "", "name is required")
    assert(type(cmd) == "table" and #cmd > 0, "cmd is required (non-empty table)")
    assert(type(capabilities) == "table", "capabilities is required")
  
    opts = opts or {}
    opts.cmd = cmd
    opts.capabilities = capabilities
  
    local executable = cmd[1]
  
    if vim.fn.executable(executable) == 1 then
      -- vim.lsp.configs[name] = vim.tbl_deep_extend("force", vim.lsp.configs[name] or {}, opts)
      -- vim.lsp.start_client(vim.lsp.get_client_by_name(name))
      vim.lsp.config(name, opts)
      vim.lsp.enable(name)
    else
      vim.notify(
        string.format("LSP '%s' not found on $PATH (looking for '%s'). Skipping.", name, executable),
        vim.log.levels.WARN,
        { title = "LSP" }
      )
    end
  end

  ---------------------------------------------------------------
  -- Language servers (keep the ones you already use)
  ---------------------------------------------------------------

  -- Good collection of LSPs:
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md

  add_lsp_if_available("pyright",
    { "pyright-langserver", "--stdio" },
    capabilities,
    {
      filetypes = { "python" },  -- critical: never "quarto" / "markdown"
    }
  )

  -- add_lsp_if_available("dartls",
  --  { "dart", "language-server", "--protocol=lsp" },
  --  capabilities
  -- )

  ---------------------------------------------------------------
  -- LspAttach keymaps
  ---------------------------------------------------------------
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLspConfig', { clear = true }),
    callback = function(ev)
      local opts = { buffer = ev.buf, silent = true }
      local tel = require('telescope.builtin')
  
      local function map(keys, func, desc, mode)
        mode = mode or 'n'
        local o = vim.tbl_extend('force', opts, desc and { desc = desc } or {})
        vim.keymap.set(mode, keys, func, o)
      end
  
      -- Telescope-enhanced LSP navigations
      map('grr', tel.lsp_references,                'LSP: References')
      map('gri', tel.lsp_implementations,           'LSP: Implementations')
      map('grd', tel.lsp_definitions,               'LSP: Definitions')
      map('grt', tel.lsp_type_definitions,          'LSP: Type Definitions')
      map('gO',  tel.lsp_document_symbols,          'LSP: Document Symbols')
      map('gW',  tel.lsp_dynamic_workspace_symbols, 'LSP: Workspace Symbols')
  
      -- Classic navigations
      map('gd',  tel.lsp_definitions,               'LSP: Goto Definition') -- grd
      map('<leader>D', tel.lsp_type_definitions,    'LSP: Type Definition') -- grt
      map('gD',  vim.lsp.buf.declaration,           'LSP: Goto Declaration')
  
      -- Leader actions
      map('<leader>rn', vim.lsp.buf.rename,         'LSP: Rename')
      map('<leader>ca', vim.lsp.buf.code_action,    'LSP: Code Action', { 'n', 'v' })
  
      -- Diagnostics
      map('<leader>e', vim.diagnostic.open_float,   'LSP: Show Diagnostic')
      map('<leader>q', vim.diagnostic.setloclist,   'LSP: Diagnostics → Loclist')
  
      -- Inlay hints
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }))
      end, 'LSP: Toggle Inlay Hints')
    end,
  })

  -- Slightly nicer diagnostics
  vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    -- virtual_lines = false, -- set true if you prefer lines instead of virtual text
  })
EOF


" ==================
" Config shortcuts
" ==================
" $MYVIMRC resolves to the init file for the current nvim session
nnoremap <leader>ev :split $MYVIMRC<CR>
lua vim.keymap.set('n', '<leader>qq', function() local f = vim.fn.getcwd() .. '/_quarto.yml'; if vim.fn.filereadable(f) == 1 then vim.cmd('split ' .. f) else vim.notify('_quarto.yml not found', vim.log.levels.WARN) end end, { desc = 'Open _quarto.yml' })

" ====================
" My custom functions
" ====================

""" Tamarin source code (for .spthy and .sapic)
augroup filetypedetect
au BufNewFile,BufRead *.spthy	setf spthy
au BufNewFile,BufRead *.sapic	setf sapic
augroup END

"" Old file executions, ran with Shift+R
"autocmd FileType python map <buffer> <S-r> :w<CR>:exec 'w !python3' shellescape(@%, 1)<CR>
"autocmd FileType cpp map <buffer> <S-r> :w<CR>:exec 'w !g++ -std=c++17 -Wall -Wextra -g3 -ggdb3 -fsanitize=address ' shellescape(@%, 1) ';./a.out' <CR>

" Trim Whitespace at the end of the line.
fun! TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun
command! TrimWhitespace call TrimWhitespace()

" Fzf plugin
if has('macunix')
  set rtp+=/opt/homebrew/opt/fzf
else
  set rtp+=/usr/local/opt/fzf
endif

if s:ai_company ==# 'github'
  imap <silent> <C-j> <Plug>(copilot-next)
  imap <silent> <C-k> <Plug>(copilot-previous)
endif

""" Custom commands
command! ErrorRegex execute "/\\v\([a-zA-Z_-]\)\@<!\(error\|missing\|unknown\|except\|not found\|fail\|unavailable\|issue\|problem\|fault\|invalid\|code 1\|crash(\\%(!lytics))\)"



" =================
" General settings
" =================
syntax on
set ignorecase
set hidden " hide buffers instead of closing them.
"set nu " set rnu for relative numbering.
set list
set ruler
set smartcase " sets case sensitivity if there is a capital letter
" If you still want to search without case sensitivity, do "\C" before the search.
set showbreak=↪\
set listchars=tab:↦-,nbsp:␣,trail:∙,extends:⟩,precedes:⟨
set autoindent tabstop=4 softtabstop=0 shiftwidth=4 expandtab
set splitbelow  "move preview window to below, so it doesn't move the code
nnoremap <F6> yiw:%s/\<<C-r>"\>/<C-r>"/gc<Left><Left><Left>
vnoremap <F6> y:%s/\<<C-r>"\>/<C-r>"/gc<Left><Left><Left>
" delete the black hole register: https://vim.fandom.com/wiki/Replace_a_word_with_yanked_text
" so i can use vi"p
xnoremap <silent> p p:let @+=@0<CR>:let @"=@0<CR>
" repeat last macro
nnoremap Q @@
if has('nvim')
    set inccommand=nosplit
endif
set mouse=a " for mouse to work in tmux and vim



" =============
" Learning Vim
" =============
" ---
" BUFFERS
" use buffers when navigating code in the same context.
" when closing vim only unsaved buffers will block you from quitting
" for example when looking up a definition using gd, gD, \ti, \ti
" :bp :bn buffer previous/next

" TAB PAGES
" gt gT 3gt to switch between tabs
" :tabn :tabp to switch between tabs
" :tabs
" spread buffers into tab pages: sball

" WINDOWS
" :vsplit and :split
" <c-w><c-w> to switch between windows
" spread buffers into windows :vertical ball 
" VIMGREP
" :vimgrep /DistributionStatus/g %:h/**
" use :cnext :cprevious :clist or :lnext :lprevious :llist for :lvimgrep
