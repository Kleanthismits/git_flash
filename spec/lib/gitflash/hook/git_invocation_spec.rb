# frozen_string_literal: true

RSpec.describe Gitflash::Hook::GitInvocation, :git_repo do
  it 'reads the aliases configured in a repository, with spaces and newlines in values' do
    git('config', 'alias.nuke', 'reset --hard')
    git('config', 'alias.multi', "!git stash\ngit clean -f")
    aliases = described_class.configured_aliases(Dir.pwd)
    expect(aliases).to include('nuke' => 'reset --hard', 'multi' => "!git stash\ngit clean -f")
  end

  it 'reads no aliases outside a repository' do
    Dir.mktmpdir do |dir|
      expect(described_class.configured_aliases(File.join(dir, 'missing'))).to eq({})
    end
  end
end
