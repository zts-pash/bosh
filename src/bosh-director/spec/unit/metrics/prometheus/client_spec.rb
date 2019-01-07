require 'spec_helper'
require 'timecop'

module Bosh::Director::Metrics::Prometheus
  describe Client do
    describe '#get_metrics' do
      let(:http_client) { instance_double('Net::HTTP') }

      let(:exporter_response) do
        Struct.new(:body).new(File.read(asset('prometheus/node_exporter_response.txt')))
      end

      before do
        allow(Net::HTTP).to receive(:new).and_return(http_client)
      end

      it 'should return a hash of metrics' do
        expect(http_client).to receive(:get).and_return(exporter_response)

        client = described_class.new('http://localhost:9100')
        metrics = client.metrics

        expect(metrics.key?('disk')).to be_truthy
        expect(metrics.key?('load')).to be_truthy
        expect(metrics.key?('memory')).to be_truthy
      end
    end
  end
end
