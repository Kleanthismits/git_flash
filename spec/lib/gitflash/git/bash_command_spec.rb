describe Gitflash::Git::BashCommand do
  it 'executes succesfully a valid command' do
    expect(described_class.exec('echo Hello').strip).to eq('Hello')
  end
end
