# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  let(:tty) { false }
  let(:home) { File.realpath(Dir.mktmpdir('gitflash-home')) }
  let(:root) { File.realpath(Dir.pwd) }
  let(:shipped) { File.read(Gitflash::Commands::SkillInstall::SOURCE) }
  let(:user_file) { File.join(home, '.claude', 'skills', 'gitflash', 'SKILL.md') }

  before do
    allow($stdin).to receive(:tty?).and_return(tty)
    allow(Dir).to receive(:home).and_return(home)
  end

  after { FileUtils.rm_rf(home) }

  describe 'the shipped skill' do
    it 'has the frontmatter agents read' do
      expect(shipped).to start_with("---\nname: gitflash\ndescription: ")
    end

    it 'is in the gem' do
      spec = Gem::Specification.load(File.expand_path('../../../gitflash.gemspec', __dir__))
      expect(spec.files).to include('skills/gitflash/SKILL.md')
    end

    it 'is printed by skill show' do
      expect(run_cli('skill', 'show').stdout).to eq(shipped)
    end
  end

  describe 'skill install' do
    it 'installs into the Claude Code user skills by default, once' do
      json = run_cli('skill', 'install', '--json').json
      expect(json).to include('command' => 'skill install', 'status' => 'done')
      expect(json['result']).to include('scope' => 'user', 'file' => user_file,
                                        'version' => Gitflash::VERSION)
      expect(File.read(user_file)).to eq(shipped)
      expect(run_cli('skill', 'install', '--json').json['status']).to eq('noop')
    end

    it 'installs into the repository for --scope project' do
      run_cli('skill', 'install', '--scope', 'project')
      expect(File.read(File.join(root, '.claude', 'skills', 'gitflash', 'SKILL.md'))).to eq(shipped)
    end

    it 'installs into DIR/gitflash for --path DIR' do
      FileUtils.mkdir_p('agent-skills')
      json = run_cli('skill', 'install', '--path', 'agent-skills', '--json').json
      expect(json['result']).to include('scope' => 'path',
                                        'directory' => File.join(root, 'agent-skills'))
      expect(File.read(File.join('agent-skills', 'gitflash', 'SKILL.md'))).to eq(shipped)
    end

    it 'refuses a --path that is not a directory, and --path with --scope' do
      run = run_cli('skill', 'install', '--path', 'missing', '--json')
      expect(run.status).to eq(2)
      expect(run.json.dig('error', 'code')).to eq('invalid_options')

      FileUtils.mkdir_p('dir')
      run = run_cli('skill', 'install', '--path', 'dir', '--scope', 'user', '--json')
      expect(run.json.dig('error', 'message')).to include('not both')
    end

    it 'only shows the plan with --dry-run' do
      json = run_cli('skill', 'install', '--dry-run', '--json').json
      expect(json).to include('status' => 'planned', 'dry_run' => true)
      expect(File).not_to exist(user_file)
    end

    it 'works outside a git repository for the user scope' do
      Dir.mktmpdir do |outside|
        Dir.chdir(outside) { run_cli('skill', 'install') }
      end
      expect(File.read(user_file)).to eq(shipped)
    end

    it 'refuses a skills directory in the repository that is a symbolic link' do
      FileUtils.mkdir_p('.claude')
      File.symlink(home, File.join('.claude', 'skills'))
      run = run_cli('skill', 'install', '--scope', 'project', '--json')
      expect(run.status).to eq(1)
      expect(run.json.dig('error', 'message')).to include('symbolic link')
      expect(Dir.children(home)).to be_empty
    end

    context 'when a different skill file is installed' do
      before do
        FileUtils.mkdir_p(File.dirname(user_file))
        File.write(user_file, "my own notes\n")
      end

      it 'needs --confirm TOKEN, not --yes, and keeps the file until then' do
        run = run_cli('skill', 'install', '--yes', '--json')
        expect(run.status).to eq(2)
        json = run.json
        expect(json['status']).to eq('confirmation_required')
        expect(json.dig('plan', 'previous_sha256'))
          .to eq(Digest::SHA256.hexdigest("my own notes\n"))
        expect(File.read(user_file)).to eq("my own notes\n")

        token = json.dig('error', 'confirm_token')
        done = run_cli('skill', 'install', '--confirm', token, '--json').json
        expect(done['status']).to eq('done')
        expect(File.read(user_file)).to eq(shipped)
      end

      it 'does not take a token made for other file contents' do
        token = run_cli('skill', 'install', '--json').json.dig('error', 'confirm_token')
        File.write(user_file, "edited again\n")
        run = run_cli('skill', 'install', '--confirm', token, '--json')
        expect(run.status).to eq(2)
        expect(File.read(user_file)).to eq("edited again\n")
      end
    end
  end
end
