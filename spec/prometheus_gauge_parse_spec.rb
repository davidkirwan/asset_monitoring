# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Asset::PrometheusGaugeParse do
  describe '.parse' do
    it 'extracts HELP and gauge values, skips _qty' do
      text = <<~PROM
        # HELP foo_bar The test metric
        # TYPE foo_bar gauge
        foo_bar{label="x"} 12.5
        foo_bar_qty{label="x"} 99
      PROM
      values, help = described_class.parse(text)
      expect(help['foo_bar']).to eq('The test metric')
      expect(values).to eq('foo_bar' => 12.5)
    end
  end
end
