module Bosh::Director
  class InstanceGroupConfig
    include ValidationHelper

    def initialize(hash, stemcells)
      @hash = hash
      @stemcells = stemcells
    end

    def lifecycle
      safe_property(
        @hash,
        'lifecycle',
        class: String,
        optional: true,
        default: Bosh::Director::DeploymentPlan::InstanceGroup::DEFAULT_LIFECYCLE_PROFILE,
      )
    end

    def name
      safe_property(
        @hash,
        'name',
        class: String,
        optional: false,
      )
    end

    def has_availability_zone?(availability_zone)
      @hash['azs'].include?(availability_zone)
    end

    def has_os?(operating_system)
      @stemcells.any? do |stemcell|
        stemcell['alias'] == @hash['stemcell'] && stemcell['os'] == operating_system
      end
    end

    def has_job?(name, release)
      @hash['jobs'].any? { |job| job['name'] == name && job['release'] == release }
    end

    def network_present?(name)
      @hash['networks'].any? { |network| network['name'] == name }
    end

    def deploy_serial_setting?
      @hash.key?('update') && @hash['update'].key?('serial')
    end

    def deploy_serial?
      return @hash['update']['serial'] if deploy_serial_setting?

      true
    end
  end
end
