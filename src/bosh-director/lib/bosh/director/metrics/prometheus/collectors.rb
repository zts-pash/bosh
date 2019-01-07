module Bosh::Director::Metrics::Prometheus
  class DiskCollector
    def initialize(free_key, total_key)
      @mapping = {
        'free' => free_key,
        'total' => total_key,
      }

      @families = {}
    end

    def collect_family(family)
      collected = false
      @mapping.each do |_, family_name|
        if family.name == family_name
          @families[family_name] = family
          collected = true
        end
      end

      collected
    end

    def metric(label_name, label_value)
      disk = Bosh::Director::Metrics::Disk.new

      disk.total = extract_metric(@mapping['total'], label_name, label_value)
      disk.free = extract_metric(@mapping['free'], label_name, label_value)
      disk.used = disk.total - disk.free unless disk.total.nil? || disk.free.nil?

      disk
    end

    private

    def extract_metric(key, label_name, label_value)
      selected_metric = @families[key].metric.reject do |metric|
        metric.label.select do |label|
          label.name == label_name && label.value == label_value
        end.empty?
      end.first

      return selected_metric.gauge.value unless selected_metric.nil?

      nil
    end
  end

  class MemoryCollector
    def initialize(free_key, total_key)
      @mapping = {
        'free' => free_key,
        'total' => total_key,
      }

      @families = {}
    end

    def collect_family(family)
      collected = false
      @mapping.each do |_, family_name|
        if family.name == family_name
          @families[family_name] = family
          collected = true
        end
      end

      collected
    end

    def metric
      memory = Bosh::Director::Metrics::Memory.new

      memory.total = extract_metric(@mapping['total'])
      memory.free = extract_metric(@mapping['free'])
      memory.used = memory.total - memory.free unless memory.total.nil? || memory.free.nil?

      memory
    end

    private

    def extract_metric(key)
      metric = @families[key].metric.first

      return metric.gauge.value unless metric.nil?

      nil
    end
  end

  class LoadCollector
    def initialize(load1_key, load5_key, load15_key)
      @mapping = {
        'load1' => load1_key,
        'load5' => load5_key,
        'load15' => load15_key,
      }

      @families = {}
    end

    def collect_family(family)
      collected = false
      @mapping.each do |_, family_name|
        if family.name == family_name
          @families[family_name] = family
          collected = true
        end
      end

      collected
    end

    def metric
      load = Bosh::Director::Metrics::Load.new

      load.load1 = extract_metric(@mapping['load1'])
      load.load5 = extract_metric(@mapping['load5'])
      load.load15 = extract_metric(@mapping['load15'])

      load
    end

    private

    def extract_metric(key)
      metric = @families[key].metric.first

      return metric.gauge.value unless metric.nil?

      nil
    end
  end
end
