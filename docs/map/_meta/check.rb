# frozen_string_literal: true

# Checks the map without a test framework:
#   - the twins (AGENTS.md, routing.md) match docs/map/CLAUDE.md, and the root AGENTS.md matches
#     the root CLAUDE.md
#   - every [[link]] in the map names an existing card
#   - every `path:line` or `path:first-last` citation is a valid range inside an existing file
# Run from anywhere: ruby docs/map/_meta/check.rb

ROOT = File.expand_path('../../..', __dir__)
MAP = File.join(ROOT, 'docs/map')
errors = []

MAX_BYTES = 2_000_000

# Repository files are other people's input: a link to a device or a huge file must not be read
def read(path)
  if File.symlink?(path) || !File.file?(path)
    raise "#{path} is not a regular file (links are not followed)"
  end
  raise "#{path} is larger than #{MAX_BYTES} bytes" if File.size(path) > MAX_BYTES

  File.read(path)
end

# File names are text from the repository: show control characters as escapes
def safe(text)
  text.to_s.scrub.gsub(/[\u0000-\u0008\u000B-\u001F\u007F-\u009F]/) do |char|
    format('\\x%02X', char.ord)
  end
end

# Lines of a cited source, counted once per file however many citations name it
LINE_COUNTS = Hash.new do |counts, path|
  counts[path] = File.size(path) > MAX_BYTES ? 0 : File.foreach(path).count
end

{ File.join(MAP, 'AGENTS.md') => File.join(MAP, 'CLAUDE.md'),
  File.join(MAP, 'routing.md') => File.join(MAP, 'CLAUDE.md'),
  File.join(ROOT, 'AGENTS.md') => File.join(ROOT, 'CLAUDE.md') }.each do |twin, source|
  next if File.exist?(twin) && read(twin) == read(source)

  errors << "#{twin.delete_prefix("#{ROOT}/")} differs from #{source.delete_prefix("#{ROOT}/")}; " \
            'run docs/map/_meta/sync-twins.sh'
rescue RuntimeError => e
  errors << safe(e.message)
end

cards = Dir.glob(File.join(MAP, 'objects/*/*.md')).to_set { |file| File.basename(file, '.md') }
sources = Dir.glob(File.join(ROOT, '{lib,spec,schema,bin,.}/**/*')) + Dir.glob(File.join(ROOT, '*'))
sources = sources.select { |file| File.file?(file) && !File.symlink?(file) }

Dir.glob(File.join(MAP, '**/*.md')).each do |file|
  name = safe(file.delete_prefix("#{ROOT}/"))
  begin
    text = read(file)
  rescue RuntimeError => e
    errors << safe(e.message)
    next
  end

  text.scan(/\[\[([^\]]+)\]\]/).flatten.uniq.each do |link|
    errors << "#{name}: link [[#{safe(link)}]] has no card" unless cards.include?(link)
  end

  text.scan(%r{`([\w./-]+\.(?:rb|json|yml|gemspec)):(\d+)(?:-(\d+))?`}).each do |path, first, last|
    matches = sources.select { |source| source.end_with?("/#{path}") }
    if matches.empty?
      errors << "#{name}: cited file #{path} not found"
    elsif first.to_i < 1 || (last && last.to_i < first.to_i)
      errors << "#{name}: #{path}:#{[first, last].compact.join('-')} is not a valid line range"
    elsif matches.none? { |match| LINE_COUNTS[match] >= (last || first).to_i }
      errors << "#{name}: #{path}:#{[first, last].compact.join('-')} is past the end of the file"
    end
  end
end

if errors.empty?
  puts 'map ok'
else
  warn errors
  exit 1
end
