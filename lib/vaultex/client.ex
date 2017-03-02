defmodule Vaultex.Client do

  require Logger
  use GenServer
  @version "v1"
  @cache Elixir.Vaultex

  @moduledoc ~S"""
  A GenServer that holds all of the vault state for the keys we asked
  for in an ETS table. This makes sure we only ask vault if we actually
  need to but also takes into account vault expire flags so we "forget"
  about things and have to ask vault for new credentials.
  """

  @spec start_link() :: {Atom.t, Tumple.t}
  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vault)
  end

  @spec auth(tuple) :: {Atom.t, Map.t}
  def auth(creds) do
    GenServer.call(:vault, {:auth, creds})
  end

  @spec read(String.t) :: {Atom.t, Map.t}
  def read(key) do
    GenServer.call(:vault, {:read, key})
  end

  @spec write(String.t) :: {Atom.t, Map.t}
  def write(key) do
    GenServer.call(:vault, {:write, key, nil})
  end

  @spec write(String.t, map) :: {Atom.t, Map.t}
  def write(key, data) do
    GenServer.call(:vault, {:write, key, data})
  end

  @spec encrypt(String.t, map) :: {Atom.t, Map.t}
  def encrypt(key, data) do
    GenServer.call(:vault, {:encrypt, key, data}, 10_000)
  end

  @spec decrypt(String.t, map) :: {Atom.t, Map.t}
  def decrypt(key, data) do
    GenServer.call(:vault, {:decrypt, key, data}, 10_000)
  end


# GenServer callbacks

  @spec init(map) :: {Atom.t, Map.t}
  def init(state) do
    url = "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}/#{@version}/"
    {:ok, res} = request(:post, "#{url}auth/approle/login", %{role_id: get_env(:role_id), secret_id: get_env(:secret_id)})
    state1 = state
    |> Map.put(:url, url)
    |> Map.put(:token, res["auth"]["client_token"])
    {:ok, state1}
  end

  # FIXME this is deprecated as far as I can tell since we switched to approle based auth
  # authenticate and save the access token in `token`
  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:auth, {:user_id, user_id}}, _from, state) do
    app_id = Application.get_env(:vaultex, :app_id, nil)
    # TODO should call write here now that we have it
    {:ok, req} = request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id})
    #{:ok, req} = write("#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id})
    Logger.debug("Got auth reponse: #{inspect req}")

    {:reply, {:ok, :authenticated}, Map.merge(state, %{token: req["auth"]["client_token"]})}
  end

  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:auth, {:token, token}}, _from, state) do
    Logger.debug("Merged in token auth")
    {:reply, {:ok, :authenticated}, Map.merge(state, %{token: token})}
  end

  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:read, key}, _from, state) do
    data = case :ets.lookup(@cache, key) do
      [] ->
        res = request(:get, state.url <> key, nil, state.token)
              |> parse_response
        case res do
          {:ok, response} ->
            Logger.debug("[->cache] caching reponse for #{key}: #{inspect response}")
            send_expire(key, response)
            :ets.insert(@cache, {key, response})
            {:ok, response}
          error -> 
            Logger.error("got error reponse for #{key}: #{inspect error}")
            error
        end
      [{_, cached}] -> 
        Logger.debug("[<-cache] got a cached response for #{key}:#{cached}")
        {:ok, cached}
    end
    {:reply, data, state}
  end

  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:write, key, data}, _from, state) do
    case request(:post, state.url <> key, data, state.token) do
      {:ok, req} ->
        Logger.debug("Got reponse: #{inspect req}")
        {:reply, {:ok, req}, state}
      {:error, error} ->
        Logger.error("Got error: #{inspect error}")
        {:reply, {:error, error}, state}
    end
  end

  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:encrypt, key, data}, _from, state) do
    data1 = %{data | "plaintext" => data["plaintext"] |> Base.encode64}
    res = request(:post, "#{state.url}transit/encrypt/#{key}", data1, state.token)
    {:reply, res, state}
  end

  @spec handle_call(tuple, pid, map) :: {atom, tuple, map}
  def handle_call({:decrypt, key, data}, _from, state) do
    case request(:post, "#{state.url}transit/decrypt/#{key}", data, state.token) do
      {:ok, res} ->
        data1 = Map.put(res["data"], "plaintext", Base.decode64!(res["data"]["plaintext"]))
        {:reply, {:ok, %{res | "data" => data1}}, state}
      error ->
        {:reply, error, state}
    end
  end

  @spec handle_info(tuple, map) :: {atom, map}
  def handle_info({:purge, key}, state) do
    :ets.delete(@cache, key)
    Logger.info("Expired '#{key}' from cache")
    {:noreply, state}
  end


# internal helper functions

  defp send_expire(key, response) do
    case response["lease_duration"] do
      nil -> Logger.debug("No lease duration, no need to purge the key later")
      sec ->
        # notify me and delete the ETS cache
        Logger.debug("Purge the key from our internal cache after #{sec} seconds")
        :erlang.send_after(sec, __MODULE__, {:purge, key})
    end
  end

  # override some of the strange behaviour in valut and return a more sane
  # response
  defp parse_response(res) do
    case res do
      {:ok, {:errors, []}} -> {:error, :no_data}
      {:ok, {:errors, error}} -> {:error, error}
      ok -> ok
    end
  end

  defp request(method, url, params) do
    request(method, url, params, nil)
  end


  defp request(method, url, params, auth) do
    case get_content(method, url, params, auth) do
      {:ok, code, _headers, body_ref} ->
        {:ok, res} = :hackney.body body_ref
        Logger.debug("[body] #{inspect res}")
        case Poison.decode(res) do
          {:ok, json} ->
            cond do
            200 ->
              {:ok, json}
            204 ->
              {:ok, :no_data}
            code in 400..599 ->
              {:error, {{:http_status, code}, json}}
            true ->
              {:error, res}
            end
          {:error, :invalid, 0} ->
            {:ok, :no_data}
          {:error, json_err} ->
            case res do
              "" -> {:ok, :no_data}
              _  -> {:error, json_err}
            end
        end
      error -> error
    end
  end

  defp get_content(method, url, params, auth) do
    headers = case auth do
      nil -> [{"Content-Type", "application/json"}]
      token ->
        [{"Content-Type", "application/json"}, {"X-Vault-Token", token}]
    end
    Logger.debug("[#{method}] #{url}")
    Logger.debug("[HEADER] #{inspect headers}")

    case Poison.encode(params) do
      # empty params
      {:ok, "null"} ->
        :hackney.request(method, url, headers)
      {:ok, json} ->
        Logger.debug("[JSON] #{inspect json}")
        :hackney.request(method, url, headers, json)
      error -> error
    end
  end

  defp get_env(:host) do
      System.get_env("VAULT_HOST") || Application.get_env(:vaultex, :host) || "localhost"
  end
  defp get_env(:port) do
      System.get_env("VAULT_PORT") || Application.get_env(:vaultex, :port) || 8200
  end
  defp get_env(:scheme) do
      System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end
  defp get_env(:role_id) do
      System.get_env("VAULT_ROLE_ID") || Application.get_env(:vaultex, :role_id)
  end
  defp get_env(:secret_id) do
      System.get_env("VAULT_SECRET_ID") || Application.get_env(:vaultex, :secret_id)
  end
end
