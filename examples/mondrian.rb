require 'treegen'

mondrian_trees = TreeGen::configure do

  root(:split)

  node(:split) do
    arg a(:angle)
    arg n(:split) | n(:square)
    arg n(:split) | n(:square)
  end

  terminal(:square) do
    arg a(:color)
  end

  argument(:angle) do
    rand * 360
  end

  argument(:color) do
    colors = [:white, :black, :red, :yellow, :green, :blue]
    colors[rand(colors.length)]
  end

end

# +generate_tree+ takes a depth parameter and terminates all nodes
# at that depth
tree = mondrian_trees.generate_tree(3)
