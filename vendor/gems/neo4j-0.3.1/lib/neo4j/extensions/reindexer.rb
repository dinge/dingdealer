module Neo4j

  module NodeMixin

    module ClassMethods

      # Traverse all nodes and update the lucene index.
      # Can be used for example if it is neccessarly to change the index on a class
      #
      # :api: public
      def update_index
        all.nodes.each do |n|
          n.update_index
        end
      end

      # Returns node instances of this class.
      #
      # :api: public
      def all
        index_node = IndexNode.instance
        index_node.relationships.outgoing(root_class)
      end

    end
  end


  class IndexNode
    include NodeMixin
    extend Neo4j::TransactionalMixin


    # Connects the given node with the reference node.
    # The type of the relationship will be the same as the class name of the
    # specified node unless the optional parameter type is specified.
    # This method is used internally to keep a reference to all node instances in the node space
    # (useful for example for reindexing all nodes by traversing the node space).
    #
    # ==== Parameters
    # node<Neo4j::NodeMixin>:: Connect the reference node with this node
    # type<String>:: Optional, the type of the relationship we want to create
    #
    # ==== Returns
    # nil
    #
    # :api: private
    def connect(node, type = node.class.root_class)
      rtype = Neo4j::Relationships::RelationshipType.instance(type)
      @internal_node.createRelationshipTo(node.internal_node, rtype)
      nil
    end

    def on_node_created(node)
      # we have to avoid connecting to our self
      connect(node) unless self == node
    end

    def self.on_neo_started(neo_instance)
      if neo_instance.ref_node.relationship?(:index_node)
        # we already have it, put it in instance variable so we do not have to look again
        @index_node = neo_instance.ref_node.relationships.outgoing(:index_node).nodes.first
      else
        @index_node = IndexNode.new # cache this so we do not have to look it up always
        neo_instance.ref_node.relationships.outgoing(:index_node) << @index_node
      end
      Neo4j.event_handler.add(@index_node)
    end

    def self.on_neo_stopped(neo_instance)
      # unregister the instance
      Neo4j.event_handler.remove(@index_node)
      @index_node = nil
    end

    def self.instance
      Neo4j.start if @index_node.nil?
      @index_node
    end

    transactional :connect
  end


  # Add this so it can add it self as listener
  def self.load_reindexer
    Neo4j.event_handler.add(IndexNode)
    # incase we already have started
    Neo4j::Transaction.run { IndexNode.on_neo_started(Neo4j.instance) } if Neo4j.running?
  end

  load_reindexer
end
