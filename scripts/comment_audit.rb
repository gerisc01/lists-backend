#!/usr/bin/env ruby
# Ranks comments against the house rule (rare, ≤ 2 lines, no history), and proves a comment-only
# cleanup changed no code. Output is leads for /comment-review, never verdicts.
#
#   ruby scripts/comment_audit.rb                 summary + worst files (src/, bin/, test/, scripts/)
#   ruby scripts/comment_audit.rb src/actions     limit to paths
#   ruby scripts/comment_audit.rb --list          every block, with flags and the line it sits on
#   ruby scripts/comment_audit.rb --json          machine-readable
#   ruby scripts/comment_audit.rb --leads         comments naming things that no longer exist, and methods only a comment still mentions
#   ruby scripts/comment_audit.rb --verify [ref]  changed files vs ref (default HEAD): code identical once comments are stripped?
#   ruby scripts/comment_audit.rb --remove list   delete the blocks named in list, one `file:line` per line
#
# Flags: long (> 2 lines) · history (PRs, decisions, docs/, "used to") · code? (looks commented-out)
# · todo · header (a script's opening block — exempt from the length rule) · directive (magic comments).

require 'ripper'
require 'json'
require 'open3'

ROOT = File.expand_path('..', __dir__)
DEFAULT_DIRS = %w[src bin test scripts].freeze
CODE_DIRS = %w[src bin test scripts api.rb e2e_api.rb scenarios api_seeds].freeze

DIRECTIVE = /\A\s*(frozen_string_literal|encoding|coding|warn_indent|shareable_constant_value)\s*:|rubocop:|\A!/
HISTORY = /\bdecisions?\b|\b0\d{3}\b|docs\/|DECISIONS|TODO\.md|design(\.md)?\s*§|§\s?\d|\bPR ?\d|\bslice \d|\bstep \d|\bphase \d|used to\b|\bpreviously\b|\bno longer\b|\bretired\b|\blegacy\b|\brefactor/i
CODE = /\A\s*(def |end\s*\z|if |unless |return\b|require|class |module |puts |[a-z_]+\s*=[^=]|[a-z_.]+\(.*\)\s*\z)/
GEM_HOOKS = %w[initialize validate to_schema_object from_schema_object type_match? field_value_validation
               field_def_validation registered to_s == call].freeze

args = ARGV.dup
flag = ->(f) { args.include?(f) }
opt = lambda do |f|
  i = args.index(f)
  v = i && args[i + 1]
  v && !v.start_with?('--') ? v : nil
end
targets = args.each_with_index.reject { |a, i| a.start_with?('--') || %w[--verify --remove].include?(args[i - 1]) && i.positive? }.map(&:first)

def rel(path) = path.delete_prefix("#{ROOT}/")

def walk(path)
  abs = File.expand_path(path, ROOT)
  return [] if !File.exist?(abs)
  return abs.end_with?('.rb') ? [abs] : [] if File.file?(abs)

  return Dir.glob(File.join(abs, '**', '*.rb')).reject { |f| rel(f).split('/').any? { |p| p.start_with?('.') || %w[data cache logs].include?(p) } }
end

def comment_tokens(src)
  toks = []
  embdoc = nil
  Ripper.lex(src).each do |(line, col), type, text|
    case type
    when :on_comment then toks << { line: line, col: col, text: text.chomp.sub(/\A#\s?/, ''), raw: text }
    when :on_embdoc_beg then embdoc = { line: line, col: col, text: +'', raw: +text, embdoc: true }
    when :on_embdoc then embdoc[:text] << text; embdoc[:raw] << text
    when :on_embdoc_end
      embdoc[:raw] << text
      embdoc[:end] = line
      toks << embdoc
      embdoc = nil
    end
  end
  return toks
end

# Consecutive full-line comments form one block; a trailing comment is its own block.
def blocks(file)
  src = File.read(file)
  lines = src.lines
  script = rel(file).start_with?('bin/', 'scripts/')
  out = []
  comment_tokens(src).each do |t|
    trailing = !lines[t[:line] - 1][0...t[:col]].strip.empty?
    last_line = t[:end] || t[:line]
    prev = out.last
    if prev && !trailing && !prev[:trailing] && t[:line] == prev[:end] + 1
      prev[:end] = last_line
      prev[:text] << "\n" << t[:text]
      prev[:tokens] << t
    else
      out << { start: t[:line], end: last_line, text: t[:text].dup, trailing: trailing, tokens: [t] }
    end
  end
  return out.map do |b|
    n = b[:end] - b[:start] + 1
    header = script && b[:start] <= 2 && !b[:trailing]
    flags = []
    if b[:text].lines.all? { |l| l.match?(DIRECTIVE) }
      flags << 'directive'
    else
      flags << (header ? 'header' : 'long') if n > 2
      flags << 'history' if b[:text].match?(HISTORY)
      flags << 'code?' if !header && b[:text].lines.any? { |l| l.match?(CODE) }
      flags << 'todo' if b[:text].match?(/\b(TODO|FIXME|HACK)\b/)
    end
    anchor = if b[:trailing]
               lines[b[:start] - 1].strip
             else
               (lines[b[:end]..] || []).find { |l| !l.strip.empty? && !l.strip.start_with?('#') }.to_s.strip
             end
    { file: rel(file), line: b[:start], lines: n, trailing: b[:trailing], flags: flags,
      anchor: anchor[0, 70], text: b[:text], tokens: b[:tokens] }
  end
end

# Tokens with comments and layout removed; any run of newlines counts as one.
def code_shape(src)
  shape = []
  Ripper.lex(src).each do |_, type, text|
    next if %i[on_sp on_embdoc_beg on_embdoc on_embdoc_end].include?(type)

    if %i[on_comment on_nl on_ignored_nl].include?(type)
      shape << :nl if shape.last != :nl
    else
      shape << [type, text]
    end
  end
  return shape
end

def strip_comments(src)
  shape = code_shape(src)
  return shape.map { |t| t == :nl ? "\n" : t[1] }.join(' ')
end

def code_text(files)
  return files.map { |f| strip_comments(File.read(f)) }.join("\n")
end

def leads(files)
  code_files = CODE_DIRS.flat_map { |d| walk(d) }.uniq
  hay = code_text(code_files)
  frontend = File.expand_path('../games-lists/src', ROOT)
  hay += Dir.glob(File.join(frontend, '**', '*.{js,jsx,ts,tsx}')).map { |f| File.read(f) }.join("\n") if Dir.exist?(frontend)
  paths = Dir.glob(File.join(ROOT, '**', '*')).map { |f| rel(f) }
  paths += Dir.glob(File.join(frontend, '**', '*')) if Dir.exist?(frontend)
  skip = /\A(true|false|nil|self|return|new|def|end|id|key|json)\z/

  out = []
  all_blocks = files.flat_map { |f| blocks(f) }
  all_blocks.each do |b|
    names = b[:text].scan(/`([A-Za-z_][A-Za-z0-9_]{2,}[?!]?)(?:[.#][A-Za-z0-9_?!]+)*/).flatten.uniq
    file_refs = b[:text].scan(%r{\b([A-Za-z_][A-Za-z0-9_/.-]*\.(?:rb|js|ts|tsx|sh|json))\b}).flatten.uniq
    file_refs.each do |n|
      out << { kind: 'orphan', file: b[:file], line: b[:line], what: n } if !paths.any? { |p| p == n || p.end_with?("/#{n}") }
    end
    names.each do |n|
      next if n.match?(skip) || file_refs.include?(n)

      out << { kind: 'orphan', file: b[:file], line: b[:line], what: n } if !hay.match?(/(?<![A-Za-z0-9_])#{Regexp.escape(n)}(?![A-Za-z0-9_])/)
    end
  end

  files.reject { |f| rel(f).start_with?('test/') }.each do |f|
    strip_comments(File.read(f)).scan(/def (?:self \. )?([a-z_][A-Za-z0-9_]*[?!]?)/).flatten.uniq.each do |name|
      next if GEM_HOOKS.include?(name)
      next if hay.scan(/(?<![A-Za-z0-9_])#{Regexp.escape(name)}(?![A-Za-z0-9_])/).size > 1

      said = all_blocks.find { |b| b[:text].match?(/\b#{Regexp.escape(name)}\b/) }
      what = said ? "#{name} — nothing calls it; #{said[:file]}:#{said[:line]} still describes it" : "#{name} — nothing calls it"
      out << { kind: 'ghost', file: rel(f), line: 0, what: what }
    end
  end
  return out
end

def verify(ref)
  listed, = Open3.capture2('git', 'diff', '--name-only', '--diff-filter=M', ref, '--', *CODE_DIRS, chdir: ROOT)
  changed = listed.lines.map(&:strip).select { |f| f.end_with?('.rb') }
  bad = 0
  changed.each do |f|
    before, = Open3.capture2('git', 'show', "#{ref}:#{f}", chdir: ROOT)
    after = File.read(File.join(ROOT, f))
    next if code_shape(before) == code_shape(after)

    bad += 1
    puts "✗ code changed: #{f}"
  end
  puts "#{changed.size} files checked, #{bad} with code changes"
  exit(bad.zero? ? 0 : 1)
end

# A full-line comment takes its line with it; a trailing one leaves the code.
def remove(list_file)
  wanted = Hash.new { |h, k| h[k] = [] }
  File.readlines(list_file, chomp: true).map(&:strip).reject(&:empty?).each do |l|
    f, line = l.split(':')
    wanted[f] << line.to_i
  end
  n = 0
  wanted.each do |relpath, lines_wanted|
    abs = File.join(ROOT, relpath)
    found = blocks(abs).select { |b| lines_wanted.include?(b[:line]) }
    puts "! #{relpath}: #{lines_wanted.size - found.size} listed line(s) are not block starts" if found.size != lines_wanted.size
    lines = File.read(abs).lines
    found.sort_by { |b| -b[:line] }.each do |b|
      if b[:trailing]
        t = b[:tokens].first
        lines[t[:line] - 1] = lines[t[:line] - 1][0...t[:col]].rstrip + "\n"
      else
        lines.slice!(b[:line] - 1, b[:lines])
      end
    end
    File.write(abs, lines.join)
    n += found.size
  end
  puts "removed #{n} blocks"
  exit 0
end

files = (targets.empty? ? DEFAULT_DIRS : targets).flat_map { |t| walk(t) }.uniq

if flag.('--leads')
  found = leads(files)
  found.each { |l| puts "#{l[:kind].ljust(7)} #{l[:file]}:#{l[:line]}  #{l[:what]}" }
  puts "#{found.size} lead(s) to read — this says nothing about whether the comments are true"
  exit 0
end
verify(opt.('--verify') || 'HEAD') if flag.('--verify')
remove(opt.('--remove')) if flag.('--remove')

all = files.flat_map { |f| blocks(f) }
if flag.('--json')
  puts JSON.pretty_generate(all.map { |b| b.except(:tokens) })
  exit 0
end
if flag.('--list')
  all.each do |b|
    puts "#{b[:file]}:#{b[:line]}  #{b[:lines]}L #{b[:flags].join(',')}  → #{b[:anchor]}"
    puts b[:text].lines.map { |l| "    #{l.chomp}" }.join("\n")
  end
  exit 0
end

count = ->(f) { all.count { |b| b[:flags].include?(f) } }
puts "#{all.size} blocks · #{all.sum { |b| b[:lines] }} lines · long #{count.('long')} · history #{count.('history')} · " \
     "code? #{count.('code?')} · todo #{count.('todo')} · #{files.size} files"
by_file = all.group_by { |b| b[:file] }.transform_values { |bs| [bs.sum { |b| b[:lines] }, bs.count { |b| b[:flags].include?('long') }] }
puts "\ncomment lines  long  file"
by_file.sort_by { |_, (l, _)| -l }.first(20).each { |f, (l, lg)| puts "#{l.to_s.rjust(13)}  #{lg.to_s.rjust(4)}  #{f}" }
