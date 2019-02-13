module Bosh::Director
  module DeploymentPlan
    class VipNetwork < Network
      extend ValidationHelper
      include IpUtil

      # @return [Hash] Network cloud properties
      attr_reader :cloud_properties, :subnets

      def self.parse(network_spec, availability_zones, logger)
        name = safe_property(network_spec, 'name', class: String)
        subnet_specs = safe_property(network_spec, 'subnets', class: Array, default: [])
        subnets = []
        subnet_specs.each do |subnet_spec|
          new_subnet = VipNetworkSubnet.parse(name, subnet_spec, availability_zones)
          # TODO: consider validating for static ip overlap between subnets
          subnets << new_subnet
        end
        validate_all_subnets_use_azs(subnets, name)
        new(network_spec, subnets, logger)
      end

      ##
      # Creates a new network.
      #
      # @param [Hash] network_spec parsed deployment manifest network section
      # @param [Logger] logger
      def initialize(network_spec, subnets, logger)
        super(safe_property(network_spec, "name", :class => String), TaggedLogger.new(logger, 'network-configuration'))

        @cloud_properties = safe_property(network_spec, "cloud_properties", class: Hash, default: {})
        @subnets = subnets
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = REQUIRED_DEFAULTS, availability_zone = nil)
        #TODO: review (compare with manual_network implementation)
        if default_properties && !default_properties.empty?
          raise NetworkReservationVipDefaultProvided,
                "Can't provide any defaults since this is a VIP network"
        end

        {
          "type" => "vip",
          "ip" => ip_to_netaddr(reservation.ip).ip,
          "cloud_properties" => @cloud_properties
        }
      end

      def ip_type(_)
        if globally_allocate_vip?
          :dynamic
        else
          :static
        end
      end

      def has_azs?(az_names)
        true
      end

      def globally_allocate_vip?
        @subnets.size > 0
      end

      private

      def self.validate_all_subnets_use_azs(subnets, network_name)
        subnets_with_azs = []
        subnets_without_azs = []
        subnets.each do |subnet|
          if subnet.availability_zone_names.to_a.empty?
            subnets_without_azs << subnet
          else
            subnets_with_azs << subnet
          end
        end

        if subnets_with_azs.size > 0 && subnets_without_azs.size > 0
          raise JobInvalidAvailabilityZone,
                "Subnets on network '#{network_name}' must all either specify availability zone or not"
        end
      end
    end

    class VipNetworkSubnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :network_name, :name, :availability_zone_names
      attr_accessor :static_ips

      def self.parse(network_name, subnet_spec, availability_zones)
        @logger = Config.logger

        sn_name = safe_property(subnet_spec, 'name', optional: true)
        static_ips = Set.new

        availability_zone_names = parse_availability_zones(subnet_spec, network_name, availability_zones)
        static_property = safe_property(subnet_spec, 'static', optional: true)

        # TODO: are cloud properties useful?
        each_ip(static_property) do |ip|
          static_ips.add(ip)
        end

        new(
            network_name,
            availability_zone_names,
            static_ips,
            sn_name,
            )
      end

      def initialize(network_name, availability_zone_names, static_ips, subnet_name = nil)
        @network_name = network_name
        @name = subnet_name
        @availability_zone_names = availability_zone_names
        @static_ips = static_ips
      end

      private


      def self.parse_availability_zones(subnet_spec, network_name, availability_zones)
        has_availability_zones_key = subnet_spec.has_key?('azs')
        has_availability_zone_key = subnet_spec.has_key?('az')
        if has_availability_zones_key && has_availability_zone_key
          raise Bosh::Director::NetworkInvalidProperty, "Network '#{network_name}' contains both 'az' and 'azs'. Choose one."
        end

        if has_availability_zones_key
          zones = safe_property(subnet_spec, 'azs', class: Array, optional: true)
          if zones.empty?
            raise Bosh::Director::NetworkInvalidProperty, "Network '#{network_name}' refers to an empty 'azs' array"
          end
          zones.each do |zone|
            check_validity_of_subnet_availability_zone(zone, availability_zones, network_name)
          end
          zones
        else
          availability_zone_name = safe_property(subnet_spec, 'az', class: String, optional: true)
          check_validity_of_subnet_availability_zone(availability_zone_name, availability_zones, network_name)
          availability_zone_name.nil? ? nil : [availability_zone_name]
        end
      end

      def self.check_validity_of_subnet_availability_zone(availability_zone_name, availability_zones, network_name)
        unless availability_zone_name.nil? || availability_zones.any? { |az| az.name == availability_zone_name }
          raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{network_name}' refers to an unknown availability zone '#{availability_zone_name}'"
        end
      end
    end
  end
end
