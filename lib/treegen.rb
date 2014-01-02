require "treegen/version"

module TreeGen

  ##
  # The top level container for the specification of the tree nodes and
  # their arguments.

  class TreeGenSpec

    ##
    # These are used during the simple validation process where we simply make
    # sure the nodes are defined.

    attr_reader :arguments, :nodes

    def initialize; @root, @arguments, @nodes = nil, {}, {}; end

    ##
    # Only set the root node once. Raise an error root is already set
    # and the user tries to set it again. Might revisit this later to allow
    # for specifying more than one root node.

    def root(root_name)
      raise StandardError, "Root node already set: #{@root}." if @root
      @root = root_name
    end

    ##
    # Instantiate a new non-terminal node and evaluates the block of code in the context
    # of the new instance if there is a block of code.

    def node(node_name, &blk)
      if @nodes[node_name]
        raise StandardError, "A node with that name already exists: #{node_name}."
      end
      node = (@nodes[node_name] = Node.new(node_name))
      node.instance_exec(&blk) if blk
    end

    ##
    # Same as above but is meant to signal to the user that this node is meant to have
    # no children.

    def terminal(node_name, &blk); node(node_name, &blk); end

    ##
    # Create an argument node that creates values when we generate the tree.

    def argument(name, &blk)
      if @arguments[name]
        raise StandardError, "Argument node with that name already exists: #{name}."
      end
      @arguments[name] = ArgumentNode.new(name, blk)
    end

    ##
    # Make sure everything is set up as expected.
    
    def validate; @nodes.each {|name, n| n.validate(self)}; end
      
    ##
    # We require a depth parameter for tree generation because we need to know when
    # to terminate and I'm using depth as the termination criterion.

    def generate_tree(depth)
      @nodes[@root].expand(self, 0, depth)
    end

  end

  ##
  # When generating the tree we use a different kind of node that just has
  # a name, value, and zero or more children. A node with empty children indicates
  # a leaf node and the only relevant thing about a leaf node is its name and value.

  class TreeNode < Struct.new(:name, :value, :children)
    
    ##
    # One half of the mutually recursive pair of methods for generating trees
    # from node descriptions. The other half lives in +Node+. IMPORTANT: All the immediate
    # children are +TreeNode+ instances but the childrens' children are +Node+ or +ArgumentNode+
    # instances.

    def expand(tree_spec, current_depth, max_depth)
      if current_depth < max_depth
        children.map! {|c| c.expand(tree_spec, current_depth + 1, max_depth)}
      else
        children.each {|c| c.children.map!(&:terminate)}
      end
      self
    end

  end

  ##
  # This class is meant to describe the actual arguments of a function when
  # the functions and their compositions are represented as trees.

  class ArgumentNode < Struct.new(:name, :callable)

    ##
    # Expanding an argument node is very simple. We just call the block
    # of code that was used during the defintion of the argument.

    def expand(tree_spec, current_depth, max_depth)
      TreeNode.new(name, callable.call, [])
    end

    ##
    # Terminating is just as simple as expanding. We just call the block
    # to get a final value to be placed in the tree.

    def terminate
      TreeNode.new(name, callable.call, [])
    end

  end

  ##
  # You should think of these as both terminal and non-terminal nodes in the tree.

  class Node < Struct.new(:name, :argument_specifications)

    def initialize(name, spec = []); super(name, spec); end

    ##
    # Specify an argument to be appended to the argument specification
    # list for this node.

    def arg(argument_type); argument_specifications << argument_type; end

    ##
    # Create a callable argument specification.

    def a(argument_name); ArgumentSpecification.new(argument_name, :callable); end

    ##
    # Same as above except the type +:node+ instead of +:callable+.

    def n(node_name); ArgumentSpecification.new(node_name, :node); end

    ##
    # We need to enforce certain things, e.g. all argument specifications
    # must at the end of the day refer to nodes that have been defined and also
    # must contain at least a callable or terminal node.
    
    def validate(tree_spec)
      argument_specifications.each {|arg_spec| arg_spec.validate(tree_spec)}
    end

    ##
    # The other half of the mutually recursive pair of methods that are used to
    # construct the tree. The first half you saw in +TreeNode+. IMPORTANT: The
    # children are +TreeNode+ instances but the children of the children are
    # +Node+ and +ArgumentNode+ instances so need to be careful with termination.

    def expand(tree_spec, current_depth, max_depth)
      children = argument_specifications.map {|spec| spec.expand(tree_spec)}
      if current_depth < max_depth
        tree_node = TreeNode.new(name, nil, children)
        tree_node.expand(tree_spec, current_depth + 1, max_depth)
      else
        children.each {|c| c.children.map!(&:terminate)}
        tree_node = TreeNode.new(name, nil, children)
      end
      tree_node
    end

    ##
    # This is not the correct way to terminate nodes but in the absence of more
    # information the best we can do is simply truncate things and let the consumer
    # of the tree deal with incomplete nodes.

    def terminate
      TreeNode.new(name, nil, [])
    end

  end

  ##
  # An argument specification specifies the children of a node and how they
  # are supposed to be generated. Think of a BNF grammar, e.g. a(:arg) | n(:node)
  # means the argument can be either be filled in or be another non-terminal node.
  # During the tree generation we randomly choose between the various argument types.

  class ArgumentSpecification < Struct.new(:name, :type)

    def |(other); ArgumentSpecificationChoice.new(self, other); end

    ##
    # Make sure the specification has definitions for this argument.

    def validate(tree_spec)
      case type
      when :callable
        unless tree_spec.arguments[name]
          raise StandardError, "Argument type is not defined: #{name}."
        end
      when :node
        unless tree_spec.nodes[name]
          raise StandardError, "Node type is not defined: #{name}."
        end
      end
    end

    ##
    # Used during expansion to turn arguments back to +Node+ and +ArgumentNode+
    # instances so that the mutually recursive pair of functions between +TreeNode+
    # and +Node+ can continue expanding the tree.

    def nodify(tree_spec)
      case type
      when :callable
        tree_spec.arguments[name]
      when :node
        tree_spec.nodes[name]
      end
    end

    ##
    # Create new +TreeNode+ instances based on argument type. For callables we just
    # fill in the value and for non-callable nodes we simply convert it to a +TreeNode+
    # instance and await further calls from the mutually recursive functions.

    def expand(tree_spec)
      case type
      when :callable
        TreeNode.new(name, tree_spec.arguments[name].callable.call, [])
      when :node
        TreeNode.new(name, nil,
         tree_spec.nodes[name].argument_specifications.map {|spec| spec.nodify(tree_spec)})
      end
    end

  end

  ##
  # When there are several choices for an argument then we create an instance
  # of this class to collect all the choices into one place. Pretty much the same
  # logic as for +ArgumentSpecification+ except when it comes to choices we just
  # choose randomly from the argument types.

  class ArgumentSpecificationChoice

    def initialize(left, right); @arguments = [left, right]; end

    def |(other); @arguments << other; end

    def validate(tree_spec); @arguments.each {|arg_spec| arg_spec.validate(tree_spec)}; end

    def nodify(tree_spec); @arguments[rand(@arguments.length)].nodify(tree_spec); end

    def expand(tree_spec); @arguments[rand(@arguments.length)].expand(tree_spec); end

  end

  ##
  # Entry point for the DSL. Just creates a new instance of +TreeGenSpec+
  # and evaluates the block in the instance and returns the instance.

  def self.configure(&blk)
    (inst = TreeGenSpec.new).instance_exec(&blk)
    inst.validate
    inst
  end

end
