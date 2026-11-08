-- Configuration légère pour éditer des fichiers système et des messages de
-- commit : aucun plugin, uniquement des réglages de nvim (≥ 0.11).

-- Confort d'édition
vim.o.number = true
vim.o.ignorecase = true -- recherche insensible à la casse…
vim.o.smartcase = true -- …sauf si le motif contient une majuscule
vim.o.undofile = true -- annulations conservées après fermeture du fichier
vim.o.scrolloff = 8 -- le curseur ne colle jamais au bord de l'écran
vim.o.breakindent = true -- les lignes repliées gardent leur indentation

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight yanked text',
  callback = function() vim.hl.on_yank() end,
})

-- Tabulations, espaces en fin de ligne et espaces insécables visibles
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Barre d'état : fichier, modifié / lecture seule, type, position
function _G.status_flags()
  local flags = ''
  if vim.bo.modified then flags = flags .. ' [modified]' end
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.readonly or (vim.bo.buftype == '' and vim.fn.filereadable(file) == 1 and vim.fn.filewritable(file) == 0) then
    flags = flags .. ' %#WarningMsg#[read-only]%*'
  end
  return flags
end
vim.o.statusline = ' %f%{%v:lua.status_flags()%}%= %y  %l:%c  %P '

-- Presse-papiers du système pour y, d, p… : wl-copy / xclip en local, le
-- tampon tmux dans tmux, et en SSH hors tmux, le terminal (OSC 52)
vim.schedule(function()
  if vim.env.SSH_TTY and not vim.env.TMUX then
    local osc52 = require('vim.ui.clipboard.osc52')
    -- Lire le presse-papiers par OSC 52 est rarement autorisé : coller
    -- reprend le dernier texte copié dans nvim
    local function paste() return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } end
    vim.g.clipboard = {
      name = 'OSC 52',
      copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
      paste = { ['+'] = paste, ['*'] = paste },
    }
  end
  vim.o.clipboard = 'unnamedplus'
end)

-- :W enregistre avec sudo un fichier ouvert sans les droits d'écriture
-- (« :w !sudo tee % » de vim ne fonctionne pas dans nvim : sudo ne peut pas y
-- demander le mot de passe)
vim.api.nvim_create_user_command('W', function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('Buffer has no file name', vim.log.levels.ERROR)
    return
  end
  local password = ''
  vim.fn.system({ 'sudo', '-n', 'true' })
  if vim.v.shell_error ~= 0 then
    password = vim.fn.inputsecret('sudo password: ')
    if password == '' then return end
  end
  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), tmp)
  -- cat > : le fichier garde son propriétaire et ses droits
  local out = vim.fn.system({ 'sudo', '-S', '-p', '', 'sh', '-c', 'cat "$1" > "$2"', 'sh', tmp, file }, password .. '\n')
  local ok = vim.v.shell_error == 0
  os.remove(tmp)
  if not ok then
    vim.notify('Write failed: ' .. vim.trim(out), vim.log.levels.ERROR)
    return
  end
  vim.cmd('silent edit!') -- recharger sans avertissement « fichier modifié »
  vim.notify('Written with sudo: ' .. file)
end, { desc = 'Write the file with sudo' })

-- Messages de commit : repères à 50 (titre) et 72 colonnes (corps), retour à
-- la ligne automatique à 72
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'gitcommit',
  callback = function()
    vim.opt_local.textwidth = 72
    vim.opt_local.colorcolumn = '51,73'
  end,
})
