require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe FeatureConfiguredDNSEncoder do
      subject(:feature_configured_dns_encoder) do
        FeatureConfiguredDNSEncoder.new(
          root_domain: root_domain,
          deployment_name: deployment_name,
          use_short_dns_addresses: use_short_dns_addresses,
          use_link_address: use_link_address,
        )
      end

      let(:root_domain)              { Sham.domain }
      let(:deployment_name)          { Sham.name }
      let(:link_group_name)          { Sham.name }
      let(:instance_group_name)      { Sham.name }
      let(:instance_id)              { Sham.uuid }
      let(:network_ip)               { Sham.ip }
      let(:network_name)             { Sham.name }
      let(:prefer_dns_entry)         { true }
      let(:use_short_dns_addresses)  { true }
      let(:config_local_dns_enabled) { true }
      let(:use_link_address)         { true }

      let(:local_dns_encoder)        { instance_double(Bosh::Director::DnsEncoder) }

      before do
        allow(LocalDnsEncoderManager).to receive(:create_dns_encoder).with(true).and_return local_dns_encoder
        allow(Config).to receive(:local_dns_enabled?).and_return config_local_dns_enabled
      end

      context 'when network type is dynamic' do
        let(:network_type) { 'dynamic' }

        context 'when use_link_address is true' do
          let(:use_link_address) { true }

          it('should encode the link group name') do
            allow(local_dns_encoder).to receive(:encode_query).with(
              group_type: Models::LocalDnsEncodedGroup::Types::LINK,
              group_name: link_group_name,
              root_domain: root_domain,
              default_network: network_name,
              deployment_name: deployment_name,
              uuid: instance_id,
            ).and_return(:encoded)

            expect(
              subject.encode(
                prefer_dns_entry: prefer_dns_entry,
                network_name: network_name,
                network_type: network_type,
                link_group_name: link_group_name,
                instance_group_name: instance_group_name,
                instance_id: instance_id,
                network_ip: network_ip,
              ),
            ).to eq(:encoded)
          end
        end

        context 'when use_link_address is false' do
          let(:use_link_address)         { false }

          it('should encode the instance group name') do
            allow(local_dns_encoder).to receive(:encode_query).with(
              group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
              group_name: instance_group_name,
              root_domain: root_domain,
              default_network: network_name,
              deployment_name: deployment_name,
              uuid: instance_id,
            ).and_return(:encoded)

            expect(
              subject.encode(
                prefer_dns_entry: prefer_dns_entry,
                network_name: network_name,
                network_type: network_type,
                link_group_name: link_group_name,
                instance_group_name: instance_group_name,
                instance_id: instance_id,
                network_ip: network_ip,
              ),
            ).to eq(:encoded)
          end
        end
      end

      context 'when network type is non-dynamic' do
        let(:network_type) { Sham.name }

        context 'when prefer DNS entry is true' do
          let(:prefer_dns_entry) { true }

          context 'when config_local_dns_enabled is true' do
            let(:config_local_dns_enabled) { true }

            context 'when use_link_address is true' do
              let(:use_link_address) { true }

              it('should encode the link group name') do
                allow(local_dns_encoder).to receive(:encode_query).with(
                  group_type: Models::LocalDnsEncodedGroup::Types::LINK,
                  group_name: link_group_name,
                  root_domain: root_domain,
                  default_network: network_name,
                  deployment_name: deployment_name,
                  uuid: instance_id,
                ).and_return(:encoded)

                expect(
                  subject.encode(
                    prefer_dns_entry: prefer_dns_entry,
                    network_name: network_name,
                    network_type: network_type,
                    link_group_name: link_group_name,
                    instance_group_name: instance_group_name,
                    instance_id: instance_id,
                    network_ip: network_ip,
                  ),
                ).to eq(:encoded)
              end
            end

            context 'when use_link_address is false' do
              let(:use_link_address) { false }

              it('should encode the instance group name') do
                allow(local_dns_encoder).to receive(:encode_query).with(
                  group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
                  group_name: instance_group_name,
                  root_domain: root_domain,
                  default_network: network_name,
                  deployment_name: deployment_name,
                  uuid: instance_id,
                ).and_return(:encoded)

                expect(
                  subject.encode(
                    prefer_dns_entry: prefer_dns_entry,
                    network_name: network_name,
                    network_type: network_type,
                    link_group_name: link_group_name,
                    instance_group_name: instance_group_name,
                    instance_id: instance_id,
                    network_ip: network_ip,
                  ),
                ).to eq(:encoded)
              end
            end
          end

          context 'when config_local_dns_enabled is false' do
            let(:config_local_dns_enabled) { false }

            it 'should return the network IP' do
              expect(
                subject.encode(
                  prefer_dns_entry: prefer_dns_entry,
                  network_name: network_name,
                  network_type: network_type,
                  link_group_name: link_group_name,
                  instance_group_name: instance_group_name,
                  instance_id: instance_id,
                  network_ip: network_ip,
                ),
              ).to eq(network_ip)
            end
          end
        end

        context 'when prefer DNS entry is false' do
          let(:prefer_dns_entry) { false }

          it 'should return the network IP' do
            expect(
              subject.encode(
                prefer_dns_entry: prefer_dns_entry,
                network_name: network_name,
                network_type: network_type,
                link_group_name: link_group_name,
                instance_group_name: instance_group_name,
                instance_id: instance_id,
                network_ip: network_ip,
              ),
            ).to eq(network_ip)
          end
        end
      end
    end
  end
end
