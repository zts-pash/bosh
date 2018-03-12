require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellUploadsController < BaseController
      post '/', scope: :read_stemcells do
        payload = json_decode(request.body.read)

        stemcell = payload['stemcell']
        raise ValidationMissingField, "Missing 'stemcell' field" if stemcell.nil?

        name = stemcell['name']
        raise ValidationMissingField, "Missing 'name' field" if name.nil?

        version = stemcell['version']
        raise ValidationMissingField, "Missing 'version' field" if version.nil?

        result = { 'needed' => stemcell_not_found?(name, version) }
        json_encode(result)
      end

      def stemcell_not_found?(name, version)
        stemcell_manager = Bosh::Director::Api::StemcellManager.new
        cloud_factory = CloudFactory.create
        cloud_factory.all_names.each do |cpi_name|
          return false if stemcell_manager.find_by_name_and_version_and_cpi(name, version, cpi_name)
        end
      rescue StemcellNotFound
        return true
      end
    end
  end
end
