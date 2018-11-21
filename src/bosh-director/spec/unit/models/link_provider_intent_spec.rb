require 'spec_helper'
require 'bosh/director/models/links/link_provider_intent'

module Bosh::Director::Models::Links
  describe LinkProviderIntent do
    describe '#validate' do
      it 'validates presence of original_name' do
        expect do
          LinkProviderIntent.create(
            link_provider_id: 1,
            type: 't',
          )
        end.to raise_error(Sequel::ValidationFailed, 'original_name presence')
      end
      it 'validates presence of link_provider_id' do
        expect do
          LinkProviderIntent.create(
            original_name: 'original_name',
            type: 't',
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_provider_id presence')
      end
      it 'validates presence of type' do
        expect do
          LinkProviderIntent.create(
            original_name: 'original_name',
            link_provider_id: 1,
          )
        end.to raise_error(Sequel::ValidationFailed, 'type presence')
      end
    end

    describe '#group_name' do
      context 'when provider intent has a type a name' do
        subject(:link_provider_intent) do
          LinkProviderIntent.make(type: 'type', name: 'name')
        end

        it 'returns a combination of provider name and link type' do
          expect(link_provider_intent.group_name).to eq('name-type')
        end
      end

      context 'when provider intent has a type and no name' do
        subject(:link_provider_intent) do
          LinkProviderIntent.make(original_name: 'original_name', type: 'type', name: nil)
        end

        it 'returns a combination of provider original name and link type' do
          expect(link_provider_intent.group_name).to eq('original_name-type')
        end
      end
    end
  end
end
