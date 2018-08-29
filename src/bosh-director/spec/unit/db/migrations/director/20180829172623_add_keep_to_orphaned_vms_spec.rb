require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180829172623_add_keep_to_orphaned_vms.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
      DBSpecHelper.migrate(subject)
    end

    # TODO
  end
end
