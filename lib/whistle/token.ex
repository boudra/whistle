defmodule Whistle.Token do
  alias Plug.Crypto.MessageEncryptor
  alias Plug.Crypto.KeyGenerator

  def sign(secret_key_base, salt, data, opts \\ []) when is_binary(salt) do
    {signed_at_seconds, key_opts} = Keyword.pop(opts, :signed_at)

    secret = KeyGenerator.generate(secret_key_base, salt)
    sign_secret = KeyGenerator.generate(secret_key_base, "test")

    signed_at_ms = if signed_at_seconds, do: trunc(signed_at_seconds * 1000), else: now_ms()

    %{data: data, signed: signed_at_ms}
    |> :erlang.term_to_binary()
    |> MessageEncryptor.encrypt(secret, sign_secret)
  end

  def verify(secret_key_base, salt, token, opts \\ [])

  def verify(secret_key_base, salt, token, opts) when is_binary(salt) and is_binary(token) do
    secret = KeyGenerator.generate(secret_key_base, salt)
    sign_secret = KeyGenerator.generate(secret_key_base, "test")

    case MessageEncryptor.decrypt(token, secret, sign_secret) do
      {:ok, message} ->
        %{data: data, signed: signed} = Plug.Crypto.safe_binary_to_term(message)

        if expired?(signed, Keyword.get(opts, :max_age, :infinity)) do
          {:error, :expired}
        else
          {:ok, data}
        end

      :error ->
        {:error, :invalid}
    end
  end

  def verify(_context, salt, nil, _opts) when is_binary(salt) do
    {:error, :missing}
  end

  defp expired?(_signed, :infinity), do: false
  defp expired?(signed, max_age_secs), do: signed + trunc(max_age_secs * 1000) < now_ms()

  defp now_ms, do: System.system_time(:millisecond)
end
