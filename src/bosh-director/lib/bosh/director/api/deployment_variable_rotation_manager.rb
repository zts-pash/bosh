module Bosh::Director
  module Api
    class DeploymentVariableRotationManager
      def initialize(manifest_variables, deployment_name)
        @variables = manifest_variables
        @deployment_name = deployment_name
        @config_server_client = Bosh::Director::ConfigServer::ClientFactory.create_default_client
      end

      def regenerate_leaf_certificates
        regenerated = []
        variable_leaf_certificates.each do |leaf|
          absolute_name = absolute_variable_name(leaf['name'])
          absolute_ca_name = absolute_variable_name(leaf['options']['ca'])
          leaf['options']['ca'] = absolute_ca_name
          @config_server_client.force_regenerate_value(absolute_name, leaf['type'], leaf['options'])
          regenerated << { 'name' => absolute_name, 'type' => 'variable' }
        end
        regenerated
      end

      def generate_transitional_cas
        generated_transitional = []
        variable_ca_certificates.each do |ca|
          abs_name = absolute_variable_name(ca['name'])
          ca['options']['ca'] = absolute_variable_name(ca['options']['ca']) if ca['options']['ca']
          @config_server_client.regenerate_transitional_ca(abs_name)
          generated_transitional << { 'name' => abs_name, 'type' => 'variable' }
        end
        generated_transitional
      end

      def deployment_leaf_certificates
        variable_leaf_certificates.map do |leaf|
          { 'name' => absolute_variable_name(leaf['name']), 'type' => 'variable' }
        end
      end

      def deployment_ca_certificates
        variable_ca_certificates.map do |ca|
          { 'name' => absolute_variable_name(ca['name']), 'type' => 'variable' }
        end
      end

      private

      def variable_ca_certificates
        @variables.select { |v| v['type'] == 'certificate' && v['options']['is_ca'] }
      end

      def variable_leaf_certificates
        @variables.select { |v| v['type'] == 'certificate' && !v['options']['is_ca'] }
      end

      def absolute_variable_name(name)
        Bosh::Director::ConfigServer::ConfigServerHelper.add_prefix_if_not_absolute(
          name,
          Bosh::Director::Config.name,
          @deployment_name,
        )
      end
    end
  end
end
