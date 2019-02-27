require 'spec_helper'

module Bosh::Director
  module Addon
    describe Addon, truncation: true do
      subject(:addon) { Addon.new(addon_name, jobs, properties, includes, excludes) }
      let(:addon_name) { 'addon-name' }
      let(:jobs) do
        [
          { 'name' => 'dummy_with_properties',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => [] },
          { 'name' => 'dummy_with_package',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => [] },
        ]
      end
      let(:properties) do
        { 'echo_value' => 'addon_prop_value' }
      end

      let(:cloud_configs) { [Models::Config.make(:cloud_with_manifest_v2)] }

      let(:teams) do
        Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(
          %w[bosh.teams.team_1.admin bosh.teams.team_3.admin],
        )
      end

      let(:deployment_model) do
        deployment_model = Models::Deployment.make
        deployment_model.teams = teams
        deployment_model.cloud_configs = cloud_configs
        deployment_model.save
        deployment_model
      end

      let!(:variable_set) { Models::VariableSet.make(deployment: deployment_model) }

      let(:deployment_name) { 'dep1' }

      let(:manifest_hash) do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['name'] = deployment_name
        manifest_hash
      end

      let(:deployment) do
        planner = DeploymentPlan::Planner.new(
          { name: deployment_name, properties: {} },
          manifest_hash,
          YAML.dump(manifest_hash),
          cloud_configs,
          {},
          deployment_model,
        )
        planner.update = DeploymentPlan::UpdateConfig.new(manifest_hash['update'])
        planner
      end

      let(:includes) { Filter.parse(include_spec, :include) }
      let(:excludes) { Filter.parse(exclude_spec, :exclude) }

      let(:exclude_spec) { nil }
      let(:include_spec) { nil }

      describe '#add_to_deployment' do
        let(:include_spec) do
          { 'deployments' => [deployment_name] }
        end
        let(:instance_group) do
          instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
          jobs = [{ 'name' => 'dummy', 'release' => 'dummy' }]
          instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: jobs, azs: ['z1']), {})
        end
        let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
        let(:release_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model) }

        let(:dummy_template_spec) do
          {
            'provides' => [
              {
                'name' => 'provided_links_101',
                'type' => 'type_101',
              },
            ],
            'consumes' => [
              {
                'name' => 'consumed_links_102',
                'type' => 'type_102',
              },
            ],
          }
        end

        let(:dummy_with_properties_template_spec) do
          {
            'provides' => [
              {
                'name' => 'provided_links_1',
                'type' => 'type_1',
              },
              {
                'name' => 'provided_links_2',
                'type' => 'type_2',
              },
            ],
            'consumes' => [
              {
                'name' => 'consumed_links_3',
                'type' => 'type_3',
              },
              {
                'name' => 'consumed_links_4',
                'type' => 'type_4',
              },
            ],
          }
        end

        let(:dummy_with_properties_template) do
          Bosh::Director::Models::Template.make(
            name: 'dummy_with_properties',
            release: release_model,
            spec_json: dummy_with_properties_template_spec.to_json,
          )
        end

        let(:dummy_with_packages_template) do
          Bosh::Director::Models::Template.make(name: 'dummy_with_package', release: release_model)
        end

        before do
          release_version_model.add_template(
            Bosh::Director::Models::Template.make(
              name: 'dummy',
              release: release_model,
              spec_json: dummy_template_spec.to_json,
            ),
          )
          release_version_model.add_template(dummy_with_properties_template)
          release_version_model.add_template(dummy_with_packages_template)

          release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
          deployment.add_release(release)
          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
            Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs,
            DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
            DeploymentPlan::IpProviderFactory.new(true, logger),
          )

          deployment.add_instance_group(instance_group)
          allow(deployment_model).to receive(:current_variable_set).and_return(variable_set)
        end

        context 'when addon does not apply to the instance group' do
          let(:include_spec) do
            { 'deployments' => ['no_findy'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon does not apply to the deployment teams' do
          let(:include_spec) do
            { 'teams' => ['team_2'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon applies to instance group' do
          let(:links_parser) do
            instance_double(Bosh::Director::Links::LinksParser)
          end

          it 'adds addon to instance group' do
            addon.add_to_deployment(deployment)
            deployment_instance_group = deployment.instance_group(instance_group.name)
            expect(deployment_instance_group.jobs.map(&:name)).to eq(%w[dummy dummy_with_properties dummy_with_package])
          end

          it 'parses links using LinksParser' do
            allow(Bosh::Director::Links::LinksParser).to receive(:new).and_return(links_parser)

            expect(links_parser).to receive(:parse_providers_from_job).with(
              jobs[0],
              deployment_model,
              dummy_with_properties_template,
              job_properties: properties,
              instance_group_name: 'foobar',
            )
            expect(links_parser).to receive(:parse_consumers_from_job).with(
              jobs[0],
              deployment_model,
              dummy_with_properties_template,
              instance_group_name: 'foobar',
            )

            expect(links_parser).to receive(:parse_providers_from_job).with(
              jobs[1],
              deployment_model,
              dummy_with_packages_template,
              job_properties: properties,
              instance_group_name: 'foobar',
            )
            expect(links_parser).to receive(:parse_consumers_from_job).with(
              jobs[1],
              deployment_model,
              dummy_with_packages_template,
              instance_group_name: 'foobar',
            )

            addon.add_to_deployment(deployment)
          end

          context 'when there is another instance group which is excluded' do
            let(:exclude_spec) do
              { 'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }] }
            end

            before do
              instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
              jobs = [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }]
              instance_group = instance_group_parser.parse(
                Bosh::Spec::Deployments.simple_job(
                  name: 'excluded_ig',
                  jobs: jobs,
                  azs: ['z1'],
                ),
                {}
              )
              deployment.add_instance_group(instance_group)
            end

            it 'should not parse providers and consumers for excluded instance group' do
              links_parser = instance_double(Bosh::Director::Links::LinksParser)

              allow(Bosh::Director::Links::LinksParser).to receive(:new).and_return(links_parser)
              allow(links_parser).to receive(:parse_providers_from_job)
              allow(links_parser).to receive(:parse_consumers_from_job)

              expect(links_parser).to_not receive(:parse_providers_from_job).with(
                anything, anything, anything, job_properties: anything, instance_group_name: 'excluded_ig'
              )
              expect(links_parser).to_not receive(:parse_consumers_from_job).with(
                anything, anything, anything, instance_group_name: 'excluded_ig'
              )

              addon.add_to_deployment(deployment)
            end
          end

          context 'when addon job specified does not exist in release' do
            let(:jobs) do
              [
                { 'name' => 'non-existing-job',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [] },
                { 'name' => 'dummy_with_package',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [] },
              ]
            end

            it 'throws an error' do
              expect do
                addon.add_to_deployment(deployment)
              end.to raise_error Bosh::Director::DeploymentUnknownTemplate, /Can't find job 'non-existing-job'/
            end
          end

          context 'none of the addon jobs have job level properties' do
            context 'when the addon has properties' do
              it 'adds addon properties to addon job' do
                addon.add_to_deployment(deployment)

                expect(instance_group.jobs[1].properties).to eq('foobar' => properties)
                expect(instance_group.jobs[2].properties).to eq('foobar' => properties)
              end
            end

            context 'when the addon has no addon level properties' do
              let(:properties) do
                {}
              end

              it 'adds empty properties to addon job to avoid override by instance group or manifest level properties' do
                added_jobs = []
                expect(instance_group).to(receive(:add_job)) { |job| added_jobs << job }.twice
                addon.add_to_deployment(deployment)

                expect(added_jobs[0].properties).to eq('foobar' => {})
                expect(added_jobs[1].properties).to eq('foobar' => {})
              end
            end
          end

          context 'when the addon jobs have job level properties' do
            let(:jobs) do
              [
                { 'name' => 'dummy_with_properties',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [],
                  'properties' => { 'job' => 'properties' } },
              ]
            end

            it 'does not overwrite jobs properties with addon properties' do
              expect(instance_group).to(receive(:add_job)) do |added_job|
                expect(added_job.properties).to eq('foobar' => { 'job' => 'properties' })
              end
              addon.add_to_deployment(deployment)
            end
          end
        end

        context 'when the addon has deployments in include and jobs in exclude' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          let(:exclude_spec) do
            { 'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy' }] }
          end

          it 'adds filtered jobs only' do
            expect(instance_group).not_to receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon does not apply to the availability zones' do
          let(:include_spec) do
            { 'azs' => ['z3'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end
      end

      describe '#parse' do
        context 'when name, jobs, include, and properties' do
          let(:include_hash) do
            { 'jobs' => [], 'properties' => [] }
          end
          let(:addon_hash) do
            {
              'name' => 'addon-name',
              'jobs' => jobs,
              'properties' => properties,
              'include' => include_hash,
            }
          end

          it 'returns addon' do
            expect(Filter).to receive(:parse).with(include_hash, :include, RUNTIME_LEVEL)
            expect(Filter).to receive(:parse).with(nil, :exclude, RUNTIME_LEVEL)
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(2)
            expect(addon.jobs.map { |job| job['name'] }).to eq(%w[dummy_with_properties dummy_with_package])
            expect(addon.properties).to eq(properties)
          end
        end

        context 'when jobs, properties and include are empty' do
          let(:addon_hash) do
            { 'name' => 'addon-name' }
          end

          it 'returns addon' do
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(0)
            expect(addon.properties).to be_nil
          end
        end

        context 'when jobs, properties and include are empty' do
          let(:addon_hash) do
            { 'name' => 'addon-name' }
          end

          it 'returns addon' do
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(0)
            expect(addon.properties).to be_nil
          end
        end

        context 'when name is empty' do
          let(:addon_hash) do
            { 'jobs' => ['addon-name'] }
          end

          it 'errors' do
            error_string = "Required property 'name' was not specified in object ({\"jobs\"=>[\"addon-name\"]})"
            expect { Addon.parse(addon_hash) }.to raise_error(ValidationMissingField, error_string)
          end
        end
      end

      describe '#applies?' do
        context 'when the addon is applicable by deployment name' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          let(:deployment_instance_group) do
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by deployment name' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          let(:deployment_instance_group) do
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          end

          it 'does not apply' do
            expect(addon.applies?('blarg', [], nil)).to eq(false)
          end
        end

        context 'when the addon is applicable by team' do
          let(:include_spec) do
            { 'teams' => ['team_1'] }
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by team' do
          let(:include_spec) do
            { 'teams' => ['team_5'] }
          end

          it 'does not apply' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(false)
          end
        end

        context 'when the addon has empty include' do
          let(:include_spec) do
            {}
          end
          let(:deployment_instance_group) do
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon has empty include and exclude' do
          let(:include_spec) do
            {}
          end
          let(:exclude_spec) do
            {}
          end
          let(:deployment_instance_group) do
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon only excludes' do
          context 'when excluding both job and deployment' do
            let(:exclude_spec) do
              {
                'deployments' => [excluded_deployment_name],
                'jobs' => [{ 'name' => 'excluded_job', 'release' => 'excluded_job_release' }],
              }
            end

            let(:included_instance_group) do
              double(Bosh::Director::DeploymentPlan, has_job?: false)
            end

            let(:excluded_instance_group) do
              excluded = double(Bosh::Director::DeploymentPlan)
              allow(excluded).to receive(:has_job?)
                .with('excluded_job', 'excluded_job_release')
                .and_return(true)
              excluded
            end

            let(:deployment_teams) { [] }

            let(:excluded_deployment_name) { 'excluded_deployment' }
            let(:included_deployment_name) { 'included_deployment' }

            it 'excludes based on deployment or job' do
              expect(
                addon.applies?(
                  excluded_deployment_name,
                  deployment_teams,
                  included_instance_group,
                ),
              ).to eq(true)
              expect(
                addon.applies?(
                  included_deployment_name,
                  deployment_teams,
                  excluded_instance_group,
                ),
              ).to eq(true)
              expect(
                addon.applies?(
                  excluded_deployment_name,
                  deployment_teams,
                  excluded_instance_group,
                ),
              ).to eq(false)
            end
          end
        end

        context 'when the addon has include and exclude' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          context 'when they are the same' do
            let(:exclude_spec) do
              { 'deployments' => [deployment_name] }
            end
            let(:deployment_instance_group) do
              instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
              instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
            end

            it 'does not apply' do
              expect(addon.applies?(deployment_name, [], nil)).to eq(false)
            end
          end

          context 'when include is for deployment and exclude is for job' do
            let(:exclude_spec) do
              { 'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy' }] }
            end
            let(:instance_group_parser) { DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger) }
            let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
            let(:release_version_model) do
              Bosh::Director::Models::ReleaseVersion.make(
                version: '0.2-dev', release: release_model,
              )
            end

            before do
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))
              release_version_model.add_template(
                Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model),
              )

              release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
              deployment.add_release(release)
              stemcell = DeploymentPlan::Stemcell.parse(manifest_hash['stemcells'].first)
              deployment.add_stemcell(stemcell)
              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
                Bosh::Spec::NewDeployments.simple_cloud_config,
                DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                DeploymentPlan::IpProviderFactory.new(true, logger),
              )
              instance_group1 = instance_group_parser.parse(
                Bosh::Spec::NewDeployments.simple_instance_group(jobs: [{ 'name' => 'dummy', 'release' => 'dummy' }]),
                {},
              )
              deployment.add_instance_group(instance_group1)
              instance_group2 = instance_group_parser.parse(
                Bosh::Spec::NewDeployments.simple_instance_group(
                  jobs: [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }], name: 'foobar1',
                ),
                {},
              )
              deployment.add_instance_group(instance_group2)
            end

            it 'excludes specified job only' do
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(false)
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar1'))).to eq(true)
            end
          end

          context 'when the addon has availability zones' do
            let(:instance_group_parser) { DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger) }
            let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
            let(:release_version_model) do
              Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model)
            end

            before do
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))

              release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
              deployment.add_release(release)
              stemcell = DeploymentPlan::Stemcell.parse(manifest_hash['stemcells'].first)
              deployment.add_stemcell(stemcell)
              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
                Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs,
                DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                DeploymentPlan::IpProviderFactory.new(true, logger),
              )
              jobs = [{ 'name' => 'dummy', 'release' => 'dummy' }]
              instance_group = instance_group_parser.parse(
                Bosh::Spec::NewDeployments.simple_instance_group(jobs: jobs, azs: ['z1']),
                {},
              )
              deployment.add_instance_group(instance_group)
            end

            context 'when the addon is applicable by availability zones' do
              let(:include_spec) do
                { 'azs' => ['z1'] }
              end
              it 'it applies' do
                expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(true)
              end
            end

            context 'when the addon is not applicable by availability zones' do
              let(:include_spec) do
                { 'azs' => ['z5'] }
              end
              it 'does not apply' do
                expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(false)
              end
            end
          end
        end
      end

      describe '#releases' do
        it 'should only return unique releases' do
          expect(addon.releases).to match_array(['dummy'])
        end

        context 'there are no jobs' do
          let(:jobs) do
            []
          end

          it 'should return an empty array of releases' do
            expect(addon.releases).to be_empty
          end
        end
      end
    end
  end
end
