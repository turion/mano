defmodule ManoTest do
  use ExUnit.Case
  use PropCheck

  doctest Mano

  def mano_equals(mano1 = %Mano{}, mano2 = %Mano{}) do
    when_fail(equals(Enum.to_list(mano1), Enum.to_list(mano2)),
      IO.inspect(
        mano1: mano1,
        mano2: mano2
      )
    )
  end

  def mano_equals(mano = %Mano{}, list)
  when is_list(list) do
    when_fail(equals(Enum.to_list(mano), list),
      IO.inspect(
        mano: mano,
        list: list
      )
    )
  end

  def gen(gen_value \\ term()) do
    let fingertree <- gen_fingertree(gen_value) do
      %Mano{fingertree: fingertree}
    end
  end

  defp gen_single(gen_value) do
    # IO.puts("gen_single")
    {:single, gen_value}
  end

  defp gen_tuple(gen_value) do
    # IO.puts("gen_tuple")
    {:tuple, gen_value, gen_value}
  end

  defp gen_triple(gen_value) do
    # IO.puts("gen_triple")
    {:triple, gen_value, gen_value, gen_value}
  end

  defp gen_fingertree(gen_value) do
    # IO.puts("gen_fingertree")
    # let shape <- oneof([:empty, :single, :deep]) do
    #   case shape do
    #     :empty -> :empty
    #     :single -> {:single, gen_value}
    #     :deep -> {:deep, gen_finger(gen_value), gen_fingertree(gen_node(gen_value)), gen_finger(gen_value)}
    #   end
    # end
    oneof([
      :empty,
      gen_single(gen_value),
      # {:deep, gen_finger(gen_value), delay(gen_fingertree(gen_node(gen_value))), gen_finger(gen_value)}
      gen_deep(gen_value)
    ])
  end

  defp gen_deep(gen_value) do
    let [
      finger1 <- gen_finger(gen_value),
      fingertree <- lazy(gen_fingertree(gen_node(gen_value))),
      finger2 <- gen_finger(gen_value)
    ] do
      {:deep, finger1, fingertree, finger2}
    end
  end

  def gen_finger(gen_value) do
    # IO.puts("gen_finger")
    oneof([
      gen_single(gen_value),
      gen_tuple(gen_value),
      gen_triple(gen_value)
    ])
  end

  def gen_node(gen_value) do
    # IO.puts("gen_node")
    oneof([
      gen_tuple(gen_value),
      gen_triple(gen_value)
    ])
  end

  describe "Constructors and destructors:" do
    property "view_left and cons are inverses" do
      forall mano <- gen() do
        case Mano.view_left(mano) do
          nil -> true
          {value, tail} -> mano_equals(mano, Mano.cons(tail, value))
        end
      end
    end

    property "cons and view_left are inverses" do
      forall [
        mano <- gen(),
        value <- term()
      ] do
        {value_, mano_} = mano
          |> Mano.cons(value)
          |> Mano.view_left()
        conjunction(
          value: equals(value, value_),
          tail: mano_equals(mano, mano_)
        )
      end
    end

    property "view_right and snoc are inverses" do
      forall mano <- gen() do
        case Mano.view_right(mano) do
          nil -> true
          {value, init} -> mano_equals(mano, Mano.snoc(init, value))
        end
      end
    end

    property "snoc and view_right are inverses" do
      forall [
        mano <- gen(),
        value <- term()
      ] do
        {value_, mano_} = mano
          |> Mano.snoc(value)
          |> Mano.view_right()
        conjunction(
          value: equals(value, value_),
          init: mano_equals(mano, mano_)
        )
      end
    end
  end

  describe "Enumerable is correct" do
    property "count doesn't crash" do
      forall mano <- gen() do
        Enum.count(mano)
      end

      true
    end

    property "to_list doesn't crash" do
      forall mano <- gen() do
        Enum.to_list(mano)
      end

      true
    end

    property "count = length . to_list" do
      forall mano <- gen() do
        Enum.count(mano) == length(Enum.to_list(mano))
      end
    end

    property "member? and cons agree" do
      forall [
        mano <- gen(),
        value <- term()
      ] do
        mano
        |> Mano.cons(value)
        |> Enum.member?(value)
      end
    end

    property "member? and snoc agree" do
      forall [
        mano <- gen(),
        value <- term()
      ] do
        mano
        |> Mano.snoc(value)
        |> Enum.member?(value)
      end
    end
  end

  describe "Collectable is correct" do
    property "new doesn't crash" do
      forall items <- list() do
        Mano.new(items)

        true
      end
    end

    property "cons and list constructor agree" do
      forall [
        value <- term(),
        items <- list()
      ] do
        mano_equals(
          Mano.cons(Mano.new(items), value),
          Mano.new([value | items])
        )
      end
    end
  end

  describe "Enumerable and Collectable are compatible" do
    property "new . count = length agrees" do
      forall items <- list() do
        mano = Mano.new(items)
        when_fail(
          equals(Enum.count(mano), length(items)),
          IO.inspect(mano)
        )
      end
    end

    property "new and to_list are inverse" do
      forall items <- list() do
        mano = Mano.new(items)
        when_fail(
          equals(Enum.to_list(mano), items),
          IO.inspect(mano)
        )
      end
    end

    property "to_list and new are inverse" do
      forall mano1 <- gen() do
        mano2 = mano1
          |> Enum.to_list()
          |> Mano.new()
        mano_equals(mano1, mano2)
      end
    end

    property "view_left and list constructors are compatible" do
      forall mano <- gen() do
        expected_list = case Mano.view_left(mano) do
          nil -> []
          {head, tail} -> [head | Enum.to_list(tail)]
        end
        mano_equals(mano, expected_list)
      end
    end
  end

  describe "reverse properties:" do
    property "reverse . to_list = to_list . reverse" do
      forall mano <- gen() do
        reversed = Mano.reverse(mano)
        reversed_items = mano
          |> Enum.to_list()
          |> Enum.reverse()
        mano_equals(reversed, reversed_items)
      end
    end

    property "new . reverse = reverse . new" do
      forall items <- list() do
        mano1 = items
          |> Mano.new()
          |> Mano.reverse()
        mano2 = items
          |> Enum.reverse()
          |> Mano.new()
        mano_equals(mano1, mano2)
      end
    end

    property "reverse is a transformation between cons and snoc" do
      forall [
        mano <- gen(),
        item <- term()
      ] do
        mano1 = mano
          |> Mano.cons(item)
          |> Mano.reverse()
        mano2 = mano
          |> Mano.reverse()
          |> Mano.snoc(item)
        when_fail(
          mano_equals(mano1, mano2),
          IO.inspect(
            mano: mano,
            item: item
          )
        )
      end
    end

    property "reverse is a transformation between view_left and view_right" do
      forall mano <- gen() do
        reversed_view_right = mano
          |> Mano.reverse()
          |> Mano.view_right()
        case Mano.view_left(mano) do
          nil -> equals(nil, reversed_view_right)
          {value, tail} ->
            {value_, tail_} = reversed_view_right
            conjunction(
              value: equals(value, value_),
              mano: mano_equals(tail, Mano.reverse(tail_))
            )
        end
      end
    end
  end

  describe "append:" do
    property "append doesn't crash" do
      forall [
        mano1 <- gen(),
        mano2 <- gen()
      ] do
        Mano.append(mano1, mano2)

        true
      end
    end

    property "append . to_list = to_list . (++)" do
      forall [
        mano1 <- gen(),
        mano2 <- gen()
      ] do
        mano_equals(
          Mano.append(mano1, mano2),
          Enum.to_list(mano1) ++ Enum.to_list(mano2)
        )
      end
    end

    property "new . append = (++) . new" do
      forall [
        items1 <- list(),
        items2 <- list()
      ] do
        mano_equals(
          Mano.append(Mano.new(items1), Mano.new(items2)),
          Mano.new(items1 ++ items2)
        )
      end
    end

    property "reverse is antimonoidal on append" do
      forall [
        mano1 <- gen(),
        mano2 <- gen()
      ] do
        mano_equals(
          Mano.append(Mano.reverse(mano1), Mano.reverse(mano2)),
          Mano.reverse(Mano.append(mano2, mano1))
        )
      end
    end
  end

  describe "split:" do
    property "doesn't crash" do
      forall mano <- gen() do
        Mano.split(mano, fn _ -> false end)
      end

      true
    end

    property "split . to_list = to_list . split_while" do
      forall [
        middle <- integer(),
        items <- ordered_list(integer())
      ] do
        split_function = fn item -> item < middle end
        result = items
          |> Mano.new()
          |> Mano.split(split_function)
        case result do
          nil -> Enum.empty?(items)
          {left, right} ->
            {left_items, right_items} = Enum.split_while(items, split_function)
            conjunction(
              left: mano_equals(left, left_items),
              right: mano_equals(right, right_items)
            )
        end
      end
    end
  end
end
