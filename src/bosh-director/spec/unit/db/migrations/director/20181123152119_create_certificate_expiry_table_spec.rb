require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20181123152119_create_certificate_expiry_table.rb' do
    let(:db) { DBSpecHelper.db }
    let(:expiry) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(subject)

      db[:deployments] << {
        id: 42,
        name: 'fake_deployment',
      }

      db[:deployments] << {
        id: 28,
        name: 'fake_deployment_2',
      }

      DBSpecHelper.migrate(subject)
    end

    it 'creates the certificate_expiry table' do
      db[:certificate_expiries] << {
        deployment_id: 42,
        certificate_path: '/bosh-1/fake_deployment/root_ca',
        expiry: expiry,
      }

      record = db[:certificate_expiries].first
      expect(record[:id]).to eq(1)
      expect(record[:deployment_id]).to eq(42)
      expect(record[:certificate_path]).to eq('/bosh-1/fake_deployment/root_ca')
      expect(record[:expiry]).to_not be_nil
    end

    it 'the table makes sure the deployment plus path are unique' do
      db[:certificate_expiries] << {
        deployment_id: 42,
        certificate_path: '/bosh-1/fake_deployment/root_ca',
        expiry: expiry,
      }

      expect do
        db[:certificate_expiries] << {
          deployment_id: 42,
          certificate_path: '/bosh-1/fake_deployment/root_ca',
          expiry: Time.at(628232400).utc,
        }
      end.to raise_exception Sequel::UniqueConstraintViolation

      record = db[:certificate_expiries].first
      expect(record[:id]).to eq(1)
      expect(record[:deployment_id]).to eq(42)
      expect(record[:certificate_path]).to eq('/bosh-1/fake_deployment/root_ca')
      expect(record[:expiry]).to_not be_nil

      db[:certificate_expiries] << {
        deployment_id: 28,
        certificate_path: '/bosh-1/fake_deployment/root_ca',
        expiry: Time.at(628232400).utc,
      }

      expect(db[:certificate_expiries].count).to equal(2)
    end
  end
end
