defmodule Whistle.Token do
  alias Plug.Crypto.MessageEncryptor
  alias Plug.Crypto.KeyGenerator

  def sign(secret_key_base, encrypt_salt, sign_salt, data) do
    secret = KeyGenerator.generate(secret_key_base, encrypt_salt)
    sign_secret = KeyGenerator.generate(secret_key_base, sign_salt)

    %{data: data, signed: now_ms()}
    |> :erlang.term_to_binary()
    |> MessageEncryptor.encrypt(secret, sign_secret)
  end

  def verify(secret_key_base, encrypt_salt, sign_salt, token, max_age \\ :infinity)

  def verify(secret_key_base, encrypt_salt, sign_salt, token, max_age) when is_binary(token) do
    secret = KeyGenerator.generate(secret_key_base, encrypt_salt)
    sign_secret = KeyGenerator.generate(secret_key_base, sign_salt)

    case MessageEncryptor.decrypt(token, secret, sign_secret) do
      {:ok, message} ->
        %{data: data, signed: signed} = Plug.Crypto.safe_binary_to_term(message)

        if expired?(signed, max_age) do
          {:error, :expired}
        else
          {:ok, data}
        end

      :error ->
        {:error, :invalid}
    end
  end

  def verify(_, _, _, _, _) do
    {:error, :invalid}
  end

  defp expired?(_signed, :infinity), do: false
  defp expired?(signed, max_age_secs), do: signed + trunc(max_age_secs * 1000) < now_ms()

  defp now_ms, do: System.system_time(:millisecond)
end
