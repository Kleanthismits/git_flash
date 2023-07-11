RSpec.describe Gitflash do
  it 'Zeiwerk works properly and eager loads all files' do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
