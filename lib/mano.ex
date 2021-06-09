defmodule Mano do
  @moduledoc """
  Documentation for `Mano`.
  """

  # TODO
  # * docs
  # * doctests
  # * sigils

  @doc """
  Hello world.

  ## Examples

      iex> Mano.hello()
      :world

  """
  def hello do
    :world
  end

  defstruct [fingertree: :empty]

  @type t(value) :: %__MODULE__{
    fingertree: fingertree(value)
  }

  @type fingertree(value)
    :: :empty
    |  {:single, value}
    |  {:deep, finger(value), fingertree(node(value)), finger(value)}
    # TODO Further constructor for reversed, for O(1) reversal

  @type finger(value)
    :: {:single, value}
    |  {:tuple, value, value}
    |  {:triple, value, value, value}

  defguardp is_finger(finger)
  when is_tuple(finger)
  and (tuple_size(finger) == 2 and elem(finger, 0) == :single
    or tuple_size(finger) == 3 and elem(finger, 0) == :tuple
    or tuple_size(finger) == 4 and elem(finger, 0) == :triple
  )

  @type node(value)
    :: {:tuple, value, value}
    |  {:triple, value, value, value}

  defimpl Enumerable, for: Mano do
    def count(_) do
      {:error, __MODULE__}
    end

    def reduce(mano, acc, fun) do
      reduce_(mano, acc, fun)
    end

    defp reduce_(_mano, {:halt, acc}, _fun) do
      {:halted, acc}
    end

    defp reduce_(mano, {:suspended, acc}, fun) do
      {:suspended, acc, &reduce_(mano, &1, fun)}
    end

    defp reduce_(mano, {:cont, acc}, fun) do
      # IO.inspect(mano, label: "reduce")
      case Mano.view_left(mano) do
        nil -> {:done, acc}
        {value, mano} -> reduce_(mano, fun.(value, acc), fun)
      end
    end

    def member?(_, _) do
      {:error, __MODULE__}
    end

    def slice(_) do
      {:error, __MODULE__}
    end
  end

  # TODO use snoc
  defimpl Collectable, for: Mano do
    def into(mano) do
      {mano, &collector/2}
    end

    defp collector(mano, {:cont, elem}) do
      Mano.snoc(mano, elem)
    end

    defp collector(mano, :done) do
      mano
    end

    defp collector(_mano, :halt) do
      :ok
    end
  end

  @spec empty() :: t(value) when value: any()
  def empty() do
    %__MODULE__{}
  end

  def new() do
    empty()
  end

  @spec new([value]) :: t(value) when value: any()
  def new(items) do
    Enum.into(items, empty())
  end

  def equal(mano1, mano2) do
    Enum.to_list(mano1) == Enum.to_list(mano2)
  end

  @doc """
  Prepend a value
  """
  @spec cons(t(value), value) :: t(value) when value: any()
  def cons(%__MODULE__{fingertree: fingertree}, value) do
    %__MODULE__{fingertree: cons_(fingertree, value)}
  end

  defp cons_(:empty, value) do
    {:single, value}
  end

  defp cons_(value2 = {:single, _}, value1) do
    {:deep, {:single, value1}, :empty, value2}
  end

  defp cons_({:deep, {:single, value2}, tree, finger2}, value1) do
    {:deep, {:tuple, value1, value2}, tree, finger2}
  end

  defp cons_({:deep, {:tuple, value2, value3}, tree, finger2}, value1) do
    {:deep, {:triple, value1, value2, value3}, tree, finger2}
  end

  defp cons_({:deep, {:triple, value2, value3, value4}, tree, finger2}, value1) do
    {:deep, {:tuple, value1, value2}, cons_(tree, {:tuple, value3, value4}), finger2}
  end

  def snoc(%__MODULE__{fingertree: fingertree}, value) do
    %__MODULE__{fingertree: snoc_(fingertree, value)}
  end

  defp snoc_(:empty, value) do
    {:single, value}
  end

  defp snoc_(value1 = {:single, _}, value2) do
    {:deep, value1, :empty, {:single, value2}}
  end

  defp snoc_({:deep, finger, fingertree, {:single, value1}}, value2) do
    {:deep, finger, fingertree, {:tuple, value1, value2}}
  end

  defp snoc_({:deep, finger, fingertree, {:tuple, value1, value2}}, value3) do
    {:deep, finger, fingertree, {:triple, value1, value2, value3}}
  end

  defp snoc_({:deep, finger, fingertree, {:triple, value1, value2, value3}}, value4) do
    {:deep, finger, snoc_(fingertree, {:tuple, value1, value2}), {:tuple, value3, value4}}
  end

  def view_left(%__MODULE__{fingertree: fingertree}) do
    case view_left_(fingertree) do
      nil -> nil
      {value, fingertree} -> {value, %__MODULE__{fingertree: fingertree}}
    end
  end

  defp view_left_(:empty) do
    nil
  end

  defp view_left_({:single, value}) do
    {value, :empty}
  end

  defp view_left_({:deep, {:single, value}, :empty, finger = {:single, _}}) do
    {value, finger}
  end

  defp view_left_({:deep, {:single, value}, :empty, {:tuple, value2, value3}}) do
    {value, {:deep, {:single, value2}, :empty, {:single, value3}}}
  end

  defp view_left_({:deep, {:single, value}, :empty, {:triple, value2, value3, value4}}) do
    {value, {:deep, {:single, value2}, :empty, {:tuple, value3, value4}}}
  end

  defp view_left_({:deep, {:single, value}, tree, finger}) do
    # :empty cannot occur here
    {node, tree} = view_left_(tree)
    {value, {:deep, node, tree, finger}}
  end

  defp view_left_({:deep, {:tuple, value1, value2}, tree, finger}) do
    {value1, {:deep, {:single, value2}, tree, finger}}
  end

  defp view_left_({:deep, {:triple, value1, value2, value3}, tree, finger}) do
    {value1, {:deep, {:tuple, value2, value3}, tree, finger}}
  end

  def view_right(%__MODULE__{fingertree: fingertree}) do
    case view_right_(fingertree) do
      nil -> nil
      {value, fingertree} -> {value, %__MODULE__{fingertree: fingertree}}
    end
  end

  defp view_right_(:empty) do
    nil
  end

  defp view_right_({:single, value}) do
    {value, :empty}
  end

  defp view_right_({:deep, finger, fingertree, {:tuple, value1, value2}}) do
    {value2, {:deep, finger, fingertree, {:single, value1}}}
  end

  defp view_right_({:deep, finger, fingertree, {:triple, value1, value2, value3}}) do
    {value3, {:deep, finger, fingertree, {:tuple, value1, value2}}}
  end

  defp view_right_({:deep, finger, fingertree, {:single, value}}) do
    case view_right_(fingertree) do
      {node, fingertree} -> {value, {:deep, finger, fingertree, node}}
      nil -> case finger do
        {:single, _} -> {value, finger}
        {:tuple, value1, value2} -> {value, {:deep, {:single, value1}, :empty, {:single, value2}}}
        {:triple, value1, value2, value3} -> {value, {:deep, {:single, value1}, :empty, {:tuple, value2, value3}}}
      end
    end
  end

  def reverse(%__MODULE__{fingertree: fingertree}) do
    %__MODULE__{fingertree: reverse_(fingertree)}
  end

  defp reverse_(:empty) do
    :empty
  end

  defp reverse_({:single, value}) do
    {:single, reverse_(value)}
  end

  defp reverse_({:deep, finger1, fingertree, finger2}) do
    {:deep, reverse_(finger2), reverse_(fingertree), reverse_(finger1)}
  end

  defp reverse_({:tuple, value1, value2}) do
    {:tuple, reverse_(value2), reverse_(value1)}
  end

  defp reverse_({:triple, value1, value2, value3}) do
    {:triple, reverse_(value3), reverse_(value2), reverse_(value1)}
  end

  defp reverse_(value) do
    value
  end

  def append(%__MODULE__{fingertree: fingertree1}, %__MODULE__{fingertree: fingertree2}) do
    %__MODULE__{fingertree: append_(fingertree1, fingertree2)}
  end

  defp append_(fingertree1, fingertree2) do
    glue(fingertree1, [], fingertree2)
  end

  defp cons_all(values, fingertree) do
    Enum.reduce(values, fingertree, &cons_(&2, &1))
  end

  defp snoc_all(values, fingertree) do
    Enum.reduce(values, fingertree, &snoc_(&2, &1))
  end

  defp glue(:empty, middle, fingertree) do
    # IO.inspect([middle: middle, fingertree: fingertree], label: "empty right")
    cons_all(Enum.reverse(middle), fingertree)
    # |> IO.inspect(label: "empty left")
  end

  defp glue(fingertree, middle, :empty) do
    # IO.inspect([middle: middle, fingertree: fingertree], label: "empty right")
    snoc_all(middle, fingertree)
    # |> IO.inspect(label: "empty right")
  end

  defp glue({:single, value}, middle, fingertree) do
    # IO.inspect([value: value, middle: middle, fingertree: fingertree], label: "single left")
    cons_all(Enum.reverse(middle), fingertree)
    |> cons_(value)
  end

  defp glue(fingertree, middle, {:single, value}) do
    # IO.inspect([value: value, middle: middle, fingertree: fingertree], label: "single left")
    snoc_all(middle, fingertree)
    |> snoc_(value)
  end

  defp glue(
    {:deep, fingerA1, fingertreeA, fingerA2},
    middle,
    {:deep, fingerB1, fingertreeB, fingerB2}
  ) do
    {:deep, fingerA1, glue(fingertreeA, to_tuples(to_list(fingerA2) ++ middle ++ to_list(fingerB1)), fingertreeB), fingerB2}
  end

  defp to_list({:single, value}) do
    [value]
    # |> IO.inspect(label: "to_list")
  end

  defp to_list({:tuple, value1, value2}) do
    [value1, value2]
    # |> IO.inspect(label: "to_list")
  end

  defp to_list({:triple, value1, value2, value3}) do
    [value1, value2, value3]
    # |> IO.inspect(label: "to_list")
  end

  defp to_tuples([]) do
    []
  end

  defp to_tuples([value1, value2]) do
    [{:tuple, value1, value2}]
    # |> IO.inspect(label: "tuples")
  end

  defp to_tuples([value1, value2, value3, value4]) do
    [{:tuple, value1, value2}, {:tuple, value3, value4}]
    # |> IO.inspect(label: "tuples")
  end

  defp to_tuples([value1, value2, value3 | tail]) do
    [{:triple, value1, value2, value3} | to_tuples(tail)]
  end
end
