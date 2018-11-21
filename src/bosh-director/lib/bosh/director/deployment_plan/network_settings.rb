module Bosh::Director
  module DeploymentPlan
    class NetworkSettings
      def initialize(
        availability_zone:,
        current_networks:,
        default_network:,
        desired_reservations:,
        instance_group_name:,
        instance_id:,
        deployment_name:,
        root_domain:,
        instance_index:,
        feature_configured_dns_encoder:
      )
        @availability_zone              = availability_zone
        @current_networks               = current_networks
        @default_network                = default_network
        @desired_reservations           = desired_reservations
        @instance_group_name            = instance_group_name
        @instance_id                    = instance_id
        @instance_index                 = instance_index
        @deployment_name                = deployment_name
        @root_domain                    = root_domain
        @feature_configured_dns_encoder = feature_configured_dns_encoder
      end

      def to_hash
        default_properties = {}
        @default_network.each do |key, value|
          (default_properties[value] ||= []) << key
        end

        network_settings = {}
        @desired_reservations.each do |reservation|
          network_name = reservation.network.name
          network_settings[network_name] = reservation.network.network_settings(
            reservation,
            default_properties[network_name],
            @availability_zone,
          )
          # Somewhat of a hack: for dynamic networks we might know IP address, Netmask & Gateway
          # if they're featured in agent state, in that case we put them into network spec to satisfy
          # ConfigurationHasher in both agent and director.
          next unless @current_networks.is_a?(Hash)
          next unless @current_networks[network_name].is_a?(Hash)
          next unless network_settings[network_name]['type'] == 'dynamic'

          %w[ip netmask gateway].each do |key|
            next if @current_networks[network_name][key].nil?

            network_settings[network_name][key] = @current_networks[network_name][key]
          end
        end

        network_settings
      end

      def dns_record_info
        dns_record_info = {}
        to_hash.each do |network_name, network|
          index_dns_name = DnsNameGenerator.dns_record_name(
            @instance_index,
            @instance_group_name,
            network_name,
            @deployment_name,
            @root_domain,
          )
          dns_record_info[index_dns_name] = network['ip']
          id_dns_name = DnsNameGenerator.dns_record_name(
            @instance_id,
            @instance_group_name,
            network_name,
            @deployment_name,
            @root_domain,
          )
          dns_record_info[id_dns_name] = network['ip']
        end
        dns_record_info
      end

      def network_address(link_group_name, prefer_dns_entry)
        network_name = @default_network['addressable'] || @default_network['gateway']
        net_hash = to_hash[network_name]
        get_address(network_name, net_hash['type'], net_hash['ip'], link_group_name, prefer_dns_entry)
      end

      def instance_group_network_address(prefer_dns_entry)
        network_name = @default_network['addressable'] || @default_network['gateway']
        net_hash = to_hash[network_name]
        @feature_configured_dns_encoder.encode_instance_group_address(
          prefer_dns_entry: prefer_dns_entry,
          network_name: network_name,
          network_type: net_hash['type'],
          network_ip: net_hash['ip'],
          instance_id: @instance_id,
          instance_group_name: @instance_group_name,
        )
      end

      def network_addresses(link_group_name, prefer_dns_entry)
        network_addresses = {}

        to_hash.each do |network_name, network|
          network_addresses[network_name] = get_address(
            network_name,
            network['type'],
            network['ip'],
            link_group_name,
            prefer_dns_entry,
          )
        end

        network_addresses
      end

      private

      def get_address(network_name, network_type, network_ip, link_group_name, prefer_dns_entry)
        @feature_configured_dns_encoder.encode(
          prefer_dns_entry: prefer_dns_entry,
          network_name: network_name,
          network_type: network_type,
          network_ip: network_ip,
          instance_id: @instance_id,
          link_group_name: link_group_name,
          instance_group_name: @instance_group_name,
        )
      end
    end
  end
end
