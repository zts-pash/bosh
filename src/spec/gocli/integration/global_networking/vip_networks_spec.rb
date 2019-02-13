require_relative '../../spec_helper'

describe 'vip networks', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['networks'] << {
      'name' => 'vip-network',
      'type' => 'vip',
    }
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['69.69.69.69']}
    ]
    manifest_hash
  end

  let(:updated_simple_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 2
    manifest_hash['instance_groups'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['68.68.68.68', '69.69.69.69']}
    ]
    manifest_hash
  end

  it 'reuses instance vip network IP on subsequent deploy', no_create_swap_delete: true do
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: simple_manifest)
    original_instances = director.instances
    expect(original_instances.size).to eq(1)
    expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

    cloud_config_hash['networks'][1]['static_ips'] = ['68.68.68.68', '69.69.69.69']
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: updated_simple_manifest)
    new_instances = director.instances
    expect(new_instances.size).to eq(2)
    instance_with_original_vip_ip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
    expect(instance_with_original_vip_ip.id).to eq(original_instances.first.id)
  end

  context 'when using shared vip network static ip subnets' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['networks'] << {
          'name' => 'vip-network',
          'type' => 'vip',
          'subnets' => ['static' => ['69.69.69.69']],
      }
      cloud_config_hash
    end

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['networks'] = [
          {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
          {'name' => 'vip-network'}
      ]
      manifest_hash
    end

    let(:updated_simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [
          {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
          {'name' => 'vip-network'}
      ]
      manifest_hash
    end

    it 'reuses instance vip network IP on subsequent deploy', no_create_swap_delete: true do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest)
      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

      cloud_config_hash['networks'][1]['subnets'][0]['static'] = ['68.68.68.68', '69.69.69.69']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: updated_simple_manifest)
      new_instances = director.instances
      expect(new_instances.size).to eq(2)
      instance_with_original_vip_ip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
      expect(instance_with_original_vip_ip.id).to eq(original_instances.first.id)
    end

    context 'when there are two deployments' do
      it 'does not reuse instance vip network IP on separate deployment' do
        cloud_config_hash['networks'][1]['subnets'][0]['static'] = ['68.68.68.68', '69.69.69.69']

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)
        original_instances = director.instances
        expect(original_instances.size).to eq(1)
        expect(original_instances.first.ips).to eq(['192.168.1.2', '68.68.68.68'])

        second_deployment = simple_manifest.dup
        second_deployment['name'] = 'second'

        deploy_simple_manifest(manifest_hash: second_deployment)
        new_instances = director.instances(deployment_name: 'second')
        expect(new_instances.size).to eq(1)
        expect(new_instances.first.ips).to eq(['192.168.1.3', '69.69.69.69'])
      end

      it 'does not reuse instance vip network IP on a redeploy' do
        cloud_config_hash['networks'][1]['subnets'][0]['static'] = ['68.68.68.68', '69.69.69.69']
        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        deploy_simple_manifest(manifest_hash: simple_manifest)
        original_instances = director.instances
        expect(original_instances.size).to eq(1)
        expect(original_instances.first.ips).to eq(['192.168.1.2', '68.68.68.68'])

        cloud_config_hash['networks'][1]['subnets'][0]['static'] = ['69.69.69.69', '68.68.68.68']
        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        deploy_simple_manifest(manifest_hash: simple_manifest)
        original_instances = director.instances
        expect(original_instances.size).to eq(1)
        expect(original_instances.first.ips).to eq(['192.168.1.2', '68.68.68.68'])
      end

      context 'multiple azs' do
        let(:cloud_config_hash) do
          cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs
          cloud_config_hash['networks'] << {
              'name' => 'vip-network',
              'type' => 'vip',
              'subnets' => [
                  {
                      'azs' => ['z1'],
                      'static' => ['68.68.68.68', '69.69.69.69'],
                  },
                  {
                      'azs' => ['z2'],
                      'static' => ['78.78.78.78', '79.79.79.79'],
                  },
              ],
          }
          cloud_config_hash
        end

        let(:simple_manifest) do
          manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups(azs: ['z2'])
          manifest_hash['instance_groups'].first['instances'] = 1
          manifest_hash['instance_groups'].first['networks'] = [
              {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
              {'name' => 'vip-network'}
          ]
          manifest_hash
        end

        it 'does not reuse instance vip network IP on a redeploy' do
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          deploy_simple_manifest(manifest_hash: simple_manifest)
          original_instances = director.instances
          expect(original_instances.size).to eq(1)
          expect(original_instances.first.ips).to eq(['192.168.2.2', '78.78.78.78'])
        end
      end
    end
  end
end
