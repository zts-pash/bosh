Sequel.migration do
  up do
    create_table :certificate_expiries do
      primary_key :id
      foreign_key :deployment_id, :deployments, null: false, on_delete: :cascade
      String :certificate_path, null: false
      Time :expiry, null: false
      unique %i[deployment_id certificate_path], name: :deployment_id_certificate_path_unique
    end
  end
end
