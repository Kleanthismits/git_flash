# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# The map checker and the twin sync script run on contributor-controlled files in CI
RSpec.describe 'docs/map scripts' do # rubocop:disable RSpec/DescribeClass
  let(:source_root) { File.expand_path('..', __dir__) }
  let(:root) { Dir.mktmpdir('gitflash-map') }

  before do
    FileUtils.mkdir_p(File.join(root, 'docs/map/_meta'))
    FileUtils.mkdir_p(File.join(root, 'docs/map/objects/core'))
    %w[check.rb sync-twins.sh].each do |script|
      FileUtils.cp(File.join(source_root, 'docs/map/_meta', script),
                   File.join(root, 'docs/map/_meta'))
    end
    write('CLAUDE.md', "root\n")
    write('AGENTS.md', "root\n")
    write('docs/map/CLAUDE.md', "map\n")
    write('docs/map/AGENTS.md', "map\n")
    write('docs/map/routing.md', "map\n")
  end

  after { FileUtils.remove_entry(root) }

  def write(path, text)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, text)
  end

  def check = Open3.capture3(RbConfig.ruby, File.join(root, 'docs/map/_meta/check.rb'))

  def sync = Open3.capture3('sh', File.join(root, 'docs/map/_meta/sync-twins.sh'))

  describe 'check.rb' do
    it 'passes on a consistent map' do
      expect(check).to match([/map ok/, '', have_attributes(success?: true)])
    end

    it 'refuses a twin that is a link, without reading the target' do
      FileUtils.rm(File.join(root, 'docs/map/AGENTS.md'))
      File.symlink('/dev/zero', File.join(root, 'docs/map/AGENTS.md'))

      _out, err, status = check
      expect(status).not_to be_success
      expect(err).to include('not a regular file')
    end

    it 'refuses a card that is larger than the limit' do
      write('docs/map/objects/core/big.md', 'x' * 2_100_000)
      _out, err, status = check
      expect(status).not_to be_success
      expect(err).to include('larger than')
    end

    it 'shows control characters of a file name as escapes' do
      write("docs/map/objects/core/evil\e]52;c;ZXZpbA==\a.md", "[[nowhere]]\n")
      _out, err, status = check
      expect(status).not_to be_success
      expect(err).to include('evil\\x1B]52;c;ZXZpbA==\\x07')
      expect(err).not_to include("\e", "\a")
    end

    it 'counts the lines of a cited file once, however often it is cited' do
      write('schema/v1.json', "{}\n" * 5)
      write('docs/map/objects/core/card.md',
            "`schema/v1.json:1` #{'`schema/v1.json:2-3` ' * 200}\n")
      expect(check).to match([/map ok/, '', have_attributes(success?: true)])
    end
  end

  describe 'sync-twins.sh' do
    it 'rebuilds the twins' do
      write('docs/map/CLAUDE.md', "new map\n")
      _out, _err, status = sync
      expect(status).to be_success
      expect(File.read(File.join(root, 'docs/map/AGENTS.md'))).to eq("new map\n")
    end

    it 'refuses a canonical source that is a link' do
      FileUtils.rm(File.join(root, 'CLAUDE.md'))
      File.symlink('/dev/zero', File.join(root, 'CLAUDE.md'))

      _out, err, status = sync
      expect(status).not_to be_success
      expect(err).to include('regular file')
    end

    it 'refuses a twin that is a link, so cp cannot write through it' do
      target = File.join(root, 'elsewhere.txt')
      File.write(target, 'keep')
      FileUtils.rm(File.join(root, 'AGENTS.md'))
      File.symlink(target, File.join(root, 'AGENTS.md'))

      _out, err, status = sync
      expect(status).not_to be_success
      expect(err).to include('regular file')
      expect(File.read(target)).to eq('keep')
    end

    it 'refuses a source over the size limit' do
      write('CLAUDE.md', 'x' * 1_100_000)
      _out, err, status = sync
      expect(status).not_to be_success
      expect(err).to include('smaller than 1 MB')
    end
  end
end
