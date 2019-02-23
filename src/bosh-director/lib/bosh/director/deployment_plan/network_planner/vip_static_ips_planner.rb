module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class VipStaticIpsPlanner
      def initialize(network_planner, logger)
        @network_planner = network_planner
        @logger = logger
      end

      def add_vip_network_plans(instance_plans, vip_networks)
        vip_networks.each do |vip_network|
          static_ips = vip_network.static_ips.dup || []

          unplaced_instance_plans = []
          instance_plans.each do |instance_plan|
            static_ip = get_instance_static_ip(instance_plan.existing_instance, vip_network, static_ips)
            if static_ip
              instance_plan.network_plans << @network_planner.network_plan_with_static_reservation(instance_plan, vip_network, static_ip)
            else
              unplaced_instance_plans << instance_plan
            end
          end

          unplaced_instance_plans.each do |instance_plan|
            static_ip = if vip_network.managed_vip?
                          # TODO: think about if we can put in a placeholder here to move ip creation to another place (e.g. right before vm creation)
                          cloud = Bosh::Director::CloudFactory.create.get('') # TODO pull cpi name from instance plan's [desired] AZ
                          cloud.create_external_ip
                        else
                          # pull from unmanaged static ip pool
                          static_ips.shift
                        end
            raise "Failed to do something with IPS #{vip_network.pretty_inspect}" unless static_ip
            instance_plan.network_plans << @network_planner.network_plan_with_static_reservation(instance_plan, vip_network, static_ip)
          end
        end
      end

      private

      def get_instance_static_ip(existing_instance, network, static_ips)
        if existing_instance
          existing_instance_ip = find_ip_for_network(existing_instance, network.name)
          if existing_instance_ip && (static_ips.include?(existing_instance_ip) || network.managed_vip?)
            static_ips.delete(existing_instance_ip)
            return existing_instance_ip
          end
        end
      end

      def find_ip_for_network(existing_instance, network_name)
        ip_address = existing_instance.ip_addresses.find do |ip_address|
          ip_address.network_name == network_name
        end
        ip_address.address if ip_address
      end
    end
  end
end
