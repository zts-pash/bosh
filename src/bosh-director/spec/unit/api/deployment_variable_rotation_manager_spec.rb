require 'spec_helper'

module Bosh::Director::Api
  describe DeploymentVariableRotationManager do
    subject { described_class.new(manifest_variables, deployment_name) }
    let(:deployment_name) { 'deployment-name' }
    let(:manifest_variables) do
      [
        {
          'name' => '/my_absolute_ca',
          'type' => 'certificate',
          'options' => {
            'is_ca' => true,
          }
        },
        {
          'name' => '/my_absolute_leaf',
          'type' => 'certificate',
          'options' => {
            'ca' => '/my_absolute_ca',
          },
        },
        {
          'name' => 'my_ca',
          'type' => 'certificate',
          'options' => {
            'is_ca' => true,
          },
        },
        {
          'name' => 'my_leaf',
          'type' => 'certificate',
          'options' => {
            'ca' => 'my_ca',
          },
        },
        {
          'name' => 'my_password',
          'type' => 'password',
        },
        {
          'name' => 'my_intermediate_ca',
          'type' => 'certificate',
          'options' => {
            'is_ca' => true,
            'ca' => 'my_ca',
          },
        },
        {
          'name' => 'my_intermediate_leaf',
          'type' => 'certificate',
          'options' => {
            'ca' => 'my_intermediate_ca',
          },
        },
        {
          'name' => '/my_absolute_intermediate_ca',
          'type' => 'certificate',
          'options' => {
            'is_ca' => true,
            'ca' => '/my_absolute_ca',
          },
        },
        {
          'name' => '/my_absolute_intermediate_leaf',
          'type' => 'certificate',
          'options' => {
            'ca' => '/my_absolute_intermediate_ca',
          },
        },
        {
          'name' => 'my_random_type',
          'type' => 'random_type',
        },
        {
          'name' => 'my_rsa_keys',
          'type' => 'rsa',
        },
      ]
    end
    let(:mock_config_server) { instance_double(Bosh::Director::ConfigServer::ConfigServerClient) }

    before(:each) do
      Bosh::Director::Config.name = 'Test Director'
      allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create_default_client).and_return(mock_config_server)
    end

    context 'impacted certificates' do
      it 'lists leaf certificates when requested' do
        expect(subject.deployment_leaf_certificates).to match_array(
          [
            {
              'type' => 'variable',
              'name' => '/my_absolute_leaf',
            },
            {
              'name' => '/Test Director/deployment-name/my_intermediate_leaf',
              'type' => 'variable',
            },
            {
              'name' => '/Test Director/deployment-name/my_leaf',
              'type' => 'variable',
            },
            {
              'type' => 'variable',
              'name' => '/my_absolute_intermediate_leaf',
            },
          ],
        )
      end

      it 'lists CA certificates when requested' do
        expect(subject.deployment_ca_certificates).to match_array(
          [
            {
              'type' => 'variable',
              'name' => '/my_absolute_ca',
            },
            {
              'name' => '/my_absolute_intermediate_ca',
              'type' => 'variable',
            },
            {
              'name' => '/Test Director/deployment-name/my_intermediate_ca',
              'type' => 'variable',
            },
            {
              'type' => 'variable',
              'name' => '/Test Director/deployment-name/my_ca',
            },
          ],
        )
      end
    end

    context 'generate' do
      let(:manifest_variables) do
        [
          {
            'name' => 'my_ca',
            'type' => 'certificate',
            'options' => {
              'is_ca' => true,
              'common_name' => 'cn',
            },
          },
          {
            'name' => 'my_leaf',
            'type' => 'certificate',
            'options' => {
              'ca' => 'my_ca',
              'common_name' => 'cn',
            },
          },
          {
            'name' => 'password',
            'type' => 'password',
          },
        ]
      end

      context 'leaf certs' do
        it 'regenerates only leaf certificates' do
          expect(mock_config_server).to receive(:force_regenerate_value).with(
            '/Test Director/deployment-name/my_leaf',
            'certificate',
            'ca' => '/Test Director/deployment-name/my_ca', 'common_name' => 'cn',
          )

          regenerated_certs = subject.regenerate_leaf_certificates
          expect(regenerated_certs).to match_array(
            [
              {
                'type' => 'variable',
                'name' => '/Test Director/deployment-name/my_leaf'
              },
            ],
          )
        end

        context 'CAs' do
          it 'generates a new CA' do
            expect(mock_config_server).to receive(:regenerate_transitional_ca).with(
              '/Test Director/deployment-name/my_ca',
            )

            transitional_ca_certs = subject.generate_transitional_cas
            expect(transitional_ca_certs).to match_array(
              [
                {
                  'name' => '/Test Director/deployment-name/my_ca',
                  'type' => 'variable',
                },
              ],
            )
          end
        end
      end
    end
  end
end
