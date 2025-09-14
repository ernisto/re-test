local syntax_highlight = require('./syntax_highlight')

-- utils
local function back_color(c: number?)
	return `\27[10{c or 9}m`
end
local function txt_color(c: number?)
	return `\27[9{c or 9}m`
end
local function bold(str: string)
	return `\27[1m{str}\27[22m`
end
local function format_time(seconds: number): (number, string)
	if seconds < 1e-6 then
		return 2, `{seconds * 1e9 // 1}ns`
	elseif seconds < 1e-3 then
		return 3, `{seconds * 1e6 // 1}μs`
	elseif seconds < 1 then
		return 1, `{seconds * 1e3 // 1}ms`
	elseif seconds < 60 then
		return 5, `{seconds * 1 // 1}s`
	else
		return 0, `{seconds // 60}m`
	end
end

-- ANSI colors
local RESET = '\27[0m'
local BOLD = '\27[1m'
local DIM = '\27[2m'

local nerdfont = {
	bench = '\u{f13ab}',
	bench_config = '\u{f1925}',
	bench_done = '\u{f1ad0}',
	bench_refresh = '\u{f1ae4}',
	bench_bad = '\u{f1ae6}',
	bench_pause = '\u{f1ade}',
	bench_play = '\u{f1ae0}',

	test = '\u{f0668}',
	lua = '\u{f08b1}',
	skip = '⏭',
	check = '✔',
	bad = '✖',

	left_sep = '\u{e0bc}',
	right_sep = '\u{e0ba}',
	left_corner = '\u{e0b6}',
	right_corner = '\u{e0b4}',

	-- time icons
	ms = '\u{f017}',
	s = '\u{f017}',
	m = '\u{f017}',
}

local function segment_size(text: string, count: number, previous)
	return 2 + 1 + 1 + #text + 1 + #tostring(count) + (previous and 2 or 0)
end
local function segment(color: number, icon: string, count: number, text: string, size: number, prev_color: number?)
	local sep = prev_color
		and back_color() .. txt_color(prev_color) .. nerdfont.left_sep .. txt_color(color) .. nerdfont.right_sep
	local init = txt_color(color) .. nerdfont.left_corner

	return (sep or init)
		.. back_color(color)
		.. (sep and ' ' or '')
		.. BOLD
		.. `{icon} {count} {text}`
		.. string.rep(' ', size)
		.. RESET
end
local function tag(color: number, icon: string, name: string): string
	return txt_color(color)
		.. BOLD
		.. nerdfont.left_corner
		.. back_color(color)
		.. `{icon} {name}`
		.. RESET
		.. txt_color(color)
		.. back_color()
		.. nerdfont.right_corner
		.. RESET
end

local function render_bar(
	totalCount: number,
	passedCount: number,
	failedCount: number,
	skippedCount: number,
	total_time: number
)
	local width = 64
	if totalCount <= 0 then return ' ' .. DIM .. string.rep('·', width) .. RESET .. ' ' end

	width -= 1 -- final
	width -= segment_size('PASS', passedCount, false)
	width -= segment_size('FAIL', failedCount, passedCount > 0)
	width -= segment_size('SKIP', skippedCount, failedCount > 0 or passedCount > 0)

	local prev_color
	local segs = ''
	local post_bar = ''

	if passedCount > 0 then
		segs ..= segment(2, nerdfont.check, passedCount, 'PASS', width * passedCount // totalCount, prev_color)
		prev_color = 2
	else
		post_bar ..= txt_color(2) .. ` {nerdfont.check} 0 PASS `
	end

	if failedCount > 0 then
		segs ..= segment(1, nerdfont.bad, failedCount, 'FAIL', width * failedCount // totalCount, prev_color)
		prev_color = 1
	else
		post_bar ..= txt_color(1) .. ` {nerdfont.bad} 0 FAIL `
	end

	if skippedCount > 0 then
		segs ..= segment(3, nerdfont.skip, skippedCount, 'SKIP', width * skippedCount // totalCount, prev_color)
		prev_color = 3
	else
		post_bar ..= txt_color(3) .. ` {nerdfont.skip} 0 SKIP `
	end

	local time_color, time = format_time(total_time)

	post_bar ..= txt_color(4) .. ` {nerdfont.test} {totalCount} TEST `
	post_bar ..= txt_color(time_color) .. ` {nerdfont.bench} {time} `

	return segs .. back_color() .. txt_color(prev_color) .. nerdfont.right_corner .. RESET .. BOLD .. post_bar .. RESET
end

-- module
return table.freeze({
	tag = tag,
	render_bar = render_bar,
	time = format_time,

	highlight_syntax = syntax_highlight.highlight,
	theme = syntax_highlight.theme,
	nerdfont = nerdfont,

	bold = bold,
	bkg = back_color,
	txt_color = txt_color,
	reset = RESET,
	b = BOLD,
	dim = DIM,
})
