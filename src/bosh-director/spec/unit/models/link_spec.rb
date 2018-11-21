require 'spec_helper'
require 'bosh/director/models/links/link'

module Bosh::Director::Models::Links
  describe Link do
    describe '#validate' do
      it 'validates presence of name' do
        expect do
          Link.create(
            link_consumer_intent_id: 1,
            link_content: '{}',
          )
        end.to raise_error(Sequel::ValidationFailed, 'name presence')
      end

      it 'validates presence of link_consumer_intent_id' do
        expect do
          Link.create(
            name: 'name',
            link_content: '{}',
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_consumer_intent_id presence')
      end

      it 'validates presence of link_content' do
        expect do
          Link.create(
            name: 'name',
            link_consumer_intent_id: 1,
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_content presence')
      end
    end

    describe '#group_name' do
      subject(:link) do
        link = Link.make(name: 'bar')
        allow(link).to receive(:link_provider_intent).and_return(link_provider_intent)
        link
      end

      let(:link_provider_intent) { double(LinkProviderIntent, group_name: 'foo') }

      it 'delegates to its LinkProviderIntent' do
        expect(link.group_name).to eq('foo')
      end

      context 'when provider intent is not set' do
        before do
          allow(link).to receive(:link_provider_intent).and_return(nil)
        end

        it 'returns blank' do
          expect(link.group_name).to eq('')
        end
      end
    end
  end
end
