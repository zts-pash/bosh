require 'common/deep_copy'

module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class BruteForceIpAllocation
          def initialize(networks_to_static_ips)
            @networks_to_static_ips = networks_to_static_ips
          end

          def find_best_combination
            Enumerator.new do |e|
              try_combination(@networks_to_static_ips, e)
            end.each do |networks_to_static_ips|
              if all_ips_belong_to_single_az(networks_to_static_ips)
                if even_distribution_of_ips?(networks_to_static_ips)
                  return networks_to_static_ips
                end
              end
            end
            return nil
          end

          private

          def try_combination(networks_to_static_ips, e)
            e << networks_to_static_ips

            network_iterator(networks_to_static_ips) do |allocated_ips, static_ip_to_azs|
              candidate_iterator(allocated_ips, static_ip_to_azs, networks_to_static_ips) do |candidate_networks_to_static_ips|
                result = try_combination(candidate_networks_to_static_ips, e)
                next if result.nil?
                return result
              end
            end

            return nil
          end

          def candidate_iterator(allocated_ips, static_ip_to_azs, networks_to_static_ips)
            # prioritize AZs based on least number of allocated IPs
            sorted_az_names = allocated_ips.sort_by_least_allocated_ips(static_ip_to_azs.az_names)
            sorted_az_names.each do |az_name|
              static_ip_to_azs.az_names = [az_name]
              allocated_ips.allocate(az_name)
              yield networks_to_static_ips
            end
          end

          def network_iterator(networks_to_static_ips)
            allocated_ips = AllocatedIps.new
            networks_to_static_ips.each do |_, static_ips_to_azs|
              static_ips_to_azs.each_with_index do |static_ip_to_azs|
                if static_ip_to_azs.az_names.size == 1
                  allocated_ips.allocate(static_ip_to_azs.az_names.first)
                  next
                end

                yield allocated_ips, static_ip_to_azs
              end
            end
          end

          def even_distribution_of_ips?(networks_to_static_ips)
            hash = {}
            networks_to_static_ips.each do |network, static_ips_to_azs|
              hash[network] ||= {}
              static_ips_to_azs.each do |static_ip_to_azs|
                static_ip_to_azs.az_names.each do |az_name|
                  hash[network][az_name] ||= 0
                  hash[network][az_name] += 1
                end
              end

            end

            hash.values.uniq.size > 1 ? false : true
          end

          def all_ips_belong_to_single_az(networks_to_static_ips)
            !networks_to_static_ips.values.any? do |static_ips_to_azs|
              static_ips_to_azs.any? do |static_ip_to_az|
                static_ip_to_az.az_names.size > 1
              end
            end
          end

          class AllocatedIps
            def initialize
              @allocated_ips = Hash.new {|h,k| h[k] = 0 }
            end

            def allocate(az_name)
              @allocated_ips[az_name] += 1
            end

            def sort_by_least_allocated_ips(az_names)
              az_names.sort_by do |az_name|
                @allocated_ips[az_name]
              end
            end
          end

          class PreviousAssignment
            def initialize(network_to_static_ips)
              @previous_assignment = Hash.new {|h,k| h[k] = 0 }
              network_to_static_ips.each do |previous_assignment_ip|
                @previous_assignment[previous_assignment_ip.az_names.first] += 1
              end
            end

            def has_same_distribution?(static_ips_to_azs)
              @previous_assignment.each do |az_name, required_number_of_ips_in_az|
                ips_in_az = static_ips_to_azs.select { |static_ip_to_azs| static_ip_to_azs.az_names.include?(az_name) }
                if ips_in_az.size < required_number_of_ips_in_az
                  return false
                end
              end

              return true
            end
          end
        end
      end
    end
  end
end

