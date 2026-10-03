# frozen_string_literal: true

# Checks the map without a test framework:
#   - the twins (AGENTS.md, routing.md) match docs/map/CLAUDE.md, and the root AGENTS.md matches
#     the root CLAUDE.md
#   - every [[link]] in the map names an existing card
#   - every `path:line` citation points inside an existing file
# Run from anywhere: ruby docs/map/_meta/check.rb

ROOT = File.expand_path('../../..', __dir__)
MAP = File.join(ROOT, 'docs/map')
errors = []

def read(path)
  File.read(path)
end

{ File.join(MAP, 'AGENTS.md') => File.join(MAP, 'CLAUDE.md'),
  File.join(MAP, 'routing.md') => File.join(MAP, 'CLAUDE.md'),
  File.join(ROOT, 'AGENTS.md') => File.join(ROOT, 'CLAUDE.md') }.each do |twin, source|
  next if File.exist?(twin) && read(twin) == read(source)

  errors << "#{twin.delete_prefix("#{ROOT}/")} differs from #{source.delete_prefix("#{ROOT}/")}; " \
            'run docs/map/_meta/sync-twins.sh'
end

cards = Dir.glob(File.join(MAP, 'objects/*/*.md')).to_set { |file| File.basename(file, '.md') }
sources = Dir.glob(File.join(ROOT, '{lib,spec,schema,bin,.}/**/*')) + Dir.glob(File.join(ROOT, '*'))
sources = sources.select { |file| File.file?(file) }

Dir.glob(File.join(MAP, '**/*.md')).each do |file|
  name = file.delete_prefix("#{ROOT}/")
  text = read(file)

  text.scan(/\[\[([^\]]+)\]\]/).flatten.uniq.each do |link|
    errors << "#{name}: link [[#{link}]] has no card" unless cards.include?(link)
  end

  text.scan(%r{`([\w./-]+\.(?:rb|json|yml|gemspec)):(\d+)(?:-(\d+))?`}).each do |path, first, last|
    matches = sources.select { |source| source.end_with?("/#{path}") }
    if matches.empty?
      errors << "#{name}: cited file #{path} not found"
    elsif matches.none? { |match| File.foreach(match).count >= (last || first).to_i }
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
