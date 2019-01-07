require 'json'

module Bosh::Director::Metrics
  Load = Struct.new(:load1, :load5, :load15)

  Memory = Struct.new(:total, :free, :used)

  Disk = Struct.new(:total, :free, :used)

  CPU = Struct.new(:user, :system, :wait)

  class DiskCollection
    def initialize
      @disks = []
    end

    def add(disk)
      raise 'disk must be of Disk type' unless disk.is_a?(Disk)

      @disks << disk
    end

    def disks
      disks = []
      @disks.each do |disk|
        disks << disk.to_h
      end
      disks
    end
  end
end
