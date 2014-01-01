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
    rand * 2 * Math::PI
  end

  argument(:color) do
    colors = [:white, :black, :red, :yellow, :green, :blue]
    colors[rand(colors.length)]
  end

end

# +generate_tree+ takes a depth parameter and terminates all nodes
# at that depth
tree = mondrian_trees.generate_tree(3)

module RaphaelMondrian

  ##
  # We are going to be dealing with points in a plane so might as well
  # define them along with the very basic vector group operations. Scalars
  # act from the right because it is easier to define multiplication from the
  # right than it is from the left. We are overloading the meaning of +Point+
  # to both mean a point and a vector.

  class Point < Struct.new(:x, :y)
    def +(other); Point.new(self.x + other.x, self.y + other.y); end
    def -(other); Point.new(self.x - other.x, self.y - other.y); end
    def -@; Point.new(-self.x, -self.y); end
    def *(scalar); Point.new(self.x * scalar, self.y * scalar); end
    def norm; Math.sqrt(self.x * self.x + self.y * self.y); end
    def self.from_angle(angle); Point.new(Math.cos(angle), Math.sin(angle)); end
    def dot(other); self.x * other.x + self.y * other.y; end
  end

  ##
  # Returns two parameters. The first parameter tells us how far along we have
  # to travel along the vector component of the point, vector combination to reach
  # the intersection point. The second parameter tells us how far we have to travel
  # from the centroid along the splitting vector to reach the same point. During
  # the boundary calculations we are only going to be interested in results where
  # the first parameter is between 0.0 and 1.0 because those are the intersection points
  # that will be on the line segment and not outside it.

  def self.find_intersection_parameters(centroid, splitter, point, vector)
    # The equation we want to solve: point + t * vector = centroid + u * splitter.
    #
    # |vector.x -splitter.x| The matrix that represents line-line intersection.
    # |vector.y -splitter.y|
    #
    # |-splitter.y splitter.x| Adjugate of the above matrix. We need it to calculate
    # |-vector.y   vector.x  | the inverse of the above matrix.

    centroid_difference = centroid - point
    det = splitter.x * vector.y - (vector.x * splitter.y)
    t, u = 1.0 * centroid_difference.dot(Point.new(-splitter.y, splitter.x)) / det,
     1.0 * centroid_difference.dot(Point.new(-vector.y, vector.x)) / det
    [t, u]
  end

  def self.generate_aux(node, boundary)
    case node.name
    when :split
      centroid = boundary.reduce(:+) * (1.0 / boundary.length)
      point_pairs = boundary.zip(boundary.lazy.cycle.drop(1))
      boundary_vectors = point_pairs.map {|first, second| second - first}
      splitting_vector = Point.from_angle(node.children[0].value)
      annotated_boundary = boundary.zip(boundary_vectors).map do |point, vector|
        [point, vector,
         find_intersection_parameters(centroid, splitting_vector, point, vector)]
      end.flat_map do |point, vector, (t, u)|
        t <= 1 && t >= 0 ?
          [{:point => point}, {:point => point + vector * t, :split => true}] :
          [{:point => point}]
      end
      require 'pry'; binding.pry
    when :square
    end
  end

  def self.generate(node)
    generate_aux(node, [Point.new(-1, -1), Point.new(1, -1),
     Point.new(1, 1), Point.new(-1, 1)])
  end

end

require 'pry'; binding.pry
