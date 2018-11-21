require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe NetworkSettings do
      let(:instance_group_name)     { double(:instance_group_name) }
      let(:instance_id)             { double(:instance_id) }
      let(:deployment_name)         { double(:deployment_name) }
      let(:root_domain)             { double(:root_domain) }
      let(:instance_index)          { 3 }
      let(:use_short_dns_addresses) { double(:use_short_dns_addresses) }
      let(:current_networks)        do
        {
          'net_a' => {
            'ip' => '10.0.0.6',
            'netmask' => '255.255.255.0',
            'gateway' => '10.0.0.1',
          },
          'net_b' => {
            'ip' => '10.1.0.6',
            'netmask' => '255.255.255.0',
            'gateway' => '10.1.0.1',
          },
        }
      end

      subject(:network_settings) do
        NetworkSettings.new(
          availability_zone:    az,
          current_networks:     current_networks,
          default_network:      { 'gateway' => 'net_a' },
          deployment_name:      deployment_name,
          desired_reservations: reservations,
          instance_group_name:  instance_group_name,
          instance_id:          instance_id,
          instance_index:       3,
          root_domain:          root_domain,
          feature_configured_dns_encoder:     feature_configured_dns_encoder,
        )
      end

      let(:feature_configured_dns_encoder) { instance_double(FeatureConfiguredDNSEncoder) }

      let(:instance_group) do
        instance_group = InstanceGroup.new(logger)
        instance_group.name = 'fake-job'
        instance_group
      end

      let(:az) { AvailabilityZone.new('az-1', 'foo' => 'bar') }
      let(:reservations) do
        reservation_a = Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, manual_network_a)
        reservation_a.resolve_ip('10.0.0.6')
        reservation_b = Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, manual_network_b)
        reservation_b.resolve_ip('10.1.0.6')
        [reservation_a, reservation_b]
      end

      let(:manual_network_a) do
        ManualNetwork.parse(
          {
            'name' => 'net_a',
            'dns' => ['1.2.3.4'],
            'subnets' => [{
              'range' => '10.0.0.1/24',
              'gateway' => '10.0.0.1',
              'dns' => ['1.2.3.4'],
              'cloud_properties' => { 'foo' => 'bar' },
            }],
          },
          [],
          GlobalNetworkResolver.new(plan, [], logger),
          logger,
        )
      end

      let(:manual_network_b) do
        ManualNetwork.parse(
          {
            'name' => 'net_b',
            'dns' => ['1.2.3.4'],
            'subnets' => [{
              'range' => '10.1.0.1/24',
              'gateway' => '10.1.0.1',
              'dns' => ['1.2.3.4'],
              'cloud_properties' => { 'baz' => 'bam' },
            }],
          },
          [],
          GlobalNetworkResolver.new(plan, [], logger),
          logger,
        )
      end

      let(:plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }
      let(:use_short_dns_addresses) { false }

      describe '#to_hash' do
        context 'dynamic network' do
          let(:dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], { 'foo' => 'bar' }, 'az-1')]
            DynamicNetwork.new('net_a', subnets, logger)
          end

          let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)] }

          it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
            expect(network_settings.to_hash).to eql(
              'net_a' => {
                'type' => 'dynamic',
                'cloud_properties' => {
                  'foo' => 'bar',
                },
                'dns' => ['1.2.3.4'],
                'default' => ['gateway'],
                'ip' => '10.0.0.6',
                'netmask' => '255.255.255.0',
                'gateway' => '10.0.0.1',
              },
            )
          end
        end
      end

      describe '#dns_record_info' do
        before do
          allow(DnsNameGenerator).to receive(:dns_record_name).with(
            instance_index,
            instance_group_name,
            'net_a',
            deployment_name,
            root_domain,
          ).and_return(index_dns_name_a)
          allow(DnsNameGenerator).to receive(:dns_record_name).with(
            instance_id,
            instance_group_name,
            'net_a',
            deployment_name,
            root_domain,
          ).and_return(id_dns_name_a)
        end

        before do
          allow(DnsNameGenerator).to receive(:dns_record_name).with(
            instance_index,
            instance_group_name,
            'net_b',
            deployment_name,
            root_domain,
          ).and_return(index_dns_name_b)
          allow(DnsNameGenerator).to receive(:dns_record_name).with(
            instance_id,
            instance_group_name,
            'net_b',
            deployment_name,
            root_domain,
          ).and_return(id_dns_name_b)
        end

        let(:index_dns_name_a) { Sham.name }
        let(:id_dns_name_a)    { Sham.name }
        let(:index_dns_name_b) { Sham.name }
        let(:id_dns_name_b)    { Sham.name }

        it 'includes both id and uuid records' do
          expect(network_settings.dns_record_info).to eq(
            id_dns_name_a    => '10.0.0.6',
            index_dns_name_a => '10.0.0.6',
            id_dns_name_b    => '10.1.0.6',
            index_dns_name_b => '10.1.0.6',
          )
        end
      end


      context 'DNS encoder' do
        let(:link_group_name)  { double(:link_group_name) }
        let(:prefer_dns_entry) { double(:prefer_dns_entry) }
        let(:use_link_address) { double(:use_link_address) }
        let(:encoded_net_a)    { double(:encoded_net_a) }
        let(:ig_encoded_net_a) { double(:ig_encoded_net_a) }
        let(:encoded_net_b)    { double(:encoded_net_b) }

        before do
          allow(FeatureConfiguredDNSEncoder).to receive(:new).with(
            root_domain:             root_domain,
            deployment_name:         deployment_name,
            use_link_address:        use_link_address,
            use_short_dns_addresses: use_short_dns_addresses,
          ).and_return(feature_configured_dns_encoder)
        end

        let(:feature_configured_dns_encoder) { instance_double(FeatureConfiguredDNSEncoder) }

        before do
          allow(feature_configured_dns_encoder).to receive(:encode).with(
            instance_group_name:     instance_group_name,
            instance_id:             instance_id,
            prefer_dns_entry:        prefer_dns_entry,
            link_group_name:         link_group_name,
            network_ip:              '10.0.0.6',
            network_name:            'net_a',
            network_type:            'manual',
          ).and_return encoded_net_a

          allow(feature_configured_dns_encoder).to receive(:encode_instance_group_address).with(
            instance_group_name:     instance_group_name,
            instance_id:             instance_id,
            prefer_dns_entry:        prefer_dns_entry,
            network_ip:              '10.0.0.6',
            network_name:            'net_a',
            network_type:            'manual',
          ).and_return ig_encoded_net_a

          allow(feature_configured_dns_encoder).to receive(:encode).with(
            instance_id:             instance_id,
            instance_group_name:     instance_group_name,
            prefer_dns_entry:        prefer_dns_entry,
            link_group_name:         link_group_name,
            network_ip:              '10.1.0.6',
            network_name:            'net_b',
            network_type:            'manual',
          ).and_return encoded_net_b
        end

        describe '#network_address' do
          it 'returns the address for the default network' do
            expect(network_settings.network_address(link_group_name, prefer_dns_entry)).to eq(encoded_net_a)
          end

          it 'returns the instance_group address for the default network' do
            expect(network_settings.instance_group_network_address(prefer_dns_entry)).to eq(ig_encoded_net_a)
          end
        end

        describe '#network_addresses' do
          it 'returns network_addresses for all networks for the instance' do
            expect(network_settings.network_addresses(link_group_name, prefer_dns_entry)).to eq(
              'net_a' => encoded_net_a,
              'net_b' => encoded_net_b,
            )
          end
        end
      end
    end
  end
end
