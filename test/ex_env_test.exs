defmodule ExEnvTest do
  use ExUnit.Case
  doctest ExEnv

  @os_var "EX_ENV_TEST_DATE_SIGILS_CONFIG"
  @fixture Path.expand("fixtures/date_sigils_config.exs", __DIR__)

  setup do
    on_exit(fn -> System.delete_env(@os_var) end)
  end

  test "date and time sigils from system variable are evaluated into config" do
    System.put_env(@os_var, """
    [
      launch_date: ~D[2026-09-09],
      open_at: ~T[10:00:00],
      created_at: ~N[2026-09-09 10:00:00],
      deadline: ~U[2026-09-09 10:00:00Z]
    ]
    """)

    config = Config.Reader.read!(@fixture)

    assert config[:ex_env_test_app] == [
             launch_date: ~D[2026-09-09],
             open_at: ~T[10:00:00],
             created_at: ~N[2026-09-09 10:00:00],
             deadline: ~U[2026-09-09 10:00:00Z]
           ]
  end

  test "date sigil with custom calendar is rejected" do
    System.put_env(@os_var, "[launch_date: ~D[2026-09-09 Evil.Calendar]]")

    assert_raise RuntimeError, ~r/unsupported calendar Evil.Calendar/, fn ->
      Config.Reader.read!(@fixture)
    end
  end

  test "other sigils are rejected" do
    System.put_env(@os_var, "[name: ~s[hello]]")

    assert_raise RuntimeError, ~r/invalid or unsafe config AST/, fn ->
      Config.Reader.read!(@fixture)
    end
  end
end
