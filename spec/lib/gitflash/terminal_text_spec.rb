# frozen_string_literal: true

RSpec.describe Gitflash::TerminalText do
  describe '.safe' do
    it 'shows control characters as escapes' do
      expect(described_class.safe("a\e[2Jb\r\x07")).to eq('a\\x1B[2Jb\\x0D\\x07')
    end

    it 'escapes the clipboard sequence (OSC 52)' do
      text = described_class.safe("\e]52;c;ZXZpbA==\a")
      expect(text).not_to include("\e", "\a")
    end

    it 'escapes C1 controls and bidirectional overrides' do
      expect(described_class.safe("\u009b\u202Eevil")).to eq('\\x9B\\u202Eevil')
    end

    it 'escapes invisible directional marks' do
      expect(described_class.safe("a\u061Cb\u200Ec\u200Fd")).to eq('a\\u061Cb\\u200Ec\\u200Fd')
    end

    it 'keeps newlines, tabs and normal text' do
      expect(described_class.safe("one\n\ttwo ünï")).to eq("one\n\ttwo ünï")
    end

    it 'survives invalid UTF-8' do
      expect(described_class.safe("bad\xFF")).to eq("bad\uFFFD")
    end
  end

  describe '.line' do
    it 'also shows newlines and tabs as escapes, so text cannot start a fake row' do
      expect(described_class.line("a\n* fake row\tb\e[2J")).to eq('a\\n* fake row\\tb\\x1B[2J')
    end

    it 'leaves ordinary text alone' do
      expect(described_class.line('/tmp/wt/feature x')).to eq('/tmp/wt/feature x')
    end
  end
end
