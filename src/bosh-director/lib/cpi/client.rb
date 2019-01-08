this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = this_dir
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'grpc'
require 'cpi_services_pb'

# def main
#   stub = Cpi::CPI::Stub.new('unix:///tmp/cpi.socket', :this_channel_is_insecure)
#   resp = stub.info(Cpi::BaseRequest.new(director_uuid: 'stuff', properties: { a: 1 }.to_json))
#   p "Greeting: #{resp.inspect}"
# end

# main
