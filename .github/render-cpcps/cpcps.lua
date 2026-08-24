-- THIS FILE IS AI GENERATED IT MAY CONTAIN ERRORS
-- ONLY PART THAT IS HANDWRITTED IS SPECIFICALLY THE LANDSCAPE PART
-- this contains support for VCS tables at the top of documents when I get to it
--
-- cpcps.lua -- pandoc filter for finalized CP/CPS PDF output (LaTeX only).
--
-- Fenced div contract for the compiled markdown:
--   ::: landscape   content is placed on landscape pages (pdflscape)
--   ::: vcs         version-control block: the heading is centered in the
--                   display font (and kept out of the ToC); a contained table
--                   with a header row renders with a navy header
--   ::: shaded      contained tables get orange shaded rows
--
-- Every table is rendered as a fully bordered longtable (the CP/CPS look, no
-- booktabs rules): header rows are navy with white bold text and repeat
-- across pages; ::: shaded tables get orange body rows.
--
-- ::: layer-N00 divs produced by brofbrs build.py are intentionally left
-- untouched so their content passes through invisibly.

local function is_latex()
  return FORMAT:match('latex') ~= nil
end

-- Serialize a list of blocks to a LaTeX string (used for table cells and the
-- version-control heading, so bullets/links/emphasis survive).
local function render_blocks(blocks)
  local ok, s = pcall(pandoc.write, pandoc.Pandoc(blocks), 'latex')
  if not ok then
    return ''
  end
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local ALIGN_CMD = {
  AlignLeft = '\\raggedright',
  AlignRight = '\\raggedleft',
  AlignCenter = '\\centering',
  AlignDefault = '\\raggedright',
}

-- Bordered longtable column spec, widths proportional to pandoc's relative
-- column widths (equal shares when pandoc left the widths at their default).
local function column_spec(tbl)
  local n = #tbl.colspecs
  local widths, total, all_set = {}, 0, true
  for i, cs in ipairs(tbl.colspecs) do
    local w = cs[2]
    if type(w) ~= 'number' or w <= 0 then
      all_set = false
    else
      widths[i] = w
      total = total + w
    end
  end
  local cols = {}
  for i, cs in ipairs(tbl.colspecs) do
    local w = (all_set and total > 0) and (widths[i] / total) or (1 / n)
    local align = ALIGN_CMD[cs[1]] or '\\raggedright'
    cols[#cols + 1] = '|>{' .. align .. '\\arraybackslash}'
      .. 'p{(\\columnwidth - ' .. (2 * n) .. '\\tabcolsep) * \\real{'
      .. string.format('%.4f', w) .. '}}'
  end
  return table.concat(cols) .. '|'
end

-- One table row. \tabularnewline is used instead of \\ so rows ending in a
-- list environment (e.g. bulleted version-control comments) still compile.
local function row_latex(row, wrap_cell)
  local cells = {}
  for _, cell in ipairs(row.cells) do
    local content = render_blocks(cell.contents)
    if wrap_cell and content ~= '' then
      content = wrap_cell(content)
    end
    cells[#cells + 1] = content
  end
  return table.concat(cells, ' & ') .. ' \\tabularnewline'
end

local function has_content(rows)
  for _, row in ipairs(rows) do
    for _, cell in ipairs(row.cells) do
      if render_blocks(cell.contents) ~= '' then
        return true
      end
    end
  end
  return false
end

local function serialize_table(tbl)
  local shaded = tbl.classes:includes('shaded-rows')
  local lines = { '\\begin{longtable}{' .. column_spec(tbl) .. '}' }

  local caption = render_blocks(tbl.caption.long or {})
  if caption ~= '' then
    lines[#lines + 1] = '\\caption{' .. caption .. '} \\tabularnewline'
  end

  -- Header rows: navy background, white bold text, repeated on every page
  if tbl.head and tbl.head.rows and has_content(tbl.head.rows) then
    for _, row in ipairs(tbl.head.rows) do
      lines[#lines + 1] = '\\hline'
      lines[#lines + 1] = '\\rowcolor{VcsBlue}'
      lines[#lines + 1] = row_latex(row, function(c)
        return '{\\color{white}\\bfseries ' .. c .. '}'
      end)
    end
    lines[#lines + 1] = '\\hline'
    lines[#lines + 1] = '\\endhead'
  end

  -- Body rows (all bodies flattened; intermediate head/foot rows kept in
  -- order, they occur neither in pipe tables nor in build.py output)
  local function body_rows(rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = '\\hline'
      if shaded then
        lines[#lines + 1] = '\\rowcolor{ShadedOrange}'
      end
      lines[#lines + 1] = row_latex(row)
    end
  end
  for _, body in ipairs(tbl.bodies) do
    body_rows(body.head or {})
    body_rows(body.body or {})
  end
  if tbl.foot and tbl.foot.rows then
    body_rows(tbl.foot.rows)
  end

  lines[#lines + 1] = '\\hline'
  lines[#lines + 1] = '\\end{longtable}'
  return pandoc.RawBlock('latex', table.concat(lines, '\n'))
end

function Table(tbl)
  if not is_latex() then
    return nil
  end
  -- On any serialization problem, fall back to pandoc's native table output
  local ok, result = pcall(serialize_table, tbl)
  if ok and result then
    return result
  end
  io.stderr:write('cpcps.lua: could not serialize a table, '
    .. 'falling back to pandoc default output\n')
  return nil
end

function Div(el)
  if not is_latex() then
    return nil
  end

	-- this is my original work here
  if el.classes:includes('landscape') then
    local blocks = { pandoc.RawBlock('latex', '\\begin{landscape}') }
    for _, b in ipairs(el.content) do
      blocks[#blocks + 1] = b
    end
    blocks[#blocks + 1] = pandoc.RawBlock('latex', '\\end{landscape}')
    return blocks
  end
	-- this is my original work here

  if el.classes:includes('vcs') then
    local out = {}
    for _, b in ipairs(el.content) do
      if b.t == 'Header' then
        -- Centered display-font heading, not a section: no page break, no
        -- ToC entry (matches the reference version-control page)
        local text = render_blocks({ pandoc.Plain(b.content) })
        out[#out + 1] = pandoc.RawBlock('latex',
          '\\par\\vspace{1.5em}\\begin{center}{\\cambriafont\\bfseries\\large '
          .. text .. '\\par}\\end{center}\\vspace{0.5em}')
      else
        out[#out + 1] = b
      end
    end
    return out
  end

  if el.classes:includes('shaded') then
    for _, b in ipairs(el.content) do
      if b.t == 'Table' then
        b.classes:insert('shaded-rows')
      end
    end
    return el
  end

  return nil
end
