module Bosh::Director
  module Jobs
    class ScheduledOrphanedVMCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphaned_vm_cleanup
      end

      def self.has_work(_)
        Models::OrphanedVm.any?
      end

      def initialize(_)
        @vm_deleter = VmDeleter.new(logger)
      end

      def perform
        orphaned_vms = Models::OrphanedVm.all
        orphaned_vms.each do |vm|
          @vm_deleter.delete_vm_by_cid(vm.cid, vm.stemcell_api_version, vm.cpi)
        end
      end
    end
  end
end
