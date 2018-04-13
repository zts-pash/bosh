require 'spec_helper'

module Bosh::Director
  module Jobs
    describe ScheduledOrphanedVMCleanup do
      describe 'has_work?' do
        context 'when there is an orphaned vm' do
          before do
            Models::OrphanedVm.create(
              cid: 'i-am-a-cid',
              orphaned_at: Time.now,
            )
          end

          it 'returns true' do
            expect(ScheduledOrphanedVMCleanup.has_work(nil)).to be_truthy
          end
        end

        context 'when there are no orphaned vms' do
          it 'returns false' do
            expect(ScheduledOrphanedVMCleanup.has_work(nil)).to be_falsey
          end
        end
      end

      describe 'perform' do
        let!(:orphaned_vm1) do
          Models::OrphanedVm.create(
            cid: 'cid1',
            orphaned_at: Time.now,
            stemcell_api_version: 1,
            cpi: 'jims-cpi',
          )
        end

        let!(:orphaned_vm2) do
          Models::OrphanedVm.create(
            cid: 'cid2',
            orphaned_at: Time.now,
            stemcell_api_version: 2,
            cpi: 'joshs-cpi',
          )
        end

        let(:vm_deleter) { instance_double(Bosh::Director::VmDeleter, delete_vm_by_cid: true) }
        let(:job) { ScheduledOrphanedVMCleanup.new({}) }

        before do
          allow(Bosh::Director::VmDeleter).to receive(:new).and_return(vm_deleter)
        end

        it 'deletes the orphaned vms by cid' do
          job.perform
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi')
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
        end

        it 'releases the ip address used by the vm' do

        end

        it 'records bosh event for vm deletion' do

        end

        context 'when deleting the vm fails' do
          it 'continues deleting orphaned vms' do

          end

          it 'reports the failure' do

          end
        end

        context 'when the vm does not exist' do
          it 'deletes the model from the database' do

          end
        end

        context 'when the orphaned vm is already being deleted' do
          it 'skips deleting the orphaned vm' do

          end
        end
      end
    end
  end
end
