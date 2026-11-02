# frozen_string_literal: true

require 'json'

# The Claude Code plugin (.claude-plugin/) runs gitflash commands by name, so it must keep
# matching what the gem ships
RSpec.describe 'Claude Code plugin' do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path('..', __dir__) }
  let(:plugin) { JSON.parse(File.read(File.join(root, '.claude-plugin', 'plugin.json'))) }
  let(:marketplace) do
    JSON.parse(File.read(File.join(root, '.claude-plugin', 'marketplace.json')))
  end

  it 'has the gem version' do
    expect(plugin['version']).to eq(Gitflash::VERSION)
  end

  it 'is listed in the marketplace from the repository root' do
    expect(marketplace['plugins'])
      .to contain_exactly(include('name' => 'gitflash', 'source' => './'))
  end

  it 'starts the MCP server' do
    expect(plugin.dig('mcpServers', 'gitflash')).to eq('command' => 'gitflash', 'args' => ['mcp'])
  end

  it 'registers the hook as hook install does, before and after Bash commands' do
    %w[PreToolUse PostToolUse].each do |event|
      groups = plugin.dig('hooks', event)
      hook = { 'type' => 'command', 'command' => Gitflash::Commands::HookInstall::MARKING_COMMAND,
               'timeout' => 30 }
      expect(groups).to eq([{ 'matcher' => 'Bash', 'hooks' => [hook] }])
      expect(groups.dig(0, 'hooks', 0, 'command')).to match(Gitflash::Hook::Settings::PATTERN)
    end
  end

  it 'ships the skill the gem installs' do
    skill = File.join(root, plugin['skills'], 'gitflash', 'SKILL.md')
    expect(File.realpath(skill)).to eq(File.realpath(Gitflash::Commands::SkillInstall::SOURCE))
  end
end
