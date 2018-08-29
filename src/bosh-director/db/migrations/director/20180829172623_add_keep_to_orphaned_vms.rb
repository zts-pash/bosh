Sequel.migration do
  up do
    alter_table(:orphaned_vms) do
      add_column(:keep, :boolean, default: false)
    end
  end
end
