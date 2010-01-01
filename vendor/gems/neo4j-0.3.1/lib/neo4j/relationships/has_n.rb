module Neo4j
  module Relationships

    # Enables traversal of nodes of a specific type that one node has.
    # Used for traversing relationship of a specific type.
    # Neo4j::NodeMixin can declare
    #
    class HasN
      include Enumerable
      extend Neo4j::TransactionalMixin

      def initialize(node, type, &filter)
        @node = node
        @type = RelationshipType.instance(type)
        @traverser = NodeTraverser.new(node.internal_node)
        @info = node.class.relationships_info[type.to_sym]
        if @info[:outgoing]
          @traverser.outgoing(type)
        else
          other_class_type = @info[:type].to_s
          @type = RelationshipType.instance(other_class_type)
          @traverser.incoming(other_class_type)
        end
        @traverser.filter(&filter) unless filter.nil?
      end


      # Sets the depth of the traversal.
      # Default is 1 if not specified.
      #
      # ==== Example
      #  morpheus.friends.depth(:all).each { ... }
      #  morpheus.friends.depth(3).each { ... }
      #  
      # ==== Arguments
      # d<Fixnum,Symbol>:: the depth or :all if traversing to the end of the network.
      # ==== Return
      # self
      # 
      # :api: public
      def depth(d)
        @traverser.depth(d)
        self
      end

      def each(&block)
        @traverser.each(&block)
      end


      # Returns true if there are no node in this type of relationship
      #
      # :api: public
      def empty?
        @traverser.empty?
      end

      # Return the first relationship or nil
      #
      # :api: public
      def first
        @traverser.first
      end

      # Creates a relationship instance between this and the other node.
      # If a class for the relationship has not been specified it will be of type Relationship.
      #
      # :api: public
      def new(other)
        from, to = @node, other
        from, to = to, from unless @info[:outgoing]

        from._create_relationship(@type.name, to)
      end


      # Creates a relationship between this and the other node.
      #
      # ==== Example
      # 
      #   n1 = Node.new # Node has declared having a friend type of relationship
      #   n2 = Node.new
      #   n3 = NodeMixin.new
      #
      #   n1 << n2 << n3
      #
      # This is the same as:
      #
      #   n1.friends.new(n2)
      #   n1.friends.new(n3)
      #
      # ==== Returns
      # self
      #
      # :api: public
      def <<(other)
        from, to = @node, other
        from, to = to, from unless @info[:outgoing]
        relationship = from._create_relationship(@type.name, to)
        self
      end


      transactional :<<, :new
    end

  end
end
