require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180828142435_add_alternate_variable_id.rb' do
    let(:db) {DBSpecHelper.db}
    let(:subject) { '20180828142435_add_alternate_variable_id.rb' }

    before do
      DBSpecHelper.migrate_all_before(subject)
      DBSpecHelper.migrate(subject)
    end

    context '#db[:variables]' do
      it 'includes the alternate variable id column' do
        expect(db[:variables].columns).to include(:alternate_variable_id)
      end
    end
  end
end
