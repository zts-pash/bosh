module Bosh::Director
  class InstanceGroupUpdaterFactory
    def initialize(logger, template_blob_cache, dns_encoder, link_provider_intents)
      @logger = logger
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
      @link_provider_intents = link_provider_intents
    end

    def new_instance_group_updater(ip_provider, instance_group)
      InstanceGroupUpdater.new(ip_provider: ip_provider,
                               instance_group: instance_group,
                               disk_manager: DiskManager.new(@logger),
                               template_blob_cache: @template_blob_cache,
                               dns_encoder: @dns_encoder,
                               link_provider_intents: @link_provider_intents)
    end
  end
end
