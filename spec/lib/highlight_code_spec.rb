# frozen_string_literal: true

RSpec.describe HighlightCode do
  it 'escapes markup in the highlighted source' do
    html = described_class.call('{"response": "<script>alert(1)</script>"}', :JSON)

    expect(html).not_to include('<script>')
    expect(html).to include('&lt;script&gt;')
  end
end
