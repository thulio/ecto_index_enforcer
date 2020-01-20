defmodule Example.Repo do
  use Ecto.Repo,
    otp_app: :example,
    adapter: Ecto.Adapters.Postgres

  use EctoIndexEnforcer, raise_errors: false, validate_wheres: true, validate_indexes: true
end
