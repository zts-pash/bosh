require 'spec_helper'

describe 'multiple cloud configs', type: :integration do
  with_reset_sandbox_before_each

  let(:first_cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'] = [{ 'name' => 'a', 'cloud_properties' => { 'prop-key-a' => 'prop-val-a' } }]
    # cloud_config_hash['networks'][0]['default'] = %w[dns gateway]
    yaml_file('first-cloud-config', cloud_config_hash)
  end
  let(:second_cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'] = [{ 'name' => 'b', 'cloud_properties' => { 'prop-key-b' => 'prop-val-b' } }]
    cloud_config_hash.delete('compilation')
    cloud_config_hash.delete('networks')
    yaml_file('second-cloud-config', cloud_config_hash)
  end

  let(:vip_cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'] = [{ 'name' => 'vip-vm', 'cloud_properties' => { 'prop-key-vip' => 'prop-val-vip' } }]
    cloud_config_hash['networks'] = [{'name'=> 'vip-network', 'type' => 'vip', 'managed' => true}]
    cloud_config_hash.delete('compilation')
    yaml_file('vip-cloud-config', cloud_config_hash)
  end
  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group(name: 'second-foobar', vm_type: 'b')
    manifest_hash
  end

  before do
    create_and_upload_test_release
    upload_stemcell
    bosh_runner.run("update-config --name=first-cloud-config --type=cloud #{first_cloud_config.path}")
    bosh_runner.run("update-config --name=second-cloud-config --type=cloud #{second_cloud_config.path}")
  end

  context 'when VIP network is specifed' do
    before do
      bosh_runner.run("update-config --name=vip-cloud-config --type=cloud #{vip_cloud_config.path}")
    end
    it 'should add VIP network to the deployment' do
      manifest = manifest_hash
      manifest['instance_groups'][0]['instances'] = 1

      manifest['instance_groups'][0]['networks'] << { 'name' => 'vip-network'}
      manifest['instance_groups'][0]['networks'][0]['default'] = %w[dns gateway]
      output = deploy_simple_manifest(manifest_hash: manifest)
      puts output

      puts bosh_runner.run("is --details -d simple")
      puts bosh_runner.run("vms --vitals -d simple")
    end
    context 'if hotswap is enabled' do
      it 'should ignore hotsawp instances' do
        manifest = manifest_hash
        manifest['instance_groups'][0]['instances'] = 1

        manifest['instance_groups'][0]['networks'] << { 'name' => 'vip-network'}
        manifest['instance_groups'][0]['networks'][0]['default'] = %w[dns gateway]
        output = deploy_simple_manifest(manifest_hash: manifest)
        puts output

        puts bosh_runner.run("is --details -d simple")
        puts bosh_runner.run("vms --vitals -d simple")

        # update vm_strategy to perform hot-swap
        manifest['instance_groups'][0]['update'] = {
            'vm_strategy' => 'create-swap-delete',
        }
        output = deploy_simple_manifest(manifest_hash: manifest)

        puts "======================================================"
        puts bosh_runner.run("is --details -d simple")
        puts bosh_runner.run("vms --vitals -d simple")
      end
    end
  end

  it 'can use configuration from all the uploaded configs' do
    deploy_simple_manifest(manifest_hash: manifest_hash)

    create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    first_cloud_config_vms = create_vm_invocations.select do |i|
      i.inputs['cloud_properties'] == { 'prop-key-a' => 'prop-val-a' }
    end
    second_cloud_config_vms = create_vm_invocations.select do |i|
      i.inputs['cloud_properties'] == { 'prop-key-b' => 'prop-val-b' }
    end
    expect(first_cloud_config_vms.count).to eq(3)
    expect(second_cloud_config_vms.count).to eq(3)
  end

  context 'when teams are used' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    let(:production_env) do
      { 'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret' }
    end
    let(:admin_env) do
      { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret' }
    end
    let(:team_read_env) do
      { 'BOSH_CLIENT' => 'team-client-read-access', 'BOSH_CLIENT_SECRET' => 'team-secret' }
    end
    let(:team_admin_env) do
      { 'BOSH_CLIENT' => 'team-client', 'BOSH_CLIENT_SECRET' => 'team-secret' }
    end

    before do
      create_and_upload_test_release(client: admin_env['BOSH_CLIENT'], client_secret: admin_env['BOSH_CLIENT_SECRET'])
      upload_stemcell(client: admin_env['BOSH_CLIENT'], client_secret: admin_env['BOSH_CLIENT_SECRET'])
    end

    context 'when there are only team cloud configs' do
      let(:team1_cc) do
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
        yaml_file('team1_cc', cloud_config_hash)
      end
      let(:team2_cc) do
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
        yaml_file('team2_cc', cloud_config_hash)
      end
      let(:manifest_hash1) do
        Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge!('name' => 'team1manifest')
      end
      let(:manifest_hash2) do
        Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge!('name' => 'team2manifest')
      end

      before do
        bosh_runner.run(
          "update-config --name=my-cc --type=cloud #{team1_cc.path}",
          client: production_env['BOSH_CLIENT'],
          client_secret: production_env['BOSH_CLIENT_SECRET'],
        )
        bosh_runner.run(
          "update-config --name=my-cc1 --type=cloud #{team2_cc.path}",
          client: team_admin_env['BOSH_CLIENT'],
          client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
        )
      end

      it 'denies permission to upload same-named-configs to another team' do
        bosh_runner.run(
          "update-config --name=should-conflict --type=cloud #{team1_cc.path}",
          client: production_env['BOSH_CLIENT'],
          client_secret: production_env['BOSH_CLIENT_SECRET'],
        )
        output, = bosh_runner.run(
          "update-config --name=should-conflict --type=cloud #{team2_cc.path}",
          client: team_admin_env['BOSH_CLIENT'],
          client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
          failure_expected: true,
        )
        expect(output).to include("Director responded with non-successful status code '401'")
      end

      it "can deploy each team's configs without conflict" do
        deploy_simple_manifest(
          manifest_hash: manifest_hash1,
          client: production_env['BOSH_CLIENT'],
          client_secret: production_env['BOSH_CLIENT_SECRET'],
        )
        deploy_simple_manifest(
          manifest_hash: manifest_hash2,
          client: team_admin_env['BOSH_CLIENT'],
          client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
        )
      end
    end

    context 'when an admin/global cloud config is present' do
      let(:admin_cc) do
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
        yaml_file('admin_cc', cloud_config_hash)
      end

      let(:team_cc) do
        cloud_config_hash = { 'vm_types' => [{ 'name' => 'team_vm' }] }
        yaml_file('team_cc', cloud_config_hash)
      end

      let(:manifest_hash) do
        Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      end

      let(:team_manifest_hash) do
        m = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        m['instance_groups'][0]['vm_type'] = 'team_vm'
        m
      end

      before do
        bosh_runner.run(
          "update-config --name=admin_cc --type=cloud #{admin_cc.path}",
          client: admin_env['BOSH_CLIENT'],
          client_secret: admin_env['BOSH_CLIENT_SECRET'],
        )
        bosh_runner.run(
          "update-config --name=team_cc --type=cloud #{team_cc.path}",
          client: team_admin_env['BOSH_CLIENT'],
          client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
        )
      end

      context 'when deploying as an admin' do
        it 'will successfully deploy a simple manifest' do
          deploy_simple_manifest(
            manifest_hash: manifest_hash,
            client: admin_env['BOSH_CLIENT'],
            client_secret: admin_env['BOSH_CLIENT_SECRET'],
          )
        end

        it 'will fail when trying to use a team-specific cloud config resource' do
          output, = deploy_simple_manifest(
            manifest_hash: team_manifest_hash,
            client: admin_env['BOSH_CLIENT'],
            client_secret: admin_env['BOSH_CLIENT_SECRET'],
            failure_expected: true,
          )
          expect(output).to include("Error: Instance group 'foobar' references an unknown vm type 'team_vm'")
        end
      end

      context 'when deploying as team member' do
        it 'will successfully deploy with team-specific cloud config resources' do
          deploy_simple_manifest(
            manifest_hash: team_manifest_hash,
            client: team_admin_env['BOSH_CLIENT'],
            client_secret: team_admin_env['BOSH_CLIENT_SECRET'],
          )
        end
      end
    end
  end
end
