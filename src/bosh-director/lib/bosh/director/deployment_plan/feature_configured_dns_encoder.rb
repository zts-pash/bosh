module Bosh::Director
  module DeploymentPlan
    class FeatureConfiguredDNSEncoder
      def initialize(root_domain:, deployment_name:, use_short_dns_addresses:, use_link_address:)
        @root_domain      = root_domain
        @deployment_name  = deployment_name
        @use_link_address = use_link_address
        @dns_encoder = LocalDnsEncoderManager.create_dns_encoder(use_short_dns_addresses)
      end

      # TODO(ja,db): make encode treat missing link_group_name as signal to not use it, rather than having separate #encode_instance_group_address method
      def encode(
        prefer_dns_entry:,
        network_name:,
        network_type:,
        network_ip:,
        instance_id:,
        link_group_name:,
        instance_group_name:
      )
        group_type = Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP
        group_name = instance_group_name
        if @use_link_address
          group_type = Models::LocalDnsEncodedGroup::Types::LINK
          group_name = link_group_name
        end

        encode_it(
          prefer_dns_entry: prefer_dns_entry,
          group_type: group_type,
          group_name: group_name,
          network_name: network_name,
          network_type: network_type,
          network_ip: network_ip,
          instance_id: instance_id,
        )
      end

      def encode_instance_group_address(
        prefer_dns_entry:,
        network_name:,
        network_type:,
        network_ip:,
        instance_id:,
        instance_group_name:
      )
        encode_it(
          prefer_dns_entry: prefer_dns_entry,
          group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
          group_name: instance_group_name,
          network_name: network_name,
          network_type: network_type,
          network_ip: network_ip,
          instance_id: instance_id,
        )
      end

      private

      def encode_it(
        prefer_dns_entry:,
        network_name:,
        network_type:,
        network_ip:,
        instance_id:,
        group_name:,
        group_type:
      )
        return network_ip unless should_use_dns?(prefer_dns_entry, network_type)

        @dns_encoder.encode_query(
          group_type:      group_type,
          group_name:      group_name,
          root_domain:     @root_domain,
          default_network: network_name,
          deployment_name: @deployment_name,
          uuid:            instance_id,
        )
      end

      def should_use_dns?(prefer_dns_entry, network_type)
        network_type == 'dynamic' || (prefer_dns_entry && Bosh::Director::Config.local_dns_enabled?)
      end
    end
  end
end
