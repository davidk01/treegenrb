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
    colors = ['#9B6AD6', '#B7F46E', '#006D4F', '#35D3A7', '#FF9C00',
     '#03426A', '#0A67A3', '#FF9200', '#009999']
    colors[rand(colors.length)]
  end

end

# +generate_tree+ takes a depth parameter and terminates all nodes
# at that depth no matter how incomplete the nodes are. this forces
# some gross hacks in the tree walking code.


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

  ##
  # We need to now extract the two seperated boundary components. It is easier to
  # draw it than to explain it but not gonna do it here. If you've ever seen the usual
  # trick in complex analysis of splitting a square into multiple parts and then going
  # forward and then backward over a commmon boundary component then you should be good
  # to go. If not I highly recommend you open up a complex analysis book at your local
  # library.

  def self.split_annotated_boundary(boundary)
    indices = []
    boundary.each_with_index do |point, index|
      if point[:split]
        indices << index
      end
    end
    first_component = boundary[indices[0]..indices[1]].map {|x| x[:point]}
    second_component = (boundary[indices[1]..-1] +
     boundary[0..indices[0]]).map {|x| x[:point]}
    [first_component, second_component]
  end

  ##
  # Traverse from the top level by splitting each boundary into two components when
  # we have a splitting node and then aggregate the results together annotated with
  # each boundary component's color.

  def self.generate_aux(node, boundary)
    case node.name
    when :split
      if node.children.empty?
        return [{:boundary => boundary, :color => :no_color}]
      end
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
      first_component, second_component = split_annotated_boundary(annotated_boundary)
      generate_aux(node.children[1], first_component) +
       generate_aux(node.children[2], second_component)
    when :square
      if node.children.empty?
        return [{:boundary => boundary, :color => :no_color}]
      end
      [{:boundary => boundary, :color => node.children[0].value}]
    end
  end

  def self.generate(node, width, height)
    boundaries_with_colors = generate_aux(node, [Point.new(0, 0), Point.new(width, 0),
     Point.new(width, height), Point.new(0, height)])
    lines = boundaries_with_colors.map do |data|
      boundary = data[:boundary]
      "var path = paper.path('M#{boundary[0].x},#{boundary[0].y}" +
       boundary[1..-1].map {|b| "L#{b.x},#{b.y}"}.join + "Z');\n" +
       "path.attr({fill: '#{data[:color]}'});"
    end.join("\n")
    script = [
     "var paper = Raphael(document.getElementById('canvas_container'), #{width}, #{height});",
     lines].join("\n")
    html = open('test.html', 'r') {|f| f.read.sub('#raphael', script)}
    open('index.html', 'w') {|f| f.puts html}
  end

end

tree = mondrian_trees.generate_tree(5)
RaphaelMondrian.generate(tree, 1200, 900)
