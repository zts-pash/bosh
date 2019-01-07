require 'spec_helper'

module Bosh::Director::Metrics::Prometheus
  describe DiskCollector do
    let(:free_key) { 'my_free_key' }
    let(:total_key) { 'my_total_key' }

    context '#collect_family' do
      context 'family matches free key' do
        subject { described_class.new(free_key, nil) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = free_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family matches total key' do
        subject { described_class.new(nil, total_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = total_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family does not match any keys' do
        subject { described_class.new(free_key, total_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = 'unknown_key'
          end
        end

        it 'return false' do
          expect(subject.collect_family(family)).to be_falsey
        end
      end
    end
    context '#get_metric' do
      subject { described_class.new(free_key, total_key) }

      let(:free_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = free_key
          family.metric = [
            make_gauge_metric(100, 'mountpoint' => '/'),
            make_gauge_metric(200, 'mountpoint' => '/var/vcap/data'),
            make_gauge_metric(300, 'mountpoint' => '/bar'),
          ]
        end
      end

      let(:total_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = total_key
          family.metric = [
            make_gauge_metric(600, 'mountpoint' => '/'),
            make_gauge_metric(700, 'mountpoint' => '/var/vcap/data'),
            make_gauge_metric(800, 'mountpoint' => '/bar'),
          ]
        end
      end

      def make_gauge_metric(value, labels = {})
        metric_labels = []
        labels.each do |k, v|
          metric_labels << make_label(k, v)
        end

        ::Prometheus::Client::Metric.new.tap do |metric|
          metric.label = metric_labels
          metric.gauge = ::Prometheus::Client::Gauge.new.tap do |gauge|
            gauge.value = value
          end
        end
      end

      def make_label(label_name, label_value)
        ::Prometheus::Client::LabelPair.new.tap do |label|
          label.name = label_name
          label.value = label_value
        end
      end

      before do
        subject.collect_family(free_family)
        subject.collect_family(total_family)
      end

      it 'returns a disk metric object' do
        disk_metric = subject.metric('mountpoint', '/var/vcap/data')
        expect(disk_metric).to be_a(Bosh::Director::Metrics::Disk)
      end

      context 'when the labels match' do
        it 'returns the disk with collected values' do
          disk_metric = subject.metric('mountpoint', '/var/vcap/data')
          expect(disk_metric.total).to eq(700)
          expect(disk_metric.free).to eq(200)
          expect(disk_metric.used).to eq(500)
        end
      end

      context 'when a metric does NOT contain the label name or value' do
        it 'returns a disk metric object with nil values' do
          disk_metric = subject.metric('mountpoint', 'cat')
          expect(disk_metric.total).to be_nil
          expect(disk_metric.free).to be_nil
          expect(disk_metric.used).to be_nil
        end
      end
    end
  end

  describe LoadCollector do
    let(:load1_key) { 'my_load_1' }
    let(:load5_key) { 'my_load_5' }
    let(:load15_key) { 'my_load_15' }

    context '#collect_family' do
      context 'family matches load1_key key' do
        subject { described_class.new(load1_key, nil, nil) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = load1_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family matches load5 key' do
        subject { described_class.new(nil, load5_key, nil) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = load5_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family matches load15_key key' do
        subject { described_class.new(nil, nil, load15_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = load15_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family does not match any keys' do
        subject { described_class.new(load1_key, load5_key, load15_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = 'unknown_key'
          end
        end

        it 'return false' do
          expect(subject.collect_family(family)).to be_falsey
        end
      end
    end

    context '#get_metric' do
      subject { described_class.new(load1_key, load5_key, load15_key) }

      let(:load1_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = load1_key
          family.metric = [
            make_gauge_metric(2.5),
          ]
        end
      end

      let(:load5_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = load5_key
          family.metric = [
            make_gauge_metric(1.7),
          ]
        end
      end

      let(:load15_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = load15_key
          family.metric = [
            make_gauge_metric(0.5),
          ]
        end
      end

      def make_gauge_metric(value, labels = {})
        metric_labels = []
        labels.each do |k, v|
          metric_labels << make_label(k, v)
        end

        ::Prometheus::Client::Metric.new.tap do |metric|
          metric.label = metric_labels
          metric.gauge = ::Prometheus::Client::Gauge.new.tap do |gauge|
            gauge.value = value
          end
        end
      end

      def make_label(label_name, label_value)
        ::Prometheus::Client::LabelPair.new.tap do |label|
          label.name = label_name
          label.value = label_value
        end
      end

      before do
        subject.collect_family(load1_family)
        subject.collect_family(load5_family)
        subject.collect_family(load15_family)
      end

      it 'returns a cpu load metric object' do
        disk_metric = subject.metric
        expect(disk_metric).to be_a(Bosh::Director::Metrics::Load)
      end

      it 'returns the cpu load with collected values' do
        metric = subject.metric
        expect(metric.load1).to eq(2.5)
        expect(metric.load5).to eq(1.7)
        expect(metric.load15).to eq(0.5)
      end
    end
  end

  describe MemoryCollector do
    let(:free_key) { 'my_free_key' }
    let(:total_key) { 'my_total_key' }

    context '#collect_family' do
      context 'family matches free key' do
        subject { described_class.new(free_key, nil) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = free_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family matches total key' do
        subject { described_class.new(nil, total_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = total_key
          end
        end

        it 'return true' do
          expect(subject.collect_family(family)).to be_truthy
        end
      end

      context 'family does not match any keys' do
        subject { described_class.new(free_key, total_key) }

        let(:family) do
          ::Prometheus::Client::MetricFamily.new.tap do |family|
            family.name = 'unknown_key'
          end
        end

        it 'return false' do
          expect(subject.collect_family(family)).to be_falsey
        end
      end
    end
    context '#get_metric' do
      subject { described_class.new(free_key, total_key) }

      let(:free_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = free_key
          family.metric = [
            make_gauge_metric(1000),
          ]
        end
      end

      let(:total_family) do
        ::Prometheus::Client::MetricFamily.new.tap do |family|
          family.name = total_key
          family.metric = [
            make_gauge_metric(20000),
          ]
        end
      end

      def make_gauge_metric(value, labels = {})
        metric_labels = []
        labels.each do |k, v|
          metric_labels << make_label(k, v)
        end

        ::Prometheus::Client::Metric.new.tap do |metric|
          metric.label = metric_labels
          metric.gauge = ::Prometheus::Client::Gauge.new.tap do |gauge|
            gauge.value = value
          end
        end
      end

      before do
        subject.collect_family(free_family)
        subject.collect_family(total_family)
      end

      it 'returns a memory metric object' do
        memory_metric = subject.metric
        expect(memory_metric).to be_a(Bosh::Director::Metrics::Memory)
      end

      it 'returns the memory metric with collected values' do
        memory_metric = subject.metric
        expect(memory_metric.total).to eq(20000)
        expect(memory_metric.free).to eq(1000)
        expect(memory_metric.used).to eq(19000)
      end
    end
  end
end
