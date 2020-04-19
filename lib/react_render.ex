defmodule ReactRender do
  use Supervisor

  @timeout 10_000
  @default_pool_size 4

  @moduledoc """
  React Renderer
  """

  @doc """
  Starts the ReactRender and workers.

  ## Options
    * `:render_service_path` - (required) is the path to the react render service relative
  to your current working directory
    * `:pool_size` - (optional) the number of workers. Defaults to 4
  """
  @spec start_link(keyword()) :: {:ok, pid} | {:error, any()}
  def start_link(args) do
    default_options = [pool_size: @default_pool_size]
    opts = Keyword.merge(default_options, args)

    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stops the ReactRender and underlying node react render service
  """
  @spec stop() :: :ok
  def stop() do
    Supervisor.stop(__MODULE__)
  end

  @doc """
  Given the `component_path` and `props`, returns html.

  `component_path` is the path to your react component module relative
  to the render service.

  `props` is a map of props given to the component. Must be able to turn into
  json
  """
  @spec get_html(binary(), map()) :: {:ok, binary()} | {:error, map()}
  def get_html(component_path, props \\ %{}) do
    case do_get_html(component_path, props) do
      {:error, _} = error ->
        error

      {:ok, %{"markup" => markup}} ->
        {:ok, markup}
    end
  end

  @doc """
  Same as `get_html/2` but wraps html in a div which is used
  to hydrate react component on client side.

  This is the preferred function when using with Phoenix

  `component_path` is the path to your react component module relative
  to the render service.

  `props` is a map of props given to the component. Must be able to turn into
  json
  """
  @spec render(binary(), map()) :: {:safe, binary()}
  def render(component_path, props \\ %{}) do
    case do_get_html(component_path, props) do
      {:error, %{message: message, stack: stack}} ->
        raise ReactRender.RenderError, message: message, stack: stack

      {:ok, %{"markup" => markup, "component" => component}} ->
        encoded_props = Jason.encode!(props)
       s = "<div data-rendered data-component=\"#{component}\" data-props=\"#{encoded_props}\">"


        {:safe, s <> markup <> "</div>"}
    end
  end

  @spec render_root(binary(), map(), keyword()) :: {:safe, binary()}
  def render_root(component_path, props, opts \\ [] ) do
    location = Keyword.get(opts, :location, "/")
    root_id = Keyword.get(opts, :root_id, "react-root")

    case do_get_root_html(component_path, location, props) do
      {:error, %{message: message, stack: stack}} ->
        raise ReactRender.RenderError, message: message, stack: stack

      {:ok, %{"markup" => markup, "component" => component}} ->
        encoded_props = Jason.encode!(props)

        html = "<div id=\"#{root_id}\" data-component=\"#{component}\" data-props=\"#{encoded_props}\">" <> markup <> "</div>"


        {:safe, html}
    end
  end


  defp do_get_root_html(component_path, req_url, props) do
    # do not think this needs to be in a task, is likely already being called in an isolated request process...
    NodeJS.call({:render_server, :renderWithRouter}, [component_path, req_url, props], binary: true)
    |> case do
      {:ok, %{"error" => error}} when not is_nil(error) ->
        normalized_error = %{
          message: error["message"],
          stack: error["stack"]
        }

        {:error, normalized_error}
       ok -> ok
    end
  end

  defp do_get_html(component_path, props) do
    task =
      Task.async(fn ->
        NodeJS.call({:render_server, :render}, [component_path, props], binary: true)
      end)

    case Task.await(task, @timeout) do
      {:ok, %{"error" => error}} when not is_nil(error) ->
        normalized_error = %{
          message: error["message"],
          stack: error["stack"]
        }

        {:error, normalized_error}

      {:ok, result} ->
        {:ok, result}
    end
  end

  # --- Supervisor Callbacks ---
  @doc false
  def init(opts) do
    pool_size = Keyword.fetch!(opts, :pool_size)
    render_service_path = Keyword.fetch!(opts, :render_service_path)

    children =
      case Application.get_application(:nodejs) do
        nil ->
          [
            supervisor(NodeJS.Supervisor, [
              [path: render_service_path, pool_size: pool_size]
            ])
          ]

        _ ->
          []
      end

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
