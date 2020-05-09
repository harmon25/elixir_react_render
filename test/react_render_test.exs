defmodule ReactRender.Test do
  use ExUnit.Case
  doctest ReactRender

  setup_all do
    apply(ReactRender, :start_link, [[render_service_path: "#{File.cwd!()}/test/fixtures"]])
    :ok
  end

  describe "get_html" do
    test "returns html" do
      {:ok, html} = ReactRender.get_html("ClassComponent.js", %{name: "test"})
      assert html =~ "👋"
      assert html =~ "test"
    end

    test "returns error when no component found" do
      {:error, error} = ReactRender.get_html("./NotFound.js")
      assert error.message =~ "Cannot find module"
    end
  end

  describe "render" do
    test "returns html" do
      {:safe, html} = ReactRender.render("PureFunction.js", %{name: "test"})
      # IO.inspect(html)
      assert html =~ "data-rendered"

      assert html =~ "👋"
      assert html =~ "test"
    end

    test "returns html with id" do
      {{:safe, html}, %{}} =
        ReactRender.render_root("PureFunction.js", %{name: "test"}, root_id: "root-id")

      # IO.inspect(html)
      assert html =~ "id=\"root-id\""
      assert html =~ "data-component=\"TestComponent\""
      assert html =~ "👋"
      assert html =~ "test"
    end

    test "raises RenderError when no component found" do
      assert_raise ReactRender.RenderError, ~r/Cannot find module/, fn ->
        ReactRender.render("./NotFound.js")
      end
    end
  end
end
