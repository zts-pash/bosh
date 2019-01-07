require 'open-uri'
require 'prometheus/client/model'

module Bosh::Director::Metrics
  module Prometheus
    class Client
      CONTENT_TYPE = 'application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited'.freeze

      def initialize(url)
        uri = URI.parse(url)
        @http = Net::HTTP.new(uri.hostname, uri.port)
        @collectors = {
          disk: DiskCollector.new('node_filesystem_free_bytes', 'node_filesystem_size_bytes'),
          load: LoadCollector.new('node_load1', 'node_load5', 'node_load15'),
          memory: MemoryCollector.new('node_memory_MemFree_bytes', 'node_memory_MemTotal_bytes'),
        }
      end

      def metrics
        response = @http.get('/metrics', 'Accept' => CONTENT_TYPE)
        buffer = Beefcake::Buffer.new(response.body)
        metrics = {}

        while (family = ::Prometheus::Client::MetricFamily.read_delimited(buffer))
          @collectors.each do |_, collector|
            collector.collect_family(family)
          end
        end

        disk_metrics = {}
        disk_collector = @collectors[:disk]
        disk_metrics['system'] = disk_collector.get_metric('mountpoint', '/')
        disk_metrics['ephemeral'] = disk_collector.get_metric('mountpoint', '/var/vcap/data')
        disk_metrics['persistent'] = disk_collector.get_metric('mountpoint', '/var/vcap/store')

        metrics['disk'] = disk_metrics
        metrics['load'] = @collectors[:load].get_metric
        metrics['memory'] = @collectors[:memory].get_metric

        metrics
      end
    end
  end
end
