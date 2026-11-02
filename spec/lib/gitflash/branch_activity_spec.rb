# frozen_string_literal: true

RSpec.describe Gitflash::BranchActivity do
  def line(ref, time, subject) = "refs/heads/#{ref}@{#{time}}\x1f#{subject}"

  it 'marks a branch whose only reflog entry is its creation as unused' do
    output = [line('fresh', 200, 'branch: Created from main'),
              line('used', 300, 'commit: b'), line('used', 100, 'branch: Created from HEAD'),
              line('moved', 150, 'branch: Reset to main')].join("\n")
    activity = described_class.parse(output)
    expect(activity.transform_values(&:unused)).to eq('fresh' => true, 'used' => false,
                                                      'moved' => false)
    expect(activity['used'].last_activity_at).to eq(Time.at(300))
  end

  it 'keeps names with @ and slashes, and knows nothing of branches without entries' do
    activity = described_class.parse(line('feat/a@b', 5, 'branch: Created from main'))
    expect(activity.keys).to eq(['feat/a@b'])
    expect(described_class.parse('')).to eq({})
  end
end
