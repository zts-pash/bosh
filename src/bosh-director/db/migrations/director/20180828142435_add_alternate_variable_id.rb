Sequel.migration do
  up do
    alter_table(:variables) do
      add_column(:alternate_variable_id, String)
    end
  end
end
