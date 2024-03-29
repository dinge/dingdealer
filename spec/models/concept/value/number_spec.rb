require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe Concept::Value::Number do
  before(:all) { start_neo4j }
  after(:all) { stop_neo4j }

  before(:each) { Neo4j::Transaction.new }
  after(:each) { Neo4j::Transaction.finish }

  it "should be part of a concept" do
    number  = Concept::Value::Number.new(:name => 'color')
    concept = Concept.new

    number.shared_concepts << concept
    number.shared_concepts.should include(concept)
    concept.attributes.should include(number)
  end

  it "should have some default values" do
    number = Concept::Value::Number.new(:name => 'color')
    number.minimal_value.should == -9999999999
    number.maximal_value.should == 9999999999
    # number.required.should be_false
  end

  it "the default values should be overwritten in the initalization" do
    number = Concept::Value::Number.new(:name => 'color', :minimal_value => 10, :maximal_value => 20)
    number.minimal_value.should == 10
    number.maximal_value.should == 20
  end
end
