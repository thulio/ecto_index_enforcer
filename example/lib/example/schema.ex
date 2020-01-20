defmodule Example.MySchema do
  use Ecto.Schema

  @primary_key false
  schema "my_schema" do
    field(:id, :integer, primary_key: true)
    field(:name, :string)
    field(:value, :float)
    field(:other_value, :decimal)
    field(:data, :map)
  end
end
