require 'treegen'

##
# For each node type, except for argument nodes, we specify a list of
# possible arguments by calling +arg+ within the specification block.
# Each argument specification must have at least one terminal node in the
# specification because otherwise when we generate the tree we won't be
# able to terminate.

mondrian_trees = TreeGen::configure do

  ##
  # We need to tell our DSL where to begin the generation of the tree and
  # we specify the root by simply calling +root+ with the name of the node.
  # Node names can be anything that can put in a Ruby hash so symbols are
  # a good choice.

  root(:split)

  ##
  # Non-terminal nodes are specified by calling +node+. They are different from
  # terminal nodes in that in the specificaton block we can specify arguments that
  # refer to other non-terminal nodes, regular nodes, and argument nodes, i.e. there
  # are no restrictions on the argument specifications.

  node(:split) do
    arg a(:angle)
    arg n(:split) | n(:square)
    arg n(:split) | n(:square)
  end

  ##
  # Terminal nodes are not any different from regular nodes. It's simply a way
  # to tell the user that this node is not meant to have any children but this
  # invariant isn't actually enforced.

  terminal(:square) do
    arg a(:color)
  end

  ##
  # Argument nodes just like terminal nodes are final and can not have any
  # children and are used to fill in the arguments for both terminal and
  # non-terminal nodes. Argument nodes are created by calling +argument+.

  argument(:angle) do
    rand * 360
  end

  ##
  # Just returns a random color symbol that is just meant to specify the color
  # of the square.

  argument(:color) do
    colors = [:white, :black, :red, :yellow, :green, :blue]
    colors[rand(colors.length)]
  end

end

tree = mondrian_trees.generate_tree(3)
require 'pry'; binding.pry
